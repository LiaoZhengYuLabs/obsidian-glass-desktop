(function () {
  "use strict";

  var MAX_ANIMALS = 80;
  var MAX_PARTICLES = 240;
  var CELL_WIDTH = 192;
  var CELL_HEIGHT = 208;
  var FRAMES_PER_ROW = 8;
  var ROWS = 9;
  var VISUAL_RADIUS = 58;
  var PATH_MAX_POINTS = 300;
  var PATH_MAX_AGE = 26000;
  var IDLE_BATCH_SIZE = 20;
  var TOTAL_ANIMAL_CAP = 40;
  var IDLE_TRIGGER_MS = 2600;
  var IDLE_BATCH_GAP_MS = 1200;

  var species = [
    { slug: "byte-bunny", name: "奶油兔", color: "#ffd9b8", hero: true },
    { slug: "silver-shorthair", name: "薄荷猫", color: "#a9f0d5", hero: true },
    { slug: "prompt-penguin", name: "冰川企鹅", color: "#98d9ff", hero: true },
    { slug: "fine-pup", name: "薰衣草小狗", color: "#d6b9ff", hero: true },
    { slug: "little-deer", name: "秋日小鹿", color: "#ffad5d", hero: true },
    { slug: "nightly-fox", name: "北极小狐狸", color: "#9fbdff", hero: true },
    { slug: "cloudy", name: "熊猫", color: "#a8e47b", hero: true },
    { slug: "peri-the-owl", name: "月光猫头鹰", color: "#79b8ff", hero: true }
  ];
  var heroCount = species.length;
  var catalogLoaded = false;
  var catalogOrder = [];
  var catalogCursor = 0;
  var catalogCount = 0;
  var uniqueVisualCount = 0;
  var dynamicImagesLoaded = 0;
  var rejectedCatalogImages = 0;
  var usedVisualKeys = new Set();
  var usedNameKeys = new Set();
  var ambientPalette = ["#9bdfff", "#bba6ff", "#a7efd7", "#ffd4a8", "#8fb6ff", "#d7c4ff", "#a9e27c"];

  var settings = {
    enabled: true,
    mode: 1,
    density: 64,
    customMax: 44,
    speciesMode: 0,
    size: 112,
    glow: 80,
    frequency: 100,
    speed: 100,
    richness: 82,
    pingPong: true,
    flocking: true,
    speedReactive: true,
    colorLink: true,
    particles: true,
    lowPower: false,
    autoPause: true
  };

  var canvas = document.getElementById("animal-trail-canvas");
  if (!canvas) return;

  // WebView2 桌面合成中 desynchronized 会让 clearRect 的透明中间态提前呈现，
  // 造成整层动物周期性闪烁。使用同步 2D 提交可让清屏与重绘保持在同一帧。
  var ctx = canvas.getContext("2d", { alpha: true });
  var width = 1;
  var height = 1;
  var renderScale = 1;
  var paused = false;
  var initialized = false;
  var adaptiveLowPower = false;
  var hostLowPower = false;
  var lastFrameTime = performance.now();
  var lastRenderTime = 0;
  var currentTargetFps = 45;
  var fpsClock = performance.now();
  var fpsFrames = 0;
  var smoothedFps = 60;
  var recoveryClock = 0;
  var lastPointerTime = 0;
  var lastGestureTime = 0;
  var lastSwipeTime = 0;
  var pathDistance = 0;
  var path = [];
  var recentInput = [];
  var animals = [];
  var particles = [];
  var activeAnimals = 0;
  var groupSequence = 0;
  var particleCursor = 0;
  var imagesReady = 0;
  var pointer = { x: 0, y: 0, speed: 0, dx: 0, dy: 0 };
  var drawOrder = [];
  var collisionItems = [];
  var overlapPairs = 0;
  var pointerControlledAnimals = 0;
  var idleCleared = false;
  var lastSpawnSpeciesIndex = -1;
  var idleBatchId = 0;
  var idleBatchOpen = false;
  var idleBatchSpawned = 0;
  var idleBatchNextAt = 0;
  var idleBatchVisualKeys = new Set();
  var idleBatchNameKeys = new Set();
  var previousIdleBatchVisualKeys = new Set();
  var previousIdleBatchNameKeys = new Set();
  var idleCycleVisualKeys = new Set();
  var idleCycleNameKeys = new Set();
  var idleBatchSpeciesIndexes = [];
  var previousIdleBatchSpeciesIndexes = [];

  // 轨迹生成状态：动物从鼠标光轨中按移动距离出现
  var nextSpawnDistance = 60;
  var speedClass = "normal";
  var burstQueue = 0;
  var burstGroupId = 0;
  var burstSquad = false;
  var lastBurstAt = 0;
  var migrationTrimDistance = 0;
  var metrics = {
    spawns: 0,
    trailSpawns: 0,
    burstSpawns: 0,
    idleSpawns: 0,
    idleBatches: 0,
    idleBatchesCompleted: 0,
    swipes: 0,
    circles: 0,
    verticalUp: 0,
    verticalDown: 0,
    clears: 0,
    softRetired: 0
  };

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(a, b, amount) {
    return a + (b - a) * amount;
  }

  function random(min, max) {
    return min + Math.random() * (max - min);
  }

  function easeOutCubic(value) {
    var t = 1 - value;
    return 1 - t * t * t;
  }

  function hexToRgba(hex, alpha) {
    var value = parseInt(hex.slice(1), 16);
    var r = (value >> 16) & 255;
    var g = (value >> 8) & 255;
    var b = value & 255;
    return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
  }

  function isLowPower() {
    return settings.lowPower || adaptiveLowPower || hostLowPower;
  }

  function maxDynamicImages() {
    return Math.round(settings.mode) === 2 ? 24 : 20;
  }

  // 模式画像：宁静 10-20 / 标准 20-40 / 动物狂欢 40-70 / 自定义（上限 80）
  function modeProfile() {
    var densityFactor = clamp(settings.density / 64, 0.35, 1.65);
    var profiles = [
      { target: 15, max: 20, spacingMul: 1.55, burstMax: 3, calm: true },
      { target: 30, max: 40, spacingMul: 1.0, burstMax: 5, calm: false },
      { target: 55, max: 70, spacingMul: 0.62, burstMax: 8, calm: false },
      { target: Math.round(settings.customMax * 0.75), max: settings.customMax, spacingMul: 1.0, burstMax: 5, calm: false }
    ];
    var index = clamp(Math.round(settings.mode), 0, 3);
    var result = profiles[index];
    var hardMax = TOTAL_ANIMAL_CAP;
    var lowPower = isLowPower();
    var targetScale = settings.lowPower ? 0.65 : lowPower ? 0.86 : 1;
    var maxScale = settings.lowPower ? 0.72 : lowPower ? 0.9 : 1;
    // 自定义模式：上限严格等于用户设定值，密度只影响目标数量
    var maxValue = index === 3
      ? clamp(Math.round(settings.customMax * maxScale), IDLE_BATCH_SIZE, hardMax)
      : clamp(Math.round(result.max * densityFactor * maxScale), IDLE_BATCH_SIZE, hardMax);
    return {
      calm: result.calm,
      target: clamp(Math.round(result.target * densityFactor * targetScale), 4, maxValue),
      max: maxValue,
      spacingMul: result.spacingMul / clamp(settings.frequency / 100, 0.4, 1.6),
      burstMax: lowPower ? Math.min(3, result.burstMax) : result.burstMax,
      particleRate: lowPower ? 0.5 : result.calm ? 0.4 : 0.18
    };
  }

  function createAnimal() {
    return {
      active: false,
      speciesIndex: 0,
      groupId: 0,
      progress: 0,
      direction: 1,
      facing: 1,
      speed: 0,
      x: 0,
      y: 0,
      lastX: 0,
      lastY: 0,
      offsetX: 0,
      offsetY: 0,
      collisionX: 0,
      collisionY: 0,
      depth: 0,
      scale: 1,
      age: 0,
      life: 0,
      delay: 0,
      phase: 0,
      lane: 0,
      driftSpeed: 0.35,
      state: "walk",
      stateTime: 0,
      stateDuration: 2,
      particleTime: 0,
      bounce: 0,
      orbitUntil: 0,
      orbitX: 0,
      orbitY: 0,
      orbitRadius: 0,
      orbitAngle: 0,
      orbitSpeed: 0,
      autonomous: false,
      homeX: 0,
      homeY: 0,
      roamX: 0,
      roamY: 0,
      roamVx: 0,
      roamVy: 0,
      nextRoamAt: 0,
      visualLift: 0,
      archetype: "runner",
      headGap: 60,
      turnPending: 0,
      rollSpin: 0,
      speedBoostUntil: 0,
      foldUntil: 0,
      dissolveAt: 0,
      nextGreetAt: 0,
      softRetired: false,
      origin: "trail",
      idleBatchId: 0
    };
  }

  function createParticle() {
    return {
      active: false,
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      age: 0,
      life: 1,
      size: 1,
      color: "#ffffff",
      alpha: 1,
      drag: true
    };
  }

  for (var i = 0; i < MAX_ANIMALS; i++) animals.push(createAnimal());
  for (var j = 0; j < MAX_PARTICLES; j++) particles.push(createParticle());

  var validationCanvas = document.createElement("canvas");
  validationCanvas.width = 24;
  validationCanvas.height = 24;
  var validationContext = validationCanvas.getContext("2d", { willReadFrequently: true });

  // 缓存的地面光晕贴图：按颜色渲染一次，替代每帧每只动物创建径向渐变
  var glowSpriteCache = {};
  function glowSprite(color) {
    var cached = glowSpriteCache[color];
    if (cached) return cached;
    var sprite = document.createElement("canvas");
    sprite.width = 96;
    sprite.height = 44;
    var spriteCtx = sprite.getContext("2d");
    var gradient = spriteCtx.createRadialGradient(48, 22, 0, 48, 22, 46);
    gradient.addColorStop(0, hexToRgba(color, 0.55));
    gradient.addColorStop(1, hexToRgba(color, 0));
    spriteCtx.fillStyle = gradient;
    spriteCtx.save();
    spriteCtx.translate(48, 22);
    spriteCtx.scale(1, 0.45);
    spriteCtx.beginPath();
    spriteCtx.arc(0, 0, 46, 0, Math.PI * 2);
    spriteCtx.fill();
    spriteCtx.restore();
    glowSpriteCache[color] = sprite;
    return sprite;
  }

  // 单次扫描：检测不透明背景，并记录每行真正有内容的帧，跳过中间空格。
  function analyzeSpriteSheet(image, checkBackground) {
    var result = { rejected: false, rowFrames: null, validFramesByRow: null };
    if (!validationContext || image.naturalWidth < CELL_WIDTH * FRAMES_PER_ROW || image.naturalHeight < CELL_HEIGHT * ROWS) {
      result.rejected = Boolean(checkBackground);
      return result;
    }
    var rowFrames = [];
    var validFramesByRow = [];
    try {
      for (var row = 0; row < ROWS; row++) {
        var painted = 0;
        var validFrames = [];
        for (var frame = 0; frame < FRAMES_PER_ROW; frame++) {
          validationContext.clearRect(0, 0, 24, 24);
          validationContext.drawImage(image, frame * CELL_WIDTH, row * CELL_HEIGHT, CELL_WIDTH, CELL_HEIGHT, 0, 0, 24, 24);
          var pixels = validationContext.getImageData(0, 0, 24, 24).data;
          var alphaSum = 0;
          for (var offset = 3; offset < pixels.length; offset += 16) alphaSum += pixels[offset];
          if (alphaSum > 700) {
            painted = frame + 1;
            validFrames.push(frame);
          }
          if (checkBackground) {
            var opaqueEdge = 0;
            var edgeSamples = 0;
            for (var pixel = 0; pixel < 24; pixel++) {
              var offsets = [pixel * 4 + 3, (23 * 24 + pixel) * 4 + 3, (pixel * 24) * 4 + 3, (pixel * 24 + 23) * 4 + 3];
              for (var edge = 0; edge < offsets.length; edge++) {
                edgeSamples++;
                if (pixels[offsets[edge]] > 220) opaqueEdge++;
              }
            }
            if (opaqueEdge / edgeSamples > 0.62) {
              result.rejected = true;
              return result;
            }
          }
        }
        rowFrames.push(Math.max(1, painted));
        validFramesByRow.push(validFrames.length ? validFrames : [0]);
      }
    } catch (error) {
      result.rejected = false;
      result.rowFrames = null;
      result.validFramesByRow = null;
      return result;
    }
    result.rowFrames = rowFrames;
    result.validFramesByRow = validFramesByRow;
    return result;
  }

  function beginImageLoad(item, sourcePath) {
    if (item.loading || item.loaded || item.rejected) return;
    item.loading = true;
    item.image = new Image();
    item.loaded = false;
    item.image.onload = function () {
      var analysis = analyzeSpriteSheet(item.image, !item.hero);
      if (analysis.rejected) {
        item.rejected = true;
        rejectedCatalogImages++;
        item.loaded = false;
        item.loading = false;
        item.image = null;
        return;
      }
      item.rowFrames = analysis.rowFrames;
      item.validFramesByRow = analysis.validFramesByRow;
      item.loaded = true;
      item.loading = false;
      item.lastUsed = performance.now();
      imagesReady++;
      if (!item.hero) dynamicImagesLoaded++;
      evictDynamicImages();
    };
    item.image.onerror = function () {
      item.loaded = false;
      item.loading = false;
      if (!item.remoteTried && item.spritesheetUrl) {
        item.remoteTried = true;
        beginImageLoad(item, item.spritesheetUrl);
      }
    };
    item.image.src = sourcePath;
  }

  function identityName(item) {
    return String(item.name || item.slug || "unknown")
      .toLowerCase()
      .replace(/[\s_\-]+/g, "")
      .trim();
  }

  function identityVisual(item) {
    return item.visualKey || ("slug:" + item.slug);
  }

  function speciesActiveCount(index) {
    var count = 0;
    for (var i = 0; i < animals.length; i++) {
      if (animals[i].active && animals[i].speciesIndex === index) count++;
    }
    return count;
  }

  function isSpeciesActive(index) {
    var candidate = species[index];
    var visualKey = identityVisual(candidate);
    var nameKey = candidate.nameKey || identityName(candidate);
    for (var i = 0; i < animals.length; i++) {
      if (!animals[i].active) continue;
      var activeIndex = animals[i].speciesIndex;
      var activeSpecies = species[activeIndex];
      if (activeIndex === index || identityVisual(activeSpecies) === visualKey || (activeSpecies.nameKey || identityName(activeSpecies)) === nameKey) return true;
    }
    return false;
  }

  function isSpeciesEligible(index) {
    var item = species[index];
    if (!item || !item.loaded || item.usedInCycle) return false;
    var visualKey = identityVisual(item);
    var nameKey = item.nameKey || identityName(item);
    return !usedVisualKeys.has(visualKey) && !usedNameKeys.has(nameKey) && !isSpeciesActive(index);
  }

  function markSpeciesUsed(index) {
    var item = species[index];
    item.usedInCycle = true;
    item.lastUsed = performance.now();
    usedVisualKeys.add(identityVisual(item));
    usedNameKeys.add(item.nameKey || identityName(item));
  }

  function dynamicCacheUsage() {
    var count = 0;
    for (var i = heroCount; i < species.length; i++) {
      if (species[i].loaded || species[i].loading) count++;
    }
    return count;
  }

  function hasCachedVisual(index) {
    var key = identityVisual(species[index]);
    for (var i = 0; i < species.length; i++) {
      if (i === index || (!species[i].loaded && !species[i].loading)) continue;
      if (identityVisual(species[i]) === key) return true;
    }
    return false;
  }

  function evictDynamicImages() {
    if (dynamicImagesLoaded <= maxDynamicImages()) return;
    var activeIndexes = new Set();
    for (var i = 0; i < animals.length; i++) {
      if (animals[i].active) activeIndexes.add(animals[i].speciesIndex);
    }
    var candidates = [];
    for (var index = heroCount; index < species.length; index++) {
      if (species[index].loaded && !activeIndexes.has(index)) candidates.push(index);
    }
    candidates.sort(function (a, b) {
      return (species[a].lastUsed || 0) - (species[b].lastUsed || 0);
    });
    while (dynamicImagesLoaded > maxDynamicImages() && candidates.length) {
      var candidate = species[candidates.shift()];
      candidate.loaded = false;
      candidate.loading = false;
      candidate.image = null;
      candidate.remoteTried = false;
      dynamicImagesLoaded--;
      imagesReady--;
    }
  }

  function shuffleCatalogOrder(resetUsage) {
    if (resetUsage) {
      usedVisualKeys.clear();
      usedNameKeys.clear();
      for (var resetIndex = 0; resetIndex < species.length; resetIndex++) species[resetIndex].usedInCycle = false;
    }
    catalogOrder.length = 0;
    for (var i = heroCount; i < species.length; i++) catalogOrder.push(i);
    for (var j = catalogOrder.length - 1; j > 0; j--) {
      var swap = Math.floor(Math.random() * (j + 1));
      var value = catalogOrder[j];
      catalogOrder[j] = catalogOrder[swap];
      catalogOrder[swap] = value;
    }
    catalogCursor = 0;
  }

  function requestNextCatalogSpecies(blockedVisualKeys, blockedNameKeys) {
    if (!catalogLoaded || catalogOrder.length === 0 || dynamicCacheUsage() >= maxDynamicImages()) return -1;
    var scanned = 0;
    while (scanned < catalogOrder.length) {
      if (catalogCursor >= catalogOrder.length) shuffleCatalogOrder(true);
      var index = catalogOrder[catalogCursor++];
      var item = species[index];
      scanned++;
      if (item.rejected || item.usedInCycle || usedVisualKeys.has(identityVisual(item)) || usedNameKeys.has(item.nameKey) || isSpeciesActive(index) || hasCachedVisual(index)) continue;
      if (blockedVisualKeys && blockedVisualKeys.has(identityVisual(item))) continue;
      if (blockedNameKeys && blockedNameKeys.has(item.nameKey || identityName(item))) continue;
      beginImageLoad(item, "animal-trail/catalog/assets/" + item.slug + ".webp");
      return index;
    }
    return -1;
  }

  function releaseUsedDynamicSlot() {
    var candidateIndex = -1;
    var oldest = Infinity;
    for (var index = heroCount; index < species.length; index++) {
      var item = species[index];
      if (!item.loaded || isSpeciesActive(index) || !item.usedInCycle) continue;
      if ((item.lastUsed || 0) < oldest) {
        oldest = item.lastUsed || 0;
        candidateIndex = index;
      }
    }
    if (candidateIndex < 0) return false;
    var candidate = species[candidateIndex];
    candidate.loaded = false;
    candidate.loading = false;
    candidate.image = null;
    candidate.remoteTried = false;
    dynamicImagesLoaded = Math.max(0, dynamicImagesLoaded - 1);
    imagesReady = Math.max(0, imagesReady - 1);
    return true;
  }

  function loadFullCatalog() {
    function register(items) {
      catalogCount = items.length;
      var catalogVisuals = new Set();
      items.forEach(function (item) {
        if (item.visualKey) catalogVisuals.add(item.visualKey);
        for (var heroIndex = 0; heroIndex < heroCount; heroIndex++) {
          if (species[heroIndex].slug === item.slug) {
            var hero = species[heroIndex];
            hero.visualKey = item.visualKey;
            hero.spritesheetUrl = item.spritesheetUrl;
            hero.nameKey = identityName(hero);

            // Public checkouts do not redistribute community sprite binaries.
            // When no locally synchronized starter exists, use the catalog URL.
            if (!hero.loaded && !hero.loading && hero.spritesheetUrl) {
              hero.remoteTried = true;
              beginImageLoad(hero, hero.spritesheetUrl);
            }
          }
        }
      });
      uniqueVisualCount = catalogVisuals.size || items.length;
      items.forEach(function (item, index) {
        species.push({
          slug: item.slug,
          name: item.displayName || item.slug,
          color: ambientPalette[index % ambientPalette.length],
          hero: false,
          loaded: false,
          loading: false,
          visualKey: item.visualKey,
          nameKey: identityName({ name: item.displayName || item.slug, slug: item.slug }),
          usedInCycle: false,
          spritesheetUrl: item.spritesheetUrl,
          submittedBy: item.submittedBy
        });
      });
      catalogLoaded = true;
      shuffleCatalogOrder(false);
      for (var preload = 0; preload < 8; preload++) requestNextCatalogSpecies();
    }

    if (Array.isArray(window.PetdexCreatureCatalog)) {
      register(window.PetdexCreatureCatalog);
      return;
    }
    fetch("animal-trail/catalog/creatures.json", { cache: "no-store" })
      .then(function (response) {
        if (!response.ok) throw new Error("Petdex catalog unavailable");
        return response.json();
      })
      .then(function (items) {
        register(items);
      })
      .catch(function () {
        catalogLoaded = false;
      });
  }

  species.forEach(function (item) {
    item.nameKey = identityName(item);
    item.usedInCycle = false;
    beginImageLoad(item, "animal-trail/assets/" + item.slug + "/spritesheet.webp");
  });
  loadFullCatalog();

  function resize() {
    var nextWidth = Math.max(1, window.innerWidth);
    var nextHeight = Math.max(1, window.innerHeight);
    var desiredScale = isLowPower() ? 1 : Math.min(window.devicePixelRatio || 1, 1.25);
    if (nextWidth === width && nextHeight === height && desiredScale === renderScale) return;
    width = nextWidth;
    height = nextHeight;
    renderScale = desiredScale;
    canvas.width = Math.round(width * renderScale);
    canvas.height = Math.round(height * renderScale);
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    ctx.setTransform(renderScale, 0, 0, renderScale, 0, 0);
    initialized = true;
  }

  function appendPathPoint(x, y, time, force) {
    var last = path[path.length - 1];
    if (last) {
      var dx = x - last.x;
      var dy = y - last.y;
      var distance = Math.sqrt(dx * dx + dy * dy);
      if (!force && distance < 6) return false;
      pathDistance += distance;
    }
    path.push({ x: x, y: y, d: pathDistance, time: time });
    if (path.length > PATH_MAX_POINTS) path.shift();
    return true;
  }

  // 轨迹按时间老化：只从头部裁剪，动物的进度会被自然夹到剩余区间
  function prunePath(now) {
    while (path.length > 12 && now - path[0].time > PATH_MAX_AGE) path.shift();
  }

  function samplePath(distance) {
    if (path.length < 2) return { x: pointer.x, y: pointer.y, angle: 0 };
    var minD = path[0].d;
    var maxD = path[path.length - 1].d;
    distance = clamp(distance, minD, maxD);
    var low = 0;
    var high = path.length - 1;
    while (low < high - 1) {
      var mid = (low + high) >> 1;
      if (path[mid].d < distance) low = mid;
      else high = mid;
    }
    var p0 = path[Math.max(0, low - 1)];
    var p1 = path[low];
    var p2 = path[high];
    var p3 = path[Math.min(path.length - 1, high + 1)];
    var span = Math.max(1, p2.d - p1.d);
    var t = clamp((distance - p1.d) / span, 0, 1);
    var t2 = t * t;
    var t3 = t2 * t;
    var x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
    var y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
    return { x: x, y: y, angle: Math.atan2(p2.y - p1.y, p2.x - p1.x) };
  }

  function acquireAnimal() {
    for (var i = 0; i < animals.length; i++) {
      if (!animals[i].active) return animals[i];
    }
    return null;
  }

  function desktopBounds(radius) {
    return {
      left: 22 + radius,
      right: Math.max(22 + radius + 80, width - 22 - radius),
      top: 58 + radius,
      bottom: Math.max(180, height - 28 - radius)
    };
  }

  function isProtectedZone(x, y, radius) {
    var stageManager = x < 92 + radius && y > 82 && y < height - 150;
    var rightWidgets = width >= 1200 && x > width - Math.min(360, width * 0.19) - radius && y > 74 && y < height - 160;
    var dock = y > height - 150 - radius * 0.35 && x > width * 0.28 && x < width * 0.72;
    return stageManager || rightWidgets || dock;
  }

  function chooseRoamTarget(item, now, directionalBias) {
    var radius = VISUAL_RADIUS * (settings.size / 100) * item.scale;
    var bounds = desktopBounds(radius);
    var rangeX = Math.min(240, Math.max(90, (bounds.right - bounds.left) * 0.22));
    var rangeY = Math.min(170, Math.max(70, (bounds.bottom - bounds.top) * 0.22));
    var bias = Number(directionalBias) || 0;
    var originX = settings.pingPong && item.homeX ? item.homeX : item.x;
    var originY = settings.pingPong && item.homeY ? item.homeY : item.y;
    var targetX;
    var targetY;
    for (var attempt = 0; attempt < 24; attempt++) {
      var explore = Math.random() < 0.22;
      targetX = explore ? random(bounds.left, bounds.right) : clamp(originX + random(-rangeX, rangeX) + bias * rangeX * 0.7, bounds.left, bounds.right);
      targetY = explore ? random(bounds.top, bounds.bottom) : clamp(originY + random(-rangeY, rangeY), bounds.top, bounds.bottom);
      if (!isProtectedZone(targetX, targetY, radius)) break;
    }
    if (isProtectedZone(targetX, targetY, radius)) {
      targetX = item.x;
      targetY = item.y;
    }
    item.roamX = targetX;
    item.roamY = targetY;
    item.nextRoamAt = now + random(2600, 7200);
  }

  // 选择物种：优先完整目录无放回轮换；候选耗尽时优雅复用，保证高密度下仍能持续生成
  function chooseSpecies() {
    var allowDynamic = settings.speciesMode !== 1;
    var allowHero = settings.speciesMode !== 2;
    if (catalogLoaded && allowDynamic && dynamicCacheUsage() < maxDynamicImages()) requestNextCatalogSpecies();
    var dynamicReady = [];
    for (var dynamicIndex = heroCount; dynamicIndex < species.length; dynamicIndex++) {
      if (allowDynamic && isSpeciesEligible(dynamicIndex)) dynamicReady.push(dynamicIndex);
    }
    var heroReady = [];
    for (var heroIndex = 0; heroIndex < heroCount; heroIndex++) {
      if (allowHero && isSpeciesEligible(heroIndex)) heroReady.push(heroIndex);
    }
    var candidates = dynamicReady;
    if (heroReady.length && (!dynamicReady.length || Math.random() >= 0.84)) candidates = heroReady;
    if (candidates.length) {
      var selected = candidates[Math.floor(Math.random() * candidates.length)];
      markSpeciesUsed(selected);
      if (allowDynamic && dynamicCacheUsage() < maxDynamicImages()) requestNextCatalogSpecies();
      lastSpawnSpeciesIndex = selected;
      return selected;
    }
    if (allowDynamic && releaseUsedDynamicSlot()) requestNextCatalogSpecies();
    // 无放回候选耗尽：允许复用已加载物种（选活跃实例最少、且不与上一只相同的）
    var reuseIndex = -1;
    var reuseScore = Infinity;
    for (var index = 0; index < species.length; index++) {
      if (!species[index].loaded) continue;
      if (index >= heroCount && !allowDynamic) continue;
      if (index < heroCount && !allowHero) continue;
      var score = speciesActiveCount(index) * 10 + (index === lastSpawnSpeciesIndex ? 5 : 0) + Math.random();
      if (score < reuseScore) {
        reuseScore = score;
        reuseIndex = index;
      }
    }
    if (reuseIndex >= 0) {
      species[reuseIndex].lastUsed = performance.now();
      lastSpawnSpeciesIndex = reuseIndex;
      return reuseIndex;
    }
    return -1;
  }

  function activeIdleBatchCount() {
    var count = 0;
    for (var i = 0; i < animals.length; i++) {
      if (animals[i].active && animals[i].origin === "idle" && animals[i].idleBatchId === idleBatchId) count++;
    }
    return count;
  }

  function combinedIdleBlockSets() {
    var visuals = new Set();
    var names = new Set();
    previousIdleBatchVisualKeys.forEach(function (value) { visuals.add(value); });
    idleBatchVisualKeys.forEach(function (value) { visuals.add(value); });
    previousIdleBatchNameKeys.forEach(function (value) { names.add(value); });
    idleBatchNameKeys.forEach(function (value) { names.add(value); });
    idleCycleVisualKeys.forEach(function (value) { visuals.add(value); });
    idleCycleNameKeys.forEach(function (value) { names.add(value); });
    return { visuals: visuals, names: names };
  }

  function idleBatchCandidates() {
    var candidates = [];
    for (var index = 0; index < species.length; index++) {
      var candidate = species[index];
      if (!candidate || !candidate.loaded || candidate.rejected || isSpeciesActive(index)) continue;
      var visualKey = identityVisual(candidate);
      var nameKey = candidate.nameKey || identityName(candidate);
      if (idleBatchVisualKeys.has(visualKey) || idleBatchNameKeys.has(nameKey)) continue;
      if (previousIdleBatchVisualKeys.has(visualKey) || previousIdleBatchNameKeys.has(nameKey)) continue;
      if (idleCycleVisualKeys.has(visualKey) || idleCycleNameKeys.has(nameKey)) continue;
      candidates.push(index);
    }
    return candidates;
  }

  function chooseIdleBatchSpecies() {
    var candidates = idleBatchCandidates();
    if (!candidates.length) return -1;
    var selected = candidates[Math.floor(Math.random() * candidates.length)];
    var item = species[selected];
    idleBatchVisualKeys.add(identityVisual(item));
    idleBatchNameKeys.add(item.nameKey || identityName(item));
    idleCycleVisualKeys.add(identityVisual(item));
    idleCycleNameKeys.add(item.nameKey || identityName(item));
    idleBatchSpeciesIndexes.push(selected);
    markSpeciesUsed(selected);
    return selected;
  }

  function requestIdleBatchCandidate() {
    var blocked = combinedIdleBlockSets();
    if (dynamicCacheUsage() >= maxDynamicImages()) releaseUsedDynamicSlot();
    var requested = requestNextCatalogSpecies(blocked.visuals, blocked.names);
    if (requested < 0 && dynamicCacheUsage() < maxDynamicImages() && idleBatchCandidates().length === 0 && idleCycleVisualKeys.size >= Math.max(20, uniqueVisualCount - 8)) {
      idleCycleVisualKeys = new Set(previousIdleBatchVisualKeys);
      idleCycleNameKeys = new Set(previousIdleBatchNameKeys);
      idleBatchVisualKeys.forEach(function (value) { idleCycleVisualKeys.add(value); });
      idleBatchNameKeys.forEach(function (value) { idleCycleNameKeys.add(value); });
      blocked = combinedIdleBlockSets();
      requestNextCatalogSpecies(blocked.visuals, blocked.names);
    }
  }

  function findIdleSpawnPoint(scale) {
    var radius = VISUAL_RADIUS * (settings.size / 100) * scale;
    var bounds = desktopBounds(radius);
    var x = width * 0.5;
    var y = height * 0.55;
    for (var attempt = 0; attempt < 36; attempt++) {
      x = random(bounds.left, bounds.right);
      y = random(bounds.top, bounds.bottom);
      if (isProtectedZone(x, y, radius)) continue;
      var clear = true;
      for (var i = 0; i < animals.length; i++) {
        if (!animals[i].active) continue;
        var dx = animals[i].x - x;
        var dy = animals[i].y - y;
        if (dx * dx + dy * dy < (radius * 1.65) * (radius * 1.65)) {
          clear = false;
          break;
        }
      }
      if (clear) break;
    }
    return { x: x, y: y };
  }

  function spawnIdleBatchAnimal(now) {
    if (activeAnimals >= TOTAL_ANIMAL_CAP || idleBatchSpawned >= IDLE_BATCH_SIZE) return null;
    var item = acquireAnimal();
    if (!item) return null;
    var speciesIndex = chooseIdleBatchSpecies();
    if (speciesIndex < 0) {
      requestIdleBatchCandidate();
      return null;
    }
    var depth = random(0.18, 1);
    var scale = random(0.7, 1.02) * lerp(0.72, 1.08, depth);
    var point = findIdleSpawnPoint(scale);
    item.active = true;
    item.speciesIndex = speciesIndex;
    item.groupId = ++groupSequence;
    item.archetype = Math.random() < 0.72 ? "idler" : "shuttler";
    item.autonomous = true;
    item.origin = "idle";
    item.idleBatchId = idleBatchId;
    item.progress = pathDistance;
    item.direction = Math.random() < 0.5 ? -1 : 1;
    item.facing = item.direction;
    item.depth = depth;
    item.scale = scale;
    item.lane = 0;
    item.headGap = random(40, 100);
    item.speed = random(28, 62) * settings.speed / 100;
    item.x = point.x;
    item.y = point.y;
    item.lastX = item.x;
    item.lastY = item.y;
    item.homeX = item.x;
    item.homeY = item.y;
    item.offsetX = 0;
    item.offsetY = 0;
    item.age = 0;
    item.life = random(12, 22);
    item.delay = random(0.02, 0.22);
    item.phase = random(0, Math.PI * 2);
    item.driftSpeed = random(0.22, 0.42);
    item.state = Math.random() < 0.5 ? "play" : (Math.random() < 0.5 ? "walk" : "look");
    item.stateTime = 0;
    item.stateDuration = random(1.5, 4.2);
    item.particleTime = random(0, 0.2);
    item.bounce = random(0, Math.PI * 2);
    item.orbitUntil = 0;
    item.roamVx = 0;
    item.roamVy = 0;
    item.visualLift = 0;
    item.turnPending = 0;
    item.rollSpin = 0;
    item.speedBoostUntil = 0;
    item.foldUntil = 0;
    item.dissolveAt = 0;
    item.nextGreetAt = 0;
    item.softRetired = false;
    chooseRoamTarget(item, now, item.direction * 0.4);
    activeAnimals++;
    idleBatchSpawned++;
    metrics.spawns++;
    metrics.idleSpawns++;
    emitConvergence(item.x, item.y, species[speciesIndex].color);
    return item;
  }

  function finishIdleBatch(now) {
    previousIdleBatchVisualKeys = new Set(idleBatchVisualKeys);
    previousIdleBatchNameKeys = new Set(idleBatchNameKeys);
    previousIdleBatchSpeciesIndexes = idleBatchSpeciesIndexes.slice();
    idleBatchVisualKeys.clear();
    idleBatchNameKeys.clear();
    idleBatchSpeciesIndexes.length = 0;
    idleBatchSpawned = 0;
    idleBatchOpen = false;
    idleBatchNextAt = now + IDLE_BATCH_GAP_MS;
    metrics.idleBatchesCompleted++;
  }

  function updateIdleBatch(now) {
    if (!settings.enabled || paused || imagesReady === 0 || now - lastPointerTime < IDLE_TRIGGER_MS) return;
    if (!idleBatchOpen) {
      if (now < idleBatchNextAt) return;
      idleBatchOpen = true;
      idleBatchId++;
      metrics.idleBatches++;
    }
    if (idleBatchSpawned >= IDLE_BATCH_SIZE) {
      if (activeIdleBatchCount() === 0) finishIdleBatch(now);
      return;
    }
    if (now < idleBatchNextAt || activeAnimals >= TOTAL_ANIMAL_CAP) return;
    if (idleBatchSpawned === 0 && idleBatchCandidates().length < IDLE_BATCH_SIZE) {
      requestIdleBatchCandidate();
      idleBatchNextAt = now + 140;
      return;
    }
    if (spawnIdleBatchAnimal(now)) idleBatchNextAt = now + random(55, 115);
    else idleBatchNextAt = now + 140;
  }

  function acquireParticle() {
    for (var i = 0; i < particles.length; i++) {
      var index = (particleCursor + i) % particles.length;
      if (!particles[index].active) {
        particleCursor = (index + 1) % particles.length;
        return particles[index];
      }
    }
    return null;
  }

  function emitParticle(x, y, color, velocityScale) {
    if (!settings.particles || isLowPower()) return;
    var item = acquireParticle();
    if (!item) return;
    var angle = random(0, Math.PI * 2);
    var speed = random(5, 28) * (velocityScale || 1);
    item.active = true;
    item.x = x + random(-5, 5);
    item.y = y + random(-4, 5);
    item.vx = Math.cos(angle) * speed;
    item.vy = Math.sin(angle) * speed - random(2, 10);
    item.age = 0;
    item.life = random(0.55, 1.6);
    item.size = random(0.7, 2.3);
    item.color = color;
    item.alpha = random(0.35, 0.9);
    item.drag = true;
  }

  function emitBurst(x, y, color, count) {
    if (!settings.particles) return;
    count = isLowPower() ? Math.ceil(count * 0.35) : count;
    for (var i = 0; i < count; i++) emitParticle(x, y, color, 2.5);
  }

  // 出生特效：光轨粒子向中心聚拢，动物从光团中显现
  function emitConvergence(x, y, color) {
    if (!settings.particles) return;
    var count = isLowPower() ? 4 : 9;
    for (var i = 0; i < count; i++) {
      var item = acquireParticle();
      if (!item) return;
      var angle = random(0, Math.PI * 2);
      var radius = random(26, 56);
      var life = random(0.32, 0.52);
      item.active = true;
      item.x = x + Math.cos(angle) * radius;
      item.y = y + Math.sin(angle) * radius * 0.72;
      item.vx = -Math.cos(angle) * radius / life;
      item.vy = -Math.sin(angle) * radius * 0.72 / life;
      item.age = 0;
      item.life = life;
      item.size = random(0.8, 2);
      item.color = Math.random() < 0.5 ? color : (Math.random() < 0.5 ? "#b9a8ff" : "#9bdfff");
      item.alpha = random(0.5, 0.95);
      item.drag = false;
    }
  }

  function updateParticles(dt) {
    for (var i = 0; i < particles.length; i++) {
      var item = particles[i];
      if (!item.active) continue;
      item.age += dt;
      if (item.age >= item.life) {
        item.active = false;
        continue;
      }
      item.x += item.vx * dt;
      item.y += item.vy * dt;
      if (item.drag) {
        item.vx *= Math.pow(0.25, dt);
        item.vy *= Math.pow(0.4, dt);
        item.vy -= 2 * dt;
      }
    }
  }

  function hasActiveParticles() {
    for (var i = 0; i < particles.length; i++) {
      if (particles[i].active) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------
  // 轨迹生成：动物按鼠标移动距离从光轨中出现
  // ---------------------------------------------------------------

  function spacingForClass(profile) {
    var base;
    if (speedClass === "slow") base = random(80, 140);
    else if (speedClass === "fast") base = random(90, 140);
    else base = random(45, 80);
    return base * profile.spacingMul;
  }

  function pickArchetype(profile) {
    var roll = Math.random();
    if (profile.calm) {
      if (roll < 0.45) return "idler";
      if (roll < 0.8 && settings.pingPong) return "shuttler";
      return "runner";
    }
    if (speedClass === "fast") {
      if (roll < 0.7) return "runner";
      return settings.pingPong ? "shuttler" : "runner";
    }
    if (roll < 0.42) return "runner";
    if (roll < 0.62 && settings.pingPong) return "shuttler";
    if (roll < 0.78) return "returner";
    return "idler";
  }

  function archetypeLife(archetype) {
    if (archetype === "shuttler") return random(15, 30);
    if (archetype === "idler") return random(12, 25);
    if (archetype === "squad") return random(10, 20);
    return random(8, 18);
  }

  function archetypeSpeed(archetype, profile) {
    var scale = settings.speed / 100;
    var calm = profile.calm ? 0.62 : 1;
    if (archetype === "squad") return random(150, 240) * scale;
    if (archetype === "idler") return random(26, 60) * scale * calm;
    if (speedClass === "fast") return random(130, 220) * scale * calm;
    if (speedClass === "slow") return random(34, 80) * scale * calm;
    return random(70, 150) * scale * calm;
  }

  function spawnFromTrail(options) {
    var profile = modeProfile();
    if (!settings.enabled || paused || imagesReady === 0 || path.length < 2) return null;
    options = options || {};
    if (activeAnimals >= profile.max) return null;
    var item = acquireAnimal();
    if (!item) return null;
    var speciesIndex = chooseSpecies();
    if (speciesIndex < 0) return null;

    var archetype = options.archetype || pickArchetype(profile);
    var head = pathDistance;
    var minD = path[0].d;
    var backOffset = options.backOffset != null ? options.backOffset : random(10, 70);
    var progress = clamp(head - backOffset, minD, head);
    var sampled = samplePath(progress);

    item.active = true;
    item.speciesIndex = speciesIndex;
    item.groupId = options.groupId || ++groupSequence;
    item.archetype = archetype;
    item.autonomous = false;
    item.origin = "trail";
    item.idleBatchId = 0;
    item.progress = progress;
    item.direction = archetype === "returner" ? -1 : 1;
    item.facing = item.direction;
    item.depth = random(0.15, 1);
    item.scale = random(0.72, 1.08) * lerp(0.72, 1.12, item.depth);
    item.lane = (options.lane != null ? options.lane : random(-1, 1)) * lerp(16, 52, item.depth);
    item.headGap = random(30, 110);
    item.speed = options.speed || archetypeSpeed(archetype, profile);
    item.x = sampled.x;
    item.y = sampled.y;
    item.lastX = item.x;
    item.lastY = item.y;
    item.homeX = item.x;
    item.homeY = item.y;
    item.offsetX = 0;
    item.offsetY = 0;
    item.age = 0;
    item.life = options.life || archetypeLife(archetype);
    item.delay = options.delay != null ? options.delay : random(0.05, 0.35);
    item.phase = random(0, Math.PI * 2);
    item.driftSpeed = random(0.24, 0.48);
    item.state = archetype === "idler" ? (Math.random() < 0.5 ? "walk" : "look") : speedClass === "fast" ? (Math.random() < 0.35 ? "roll" : "run") : speedClass === "slow" ? "walk" : (Math.random() < 0.7 ? "run" : "jump");
    item.stateTime = 0;
    item.stateDuration = random(1.6, 4.2);
    item.particleTime = random(0, 0.2);
    item.bounce = random(0, Math.PI * 2);
    item.orbitUntil = 0;
    item.roamVx = 0;
    item.roamVy = 0;
    item.visualLift = 0;
    item.turnPending = 0;
    item.rollSpin = 0;
    item.speedBoostUntil = 0;
    item.foldUntil = 0;
    item.dissolveAt = 0;
    item.nextGreetAt = 0;
    item.softRetired = false;
    activeAnimals++;
    metrics.spawns++;
    metrics.trailSpawns++;
    if (options.burst) metrics.burstSpawns++;
    emitConvergence(item.x, item.y, species[speciesIndex].color);
    return item;
  }

  // 达到上限时优先送走最早、离指针最远、深度最低的动物（柔和淡出，不闪断）
  function softRetireOne() {
    var worst = null;
    var worstScore = -Infinity;
    for (var i = 0; i < animals.length; i++) {
      var item = animals[i];
      if (!item.active || item.softRetired) continue;
      var dx = item.x - pointer.x;
      var dy = item.y - pointer.y;
      var idleProtection = item.origin === "idle" ? 100 : 0;
      var score = (item.age / Math.max(1, item.life)) * 2 + Math.sqrt(dx * dx + dy * dy) / Math.max(width, 1) + (1 - item.depth) * 0.4 - idleProtection;
      if (score > worstScore) {
        worstScore = score;
        worst = item;
      }
    }
    if (!worst) return false;
    worst.softRetired = true;
    worst.life = Math.min(worst.life, worst.age + random(1.1, 1.9));
    metrics.softRetired++;
    return true;
  }

  function trimTo(limit) {
    var guard = 0;
    while (activeAnimals - retiringCount() > limit && guard < MAX_ANIMALS) {
      if (!softRetireOne()) break;
      guard++;
    }
  }

  function retiringCount() {
    var count = 0;
    for (var i = 0; i < animals.length; i++) {
      if (animals[i].active && animals[i].softRetired) count++;
    }
    return count;
  }

  function releaseAnimal(item, burst) {
    if (!item.active) return;
    if (burst && settings.particles) emitBurst(item.x, item.y + item.visualLift, species[item.speciesIndex].color, 7);
    item.active = false;
    activeAnimals = Math.max(0, activeAnimals - 1);
  }

  function updateSpawning(now) {
    if (!settings.enabled || paused) return;
    var profile = modeProfile();

    // 爆发队列：高速甩动一次生成一小组，按帧摊开避免卡顿
    if (burstQueue > 0 && imagesReady > 0) {
      var slots = Math.min(2, burstQueue);
      for (var i = 0; i < slots; i++) {
        var spawned = spawnFromTrail({
          groupId: burstGroupId,
          archetype: burstSquad ? "squad" : (Math.random() < 0.7 ? "runner" : "shuttler"),
          backOffset: random(10, 150),
          delay: random(0, 0.25),
          lane: random(-1, 1),
          burst: true
        });
        burstQueue--;
        if (!spawned) break;
      }
      if (burstQueue <= 0) burstSquad = false;
    }

    // 常规轨迹生成：按移动距离出现（慢帧时允许每帧补生成最多 2 只，避免漏生）
    var spawnedThisFrame = 0;
    while (pathDistance >= nextSpawnDistance && now - lastPointerTime < 320 && spawnedThisFrame < 2) {
      if (spawnFromTrail({})) {
        nextSpawnDistance = Math.max(nextSpawnDistance + spacingForClass(profile), pathDistance - 160);
        spawnedThisFrame++;
      } else {
        nextSpawnDistance = pathDistance + 40;
        break;
      }
    }

    // 长距离迁徙：满编时旧动物逐渐退出，为新动物腾出位置
    if (activeAnimals >= profile.max - 1 && pathDistance - migrationTrimDistance > 480) {
      migrationTrimDistance = pathDistance;
      softRetireOne();
    }
  }

  function classifyPointerSpeed() {
    if (!settings.speedReactive) {
      speedClass = "normal";
      return;
    }
    if (pointer.speed > 1150) speedClass = "fast";
    else if (pointer.speed < 240) speedClass = "slow";
    else speedClass = "normal";
  }

  function maybeQueueBurst(now) {
    if (!settings.speedReactive || speedClass !== "fast") return;
    if (now - lastBurstAt < 520) return;
    var profile = modeProfile();
    if (activeAnimals >= profile.max) return;
    lastBurstAt = now;
    burstGroupId = ++groupSequence;
    burstQueue = Math.min(Math.round(random(3, profile.burstMax)), profile.max - activeAnimals);
  }

  // ---------------------------------------------------------------
  // 动物状态与运动
  // ---------------------------------------------------------------

  function chooseState(item) {
    var roll = Math.random();
    var richness = settings.richness / 100;
    var idleDesktop = performance.now() - lastPointerTime > 2600;
    if (item.archetype === "idler" || (idleDesktop && Math.random() < 0.5)) {
      if (roll < 0.3) item.state = "idle";
      else if (roll < 0.5) item.state = "look";
      else if (roll < 0.62 * richness + 0.1) item.state = "play";
      else if (roll < 0.78 && idleDesktop) item.state = "sleep";
      else item.state = "walk";
    } else if (roll < 0.14 * richness) {
      item.state = "jump";
    } else if (roll < 0.26 * richness) {
      item.state = "roll";
      item.rollSpin = 0;
    } else if (roll < 0.3 + 0.1 * richness) {
      item.state = "look";
    } else if (roll < 0.4 + 0.16 * richness) {
      item.state = "play";
    } else if (item.speed > 110) {
      item.state = "run";
    } else {
      item.state = Math.random() < 0.4 ? "walk" : "run";
    }
    item.stateTime = 0;
    item.stateDuration = random(1.5, item.state === "sleep" ? 5.5 : 4.2);
  }

  function beginTurn(item, nextDirection) {
    item.direction = nextDirection;
    item.state = "turn";
    item.stateTime = 0;
    item.stateDuration = random(0.4, 0.8);
    item.turnPending = nextDirection;
  }

  function updateFollowerAnimal(item, dt, now) {
    var minD = path.length ? path[0].d : 0;
    var maxD = path.length ? path[path.length - 1].d : 0;
    var stateSpeed = item.state === "sleep" ? 0 : item.state === "idle" || item.state === "look" ? 0.05 : item.state === "play" ? 0.3 : item.state === "turn" ? 0.16 : item.state === "roll" ? 1.25 : item.state === "jump" ? 1.1 : item.state === "walk" ? 0.55 : 1;
    var boost = now < item.speedBoostUntil ? 1.65 : 1;
    var headActive = now - lastPointerTime < 900;

    item.progress += item.speed * item.direction * stateSpeed * boost * dt;

    var pingPongActive = settings.pingPong || now < item.foldUntil || item.archetype === "shuttler";
    var headLimit = headActive && item.direction > 0 ? Math.max(minD, maxD - item.headGap) : maxD;
    if (item.progress >= headLimit && item.direction > 0) {
      item.progress = headLimit;
      if (headActive) {
        // 追到光轨头部：跟着指针小队前进，保持各自的跟随间距
      } else if (pingPongActive) {
        beginTurn(item, -1);
      } else if (item.archetype === "runner" && !item.softRetired) {
        item.softRetired = true;
        item.life = Math.min(item.life, item.age + random(1.2, 2));
      } else {
        item.state = Math.random() < 0.5 ? "idle" : "look";
        item.stateTime = 0;
        item.stateDuration = random(1.6, 3.4);
      }
    } else if (item.progress <= minD && item.direction < 0) {
      item.progress = minD;
      if (pingPongActive) beginTurn(item, 1);
      else if (!item.softRetired) {
        item.softRetired = true;
        item.life = Math.min(item.life, item.age + random(1.2, 2));
      }
    }

    var sampled = samplePath(item.progress);
    var normalX = -Math.sin(sampled.angle);
    var normalY = Math.cos(sampled.angle);
    var drift = item.lane + Math.sin(item.phase + item.age * item.driftSpeed) * lerp(6, 24, item.depth);
    var jump = item.state === "jump" ? -Math.abs(Math.sin(item.stateTime * Math.PI * 1.5)) * 26 : 0;
    var targetX = sampled.x + normalX * drift;
    var targetY = sampled.y + normalY * drift + jump;

    // Dock 与组件附近：软避让 + 短暂驻足观察
    var radius = VISUAL_RADIUS * (settings.size / 100) * item.scale;
    if (isProtectedZone(targetX, targetY, radius * 0.8)) {
      targetY -= radius * 0.9;
      if (Math.random() < 0.004 && item.state !== "look") {
        item.state = "look";
        item.stateTime = 0;
        item.stateDuration = random(1, 2);
      }
    }
    var bounds = desktopBounds(radius * 0.6);
    targetX = clamp(targetX, bounds.left, bounds.right);
    targetY = clamp(targetY, bounds.top, bounds.bottom);

    var follow = 1 - Math.exp(-dt * lerp(4.5, 9.5, item.depth));
    item.x = lerp(item.x, targetX, follow);
    item.y = lerp(item.y, targetY, follow);
    item.visualLift = item.state === "jump" ? -Math.abs(Math.sin(item.stateTime * Math.PI * 1.35)) * 22 : lerp(item.visualLift, 0, 1 - Math.exp(-dt * 6));

    if (item.state === "roll") item.rollSpin += dt * Math.PI * 2.2 * item.direction;
    else item.rollSpin = 0;

    var moveX = item.x - item.lastX;
    if (Math.abs(moveX) > 0.35) item.facing = moveX >= 0 ? 1 : -1;
    if (now - lastPointerTime < 1600) pointerControlledAnimals++;
  }

  function updateAutonomousAnimal(item, dt, now) {
    if (now >= item.nextRoamAt || Math.abs(item.roamX - item.x) + Math.abs(item.roamY - item.y) < 26) chooseRoamTarget(item, now, item.direction * 0.2);
    var dx = item.roamX - item.x;
    var dy = item.roamY - item.y;
    var distance = Math.max(1, Math.sqrt(dx * dx + dy * dy));
    var stateSpeed = item.state === "sleep" || item.state === "look" || item.state === "idle" ? 0 : item.state === "play" ? 0.34 : item.state === "roll" ? 0.85 : 1;
    var gatherBoost = item.dissolveAt ? 1.6 : 1;
    var targetVx = dx / distance * item.speed * stateSpeed * gatherBoost;
    var targetVy = dy / distance * item.speed * stateSpeed * gatherBoost;
    var steering = 1 - Math.exp(-dt * 2.1);
    item.roamVx = lerp(item.roamVx, targetVx, steering);
    item.roamVy = lerp(item.roamVy, targetVy, steering);
    item.x += item.roamVx * dt;
    item.y += item.roamVy * dt;
    if (Math.abs(item.roamVx) > 1.4) item.facing = item.roamVx >= 0 ? 1 : -1;
    var radius = VISUAL_RADIUS * (settings.size / 100) * item.scale;
    var bounds = desktopBounds(radius);
    item.x = clamp(item.x, bounds.left, bounds.right);
    item.y = clamp(item.y, bounds.top, bounds.bottom);
    item.visualLift = item.state === "jump" ? -Math.abs(Math.sin(item.stateTime * Math.PI * 1.35)) * 26 : lerp(item.visualLift, 0, 1 - Math.exp(-dt * 6));
    if (item.state === "roll") item.rollSpin += dt * Math.PI * 2.2 * (item.facing || 1);
    else item.rollSpin = 0;
  }

  function updateAnimal(item, dt, now) {
    if (!item.active) return;
    if (item.delay > 0) {
      item.delay -= dt;
      return;
    }
    item.age += dt;
    item.stateTime += dt;
    item.particleTime += dt;
    if (item.age >= item.life) {
      releaseAnimal(item, true);
      return;
    }
    if (item.dissolveAt && now >= item.dissolveAt) {
      releaseAnimal(item, true);
      return;
    }
    if (item.stateTime >= item.stateDuration) {
      if (item.state === "turn" && item.turnPending) item.turnPending = 0;
      chooseState(item);
    }

    item.lastX = item.x;
    item.lastY = item.y;
    if (item.orbitUntil > now) {
      item.orbitAngle += item.orbitSpeed * dt;
      item.x = item.orbitX + Math.cos(item.orbitAngle) * item.orbitRadius;
      item.y = item.orbitY + Math.sin(item.orbitAngle) * item.orbitRadius * 0.58;
      item.state = Math.sin(item.orbitAngle * 2) > 0.72 ? "jump" : "run";
      item.visualLift = 0;
      var orbitMoveX = item.x - item.lastX;
      if (Math.abs(orbitMoveX) > 0.3) item.facing = orbitMoveX >= 0 ? 1 : -1;
    } else if (item.autonomous) {
      updateAutonomousAnimal(item, dt, now);
    } else {
      updateFollowerAnimal(item, dt, now);
    }

    var profile = modeProfile();
    if (item.particleTime > profile.particleRate) {
      item.particleTime = 0;
      if (item.depth > 0.42) emitParticle(item.x, item.y + 18 * item.scale, species[item.speciesIndex].color, 0.7);
    }
  }

  function applySeparation(now) {
    collisionItems.length = 0;
    for (var i = 0; i < animals.length; i++) {
      var item = animals[i];
      if (!item.active || item.delay > 0) continue;
      item.collisionX = item.x + item.offsetX;
      item.collisionY = item.y + item.offsetY;
      collisionItems.push(item);
    }

    {
      var separationIterations = settings.flocking ? 3 : 2;
      for (var iteration = 0; iteration < separationIterations; iteration++) {
        for (var a = 0; a < collisionItems.length; a++) {
          var one = collisionItems[a];
          var radiusOne = VISUAL_RADIUS * (settings.size / 100) * one.scale;
          for (var b = a + 1; b < collisionItems.length; b++) {
            var two = collisionItems[b];
            var radiusTwo = VISUAL_RADIUS * (settings.size / 100) * two.scale;
            var dx = one.collisionX - two.collisionX;
            var dy = (one.collisionY - two.collisionY) * 1.18;
            var distanceSq = dx * dx + dy * dy;
            var minimum = radiusOne + radiusTwo + 16;
            if (iteration === 0 && settings.flocking && distanceSq < (minimum + 26) * (minimum + 26)) {
              maybeGreet(one, two, now);
            }
            if (distanceSq >= minimum * minimum) continue;
            if (distanceSq < 0.01) {
              dx = Math.cos(one.phase - two.phase) || 1;
              dy = Math.sin(one.phase - two.phase) || 0.5;
              distanceSq = dx * dx + dy * dy;
            }
            var distance = Math.sqrt(distanceSq);
            var push = (minimum - distance) * 0.54;
            var pushX = dx / distance * push;
            var pushY = dy / distance * push / 1.18;
            one.collisionX += pushX;
            one.collisionY += pushY;
            two.collisionX -= pushX;
            two.collisionY -= pushY;
          }
          one.collisionX = clamp(one.collisionX, radiusOne + 16, width - radiusOne - 16);
          one.collisionY = clamp(one.collisionY, radiusOne + 34, height - radiusOne - 24);
        }
      }
    }

    overlapPairs = 0;
    for (var first = 0; first < collisionItems.length; first++) {
      var current = collisionItems[first];
      current.offsetX = lerp(current.offsetX, current.collisionX - current.x, 0.72);
      current.offsetY = lerp(current.offsetY, current.collisionY - current.y, 0.72);
      for (var second = first + 1; second < collisionItems.length; second++) {
        var other = collisionItems[second];
        var checkX = current.collisionX - other.collisionX;
        var checkY = (current.collisionY - other.collisionY) * 1.18;
        var currentRadius = (VISUAL_RADIUS - 2) * (settings.size / 100) * current.scale;
        var otherRadius = (VISUAL_RADIUS - 2) * (settings.size / 100) * other.scale;
        var safeDistance = currentRadius + otherRadius;
        if (checkX * checkX + checkY * checkY < safeDistance * safeDistance) overlapPairs++;
      }
    }
  }

  // 两只动物相遇：短暂停下打招呼（richness 越高越常见）
  function maybeGreet(one, two, now) {
    if (settings.richness < 25) return;
    if (now < one.nextGreetAt || now < two.nextGreetAt) return;
    if (one.state === "sleep" || two.state === "sleep" || one.state === "turn" || two.state === "turn") return;
    if (Math.random() > 0.0045 * (settings.richness / 100)) return;
    one.nextGreetAt = now + 7000;
    two.nextGreetAt = now + 7000;
    one.state = "play";
    two.state = "play";
    one.stateTime = 0;
    two.stateTime = 0;
    one.stateDuration = random(0.6, 1.1);
    two.stateDuration = random(0.6, 1.1);
    one.facing = two.x >= one.x ? 1 : -1;
    two.facing = one.x >= two.x ? 1 : -1;
  }

  // Petdex 模板行：0 待机 1 走/跑 2 扑跳(翻滚) 3 打招呼 4 梳理/张望 5 睡觉 6 开心待机 7 兴奋跳跃 8 特殊姿势
  function stateRow(item) {
    if (item.state === "jump") return 7;
    if (item.state === "roll") return 2;
    if (item.state === "play") return 3;
    if (item.state === "sleep") return 5;
    if (item.state === "look") return Math.floor(item.phase * 7) % 2 === 0 ? 4 : 8;
    if (item.state === "idle") return Math.floor(item.phase * 5) % 2 === 0 ? 0 : 6;
    if (item.state === "turn") return 0;
    if (item.state === "run" || item.state === "walk") return 1;
    return 0;
  }

  function stateFps(item) {
    if (item.state === "sleep") return 3;
    if (item.state === "idle" || item.state === "look") return 4;
    if (item.state === "walk") return 7;
    if (item.state === "run") return 11;
    if (item.state === "roll") return 13;
    return 9;
  }

  function zoneAttenuation(x, y) {
    var rightPanel = x > width - Math.min(470, width * 0.18) ? 0.58 : 1;
    var dock = y > height - Math.min(155, height * 0.1) ? 0.64 : 1;
    var topBar = y < 46 ? 0.5 : 1;
    return rightPanel * dock * topBar;
  }

  function drawAmbientTrail(now) {
    if (path.length < 4) return;
    var start = Math.max(0, path.length - (isLowPower() ? 44 : 96));
    var first = path[start];
    var last = path[path.length - 1];
    var age = Math.max(0, (now - lastPointerTime) / 1000);
    var idleFade = lerp(1, 0.28, clamp(age / 9, 0, 1));
    var gradient = ctx.createLinearGradient(first.x, first.y, last.x, last.y);
    gradient.addColorStop(0, "rgba(120,86,255,0)");
    gradient.addColorStop(0.42, "rgba(137,112,255," + (0.34 * idleFade) + ")");
    gradient.addColorStop(1, "rgba(160,238,255," + (0.72 * idleFade) + ")");

    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(first.x, first.y);
    for (var i = start + 1; i < path.length - 1; i++) {
      var current = path[i];
      var next = path[i + 1];
      ctx.quadraticCurveTo(current.x, current.y, (current.x + next.x) * 0.5, (current.y + next.y) * 0.5);
    }
    ctx.lineTo(last.x, last.y);
    ctx.strokeStyle = gradient;
    ctx.lineWidth = lerp(24, 46, clamp(pointer.speed / 1500, 0, 1));
    ctx.globalAlpha = 0.16 * (settings.glow / 80);
    ctx.stroke();
    ctx.lineWidth = 16;
    ctx.globalAlpha = 0.28;
    ctx.stroke();
    ctx.lineWidth = 5;
    ctx.globalAlpha = 0.5;
    ctx.stroke();
    ctx.lineWidth = 1.5;
    ctx.globalAlpha = 0.9;
    ctx.stroke();

    if (age < 1.8) {
      var radius = lerp(28, 72, clamp(pointer.speed / 1300, 0, 1));
      var halo = ctx.createRadialGradient(pointer.x, pointer.y, 0, pointer.x, pointer.y, radius);
      halo.addColorStop(0, "rgba(239,251,255,0.5)");
      halo.addColorStop(0.28, "rgba(137,196,255,0.24)");
      halo.addColorStop(1, "rgba(113,86,255,0)");
      ctx.globalAlpha = clamp(1 - age / 1.8, 0, 1);
      ctx.fillStyle = halo;
      ctx.beginPath();
      ctx.arc(pointer.x, pointer.y, radius, 0, Math.PI * 2);
      ctx.fill();
      var rotation = now * 0.0016;
      ctx.strokeStyle = "rgba(205,238,255,0.58)";
      ctx.lineWidth = 1.2;
      ctx.shadowColor = "rgba(125,155,255,0.8)";
      ctx.shadowBlur = 10;
      ctx.beginPath();
      ctx.arc(pointer.x, pointer.y, radius * 0.58, rotation, rotation + Math.PI * 1.15);
      ctx.stroke();
      ctx.strokeStyle = "rgba(183,143,255,0.46)";
      ctx.beginPath();
      ctx.arc(pointer.x, pointer.y, radius * 0.78, -rotation * 0.75, -rotation * 0.75 + Math.PI * 0.82);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }
    ctx.restore();
  }

  function drawParticles() {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    for (var i = 0; i < particles.length; i++) {
      var item = particles[i];
      if (!item.active) continue;
      var fade = 1 - item.age / item.life;
      ctx.globalAlpha = item.alpha * fade * fade;
      ctx.fillStyle = item.color;
      ctx.shadowColor = item.color;
      ctx.shadowBlur = item.size * 4;
      ctx.beginPath();
      ctx.arc(item.x, item.y, item.size * (0.5 + fade), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function frameForRow(source, row, time, fps) {
    var validFrames = source.validFramesByRow && source.validFramesByRow[row];
    if (validFrames && validFrames.length) {
      return validFrames[Math.floor(time * fps) % validFrames.length];
    }
    var frames = source.rowFrames && source.rowFrames[row] ? source.rowFrames[row] : FRAMES_PER_ROW;
    return Math.floor(time * fps) % frames;
  }

  function drawAnimal(item, heavyEffects) {
    if (!item.active || item.delay > 0) return;
    var source = species[item.speciesIndex];
    if (!source.loaded) return;
    var fadeIn = easeOutCubic(clamp(item.age / 1.1, 0, 1));
    var fadeOut = clamp((item.life - item.age) / 2.5, 0, 1);
    var zone = zoneAttenuation(item.x, item.y);
    var alpha = fadeIn * fadeOut * lerp(0.54, 0.94, item.depth) * zone;
    var sizeScale = (settings.size / 100) * item.scale;
    var drawHeight = 118 * sizeScale;
    var drawWidth = drawHeight * (CELL_WIDTH / CELL_HEIGHT);
    var row = clamp(stateRow(item), 0, ROWS - 1);
    var frame = frameForRow(source, row, item.age + item.phase, stateFps(item));
    var glowAmount = clamp(settings.glow / 100, 0, 1.4);
    var glow = settings.colorLink ? source.color : "#c9d7ff";
    var centerX = item.x + item.offsetX;
    var baseY = item.y + item.offsetY + item.visualLift;

    ctx.save();
    if (item.age < 1.15 && heavyEffects) {
      var arrival = clamp(item.age / 1.15, 0, 1);
      var arrivalRadius = lerp(14, drawWidth * 0.82, easeOutCubic(arrival));
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = (1 - arrival) * 0.42 * zone;
      ctx.strokeStyle = hexToRgba(glow, 0.9);
      ctx.lineWidth = lerp(2.2, 0.7, arrival);
      ctx.shadowColor = glow;
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.ellipse(item.x, item.y, arrivalRadius, arrivalRadius * 0.42, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }
    var travelX = item.x - item.lastX;
    var travelY = item.y - item.lastY;
    if ((travelX * travelX + travelY * travelY) > 1.2 && heavyEffects) {
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = alpha * 0.3 * glowAmount;
      ctx.strokeStyle = hexToRgba(glow, 0.72);
      ctx.lineWidth = lerp(1.5, 4, item.depth);
      ctx.lineCap = "round";
      ctx.shadowColor = glow;
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.moveTo(item.x - travelX * 5, item.y - travelY * 5);
      ctx.lineTo(item.x, item.y);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }
    ctx.globalAlpha = alpha;
    ctx.globalCompositeOperation = "source-over";
    if (heavyEffects) {
      ctx.shadowColor = hexToRgba(glow, 0.78);
      ctx.shadowBlur = lerp(8, 25, glowAmount) * lerp(0.7, 1.14, item.depth);
    }
    ctx.translate(centerX, baseY - drawHeight * 0.78 + drawHeight * 0.5);
    if (item.rollSpin) ctx.rotate(item.rollSpin);
    if (item.facing < 0) ctx.scale(-1, 1);
    ctx.drawImage(
      source.image,
      frame * CELL_WIDTH,
      row * CELL_HEIGHT,
      CELL_WIDTH,
      CELL_HEIGHT,
      -drawWidth * 0.5,
      -drawHeight * 0.5,
      drawWidth,
      drawHeight
    );
    ctx.setTransform(renderScale, 0, 0, renderScale, 0, 0);
    ctx.shadowBlur = 0;
    ctx.globalCompositeOperation = "lighter";
    ctx.globalAlpha = alpha * 0.55 * glowAmount;
    var glowImage = glowSprite(glow);
    var glowWidth = drawWidth * 1.5;
    var glowHeight = drawHeight * 0.34;
    ctx.drawImage(glowImage, centerX - glowWidth * 0.5, item.y + item.offsetY + drawHeight * 0.11 - glowHeight * 0.5, glowWidth, glowHeight);
    ctx.restore();
  }

  function drawScene(now) {
    ctx.clearRect(0, 0, width, height);
    drawAmbientTrail(now);
    drawParticles();
    drawOrder.length = 0;
    for (var index = 0; index < animals.length; index++) {
      if (animals[index].active) drawOrder.push(animals[index]);
    }
    drawOrder.sort(function (a, b) { return a.depth - b.depth; });
    var heavyEffects = drawOrder.length <= 34 && !isLowPower();
    for (var i = 0; i < drawOrder.length; i++) drawAnimal(drawOrder[i], heavyEffects);
  }

  function updatePerformance(now) {
    fpsFrames++;
    if (now - fpsClock < 1000) return;
    var fps = fpsFrames * 1000 / (now - fpsClock);
    smoothedFps = lerp(smoothedFps, fps, 0.28);
    fpsClock = now;
    fpsFrames = 0;
    var degradeThreshold = currentTargetFps >= 45 ? 30 : 22;
    if (smoothedFps < degradeThreshold && !adaptiveLowPower) {
      adaptiveLowPower = true;
      recoveryClock = now;
      trimTo(modeProfile().max);
      resize();
    } else if (adaptiveLowPower && smoothedFps > 22) {
      if (!recoveryClock) recoveryClock = now;
      if (now - recoveryClock > 8000) {
        adaptiveLowPower = false;
        recoveryClock = 0;
        resize();
      }
    } else if (adaptiveLowPower && smoothedFps <= 22) {
      recoveryClock = now;
    }
  }

  function detectSwipe(now) {
    if (now - lastSwipeTime < 750 || recentInput.length < 3) return;
    var start = recentInput[recentInput.length - 1];
    for (var i = recentInput.length - 2; i >= 0; i--) {
      if (now - recentInput[i].time > 450) break;
      start = recentInput[i];
    }
    var end = recentInput[recentInput.length - 1];
    var dx = end.x - start.x;
    var dy = end.y - start.y;
    var distance = Math.sqrt(dx * dx + dy * dy);
    var duration = Math.max(1, end.time - start.time);
    if (distance < 150 || distance / duration * 1000 < 550) return;
    if (Math.abs(dy) > Math.abs(dx) * 0.82) {
      lastSwipeTime = now;
      if (dy < 0) {
        // 快速上滑：动物跳起后落回轨迹
        metrics.verticalUp++;
        for (var verticalIndex = 0; verticalIndex < animals.length; verticalIndex++) {
          if (!animals[verticalIndex].active || Math.random() > 0.72) continue;
          animals[verticalIndex].state = "jump";
          animals[verticalIndex].stateTime = 0;
          animals[verticalIndex].stateDuration = 1.5;
        }
        emitBurst(end.x, end.y, "#a6e8ff", 30);
      } else {
        // 快速下滑：动物向底边环境光聚集，然后化为粒子消散
        metrics.verticalDown++;
        for (var downIndex = 0; downIndex < animals.length; downIndex++) {
          var downItem = animals[downIndex];
          if (!downItem.active || Math.random() > 0.55) continue;
          downItem.autonomous = true;
          downItem.state = "run";
          downItem.stateTime = 0;
          downItem.stateDuration = 3;
          downItem.roamX = clamp(end.x + random(-260, 260), 60, width - 60);
          downItem.roamY = height - random(90, 150);
          downItem.nextRoamAt = now + 4000;
          downItem.dissolveAt = now + random(1100, 2100);
        }
        emitBurst(end.x, Math.min(height - 92, end.y), "#a998ff", 34);
      }
      return;
    }
    if (Math.abs(dx) < Math.abs(dy) * 0.82) return;
    lastSwipeTime = now;
    metrics.swipes++;
    var direction = dx >= 0 ? 1 : -1;
    // 快速左右滑动：现有动物加速折返，并生成一小队快速奔跑的动物在两端往返
    for (var animalIndex = 0; animalIndex < animals.length; animalIndex++) {
      var swipeItem = animals[animalIndex];
      if (!swipeItem.active) continue;
      swipeItem.state = "run";
      swipeItem.stateTime = 0;
      swipeItem.stateDuration = random(1.2, 2.6);
      swipeItem.speedBoostUntil = now + 2200;
      swipeItem.foldUntil = now + 6000;
      if (!swipeItem.autonomous) swipeItem.direction = direction;
      else chooseRoamTarget(swipeItem, now, direction * 1.8);
    }
    if (settings.speedReactive && imagesReady > 0) {
      burstGroupId = ++groupSequence;
      burstSquad = true;
      burstQueue = Math.min(5, Math.max(0, modeProfile().max - activeAnimals));
    }
    var color = dx >= 0 ? "#91e4ff" : "#b79bff";
    emitBurst(end.x, end.y, color, 28);
  }

  function detectCircle(now) {
    if (now - lastGestureTime < 1800 || recentInput.length < 12) return;
    var points = [];
    for (var i = recentInput.length - 1; i >= 0; i--) {
      if (now - recentInput[i].time > 2600) break;
      points.unshift(recentInput[i]);
    }
    if (points.length < 12) return;
    var minX = Infinity;
    var minY = Infinity;
    var maxX = -Infinity;
    var maxY = -Infinity;
    var length = 0;
    var area = 0;
    for (var p = 0; p < points.length; p++) {
      minX = Math.min(minX, points[p].x);
      minY = Math.min(minY, points[p].y);
      maxX = Math.max(maxX, points[p].x);
      maxY = Math.max(maxY, points[p].y);
      if (p > 0) {
        var dx = points[p].x - points[p - 1].x;
        var dy = points[p].y - points[p - 1].y;
        length += Math.sqrt(dx * dx + dy * dy);
        area += points[p - 1].x * points[p].y - points[p].x * points[p - 1].y;
      }
    }
    var boxW = maxX - minX;
    var boxH = maxY - minY;
    var closeDx = points[0].x - points[points.length - 1].x;
    var closeDy = points[0].y - points[points.length - 1].y;
    var closeDistance = Math.sqrt(closeDx * closeDx + closeDy * closeDy);
    if (boxW < 110 || boxH < 90 || length < 360) return;
    if (closeDistance > Math.max(boxW, boxH) * 0.56) return;
    if (Math.abs(area) < boxW * boxH * 0.28) return;
    // 累计转角必须接近一整圈，避免 L 形或折线被误判为画圆
    var turning = 0;
    for (var q = 2; q < points.length; q++) {
      var a1 = Math.atan2(points[q - 1].y - points[q - 2].y, points[q - 1].x - points[q - 2].x);
      var a2 = Math.atan2(points[q].y - points[q - 1].y, points[q].x - points[q - 1].x);
      var delta = a2 - a1;
      while (delta > Math.PI) delta -= Math.PI * 2;
      while (delta < -Math.PI) delta += Math.PI * 2;
      turning += delta;
    }
    if (Math.abs(turning) < Math.PI * 1.55) return;
    lastGestureTime = now;
    metrics.circles++;
    triggerVortex((minX + maxX) * 0.5, (minY + maxY) * 0.5, Math.min(boxW, boxH) * 0.42, area > 0 ? 1 : -1, now);
  }

  function triggerVortex(x, y, radius, direction, now) {
    var assigned = 0;
    for (var i = 0; i < animals.length; i++) {
      var item = animals[i];
      if (!item.active || assigned >= Math.min(activeAnimals, 18)) continue;
      item.orbitUntil = now + random(3000, 4600);
      item.orbitX = x;
      item.orbitY = y;
      item.orbitRadius = radius * random(0.62, 1.18) + assigned * 9;
      item.orbitAngle = Math.atan2(item.y - y, item.x - x);
      item.orbitSpeed = direction * random(0.48, 0.9);
      assigned++;
    }
    emitBurst(x, y, "#c7b4ff", 42);
  }

  function onPointer(x, y, source) {
    if (!settings.enabled || paused) return;
    var now = performance.now();
    x = clamp(Number(x) || 0, 0, width);
    y = clamp(Number(y) || 0, 0, height);
    var last = path[path.length - 1];
    var dx = last ? x - last.x : 0;
    var dy = last ? y - last.y : 0;
    var distance = Math.sqrt(dx * dx + dy * dy);
    var duration = last ? Math.max(8, now - last.time) : 16;
    var stale = last && now - last.time > 900;
    pointer.x = x;
    pointer.y = y;
    pointer.dx = dx;
    pointer.dy = dy;
    pointer.speed = stale ? 0 : lerp(pointer.speed, distance / duration * 1000, 0.38);
    lastPointerTime = now;
    idleCleared = false;
    // 长时间停顿后重新移动：从当前位置重新起笔，不产生跨屏假轨迹
    if (stale && distance > 220) {
      appendPathPoint(x, y, now, true);
      nextSpawnDistance = pathDistance + 30;
      return;
    }
    if (!appendPathPoint(x, y, now, false)) return;
    recentInput.push({ x: x, y: y, time: now, source: source || "mouse" });
    while (recentInput.length > 120 || (recentInput[0] && now - recentInput[0].time > 3200)) recentInput.shift();

    classifyPointerSpeed();
    maybeQueueBurst(now);
    detectSwipe(now);
    if (now - lastGestureTime > 450) detectCircle(now);
  }

  function setPaused(value) {
    if (value && !settings.autoPause) return;
    paused = Boolean(value);
    if (paused) ctx.clearRect(0, 0, width, height);
    lastFrameTime = performance.now();
  }

  function setHostLowPower(value) {
    var next = Boolean(value);
    if (hostLowPower === next) return;
    hostLowPower = next;
    trimTo(modeProfile().max);
    resize();
  }

  function clearAll() {
    for (var i = 0; i < animals.length; i++) animals[i].active = false;
    for (var j = 0; j < particles.length; j++) particles[j].active = false;
    activeAnimals = 0;
    metrics.clears++;
    burstQueue = 0;
    path.length = 0;
    recentInput.length = 0;
    pathDistance = 0;
    nextSpawnDistance = 60;
    migrationTrimDistance = 0;
    if (idleBatchVisualKeys.size) {
      previousIdleBatchVisualKeys = new Set(idleBatchVisualKeys);
      previousIdleBatchNameKeys = new Set(idleBatchNameKeys);
      previousIdleBatchSpeciesIndexes = idleBatchSpeciesIndexes.slice();
    }
    idleBatchVisualKeys.clear();
    idleBatchNameKeys.clear();
    idleBatchSpeciesIndexes.length = 0;
    idleBatchSpawned = 0;
    idleBatchOpen = false;
    idleBatchNextAt = performance.now() + IDLE_TRIGGER_MS;
    ctx.clearRect(0, 0, width, height);
  }

  function onProperty(name, value) {
    switch (name) {
      case "animalTrailEnabled":
        settings.enabled = Boolean(value);
        if (!settings.enabled) clearAll();
        return true;
      case "animalTrailMode":
        settings.mode = clamp(Number(value) || 0, 0, 3);
        trimTo(modeProfile().max);
        return true;
      case "animalTrailDensity":
        settings.density = clamp(Number(value) || 0, 0, 100);
        trimTo(modeProfile().max);
        return true;
      case "animalTrailCustomMax":
        settings.customMax = clamp(Number(value) || 44, 10, 80);
        trimTo(modeProfile().max);
        return true;
      case "animalTrailSpecies":
        settings.speciesMode = clamp(Number(value) || 0, 0, 2);
        return true;
      case "animalTrailSize":
        settings.size = clamp(Number(value) || 100, 55, 150);
        return true;
      case "animalTrailGlow":
        settings.glow = clamp(Number(value) || 0, 0, 100);
        return true;
      case "animalTrailFrequency":
        settings.frequency = clamp(Number(value) || 100, 40, 160);
        return true;
      case "animalTrailSpeed":
        settings.speed = clamp(Number(value) || 100, 40, 160);
        return true;
      case "animalTrailRichness":
        settings.richness = clamp(Number(value) || 72, 0, 100);
        return true;
      case "animalTrailPingPong":
        settings.pingPong = Boolean(value);
        return true;
      case "animalTrailFlocking":
        settings.flocking = Boolean(value);
        return true;
      case "animalTrailSpeedReactive":
        settings.speedReactive = Boolean(value);
        return true;
      case "animalTrailColorLink":
        settings.colorLink = Boolean(value);
        return true;
      case "animalTrailParticles":
        settings.particles = Boolean(value);
        return true;
      case "animalTrailLowPower":
        settings.lowPower = Boolean(value);
        trimTo(modeProfile().max);
        resize();
        return true;
      case "animalTrailAutoPause":
        settings.autoPause = Boolean(value);
        return true;
      case "animalTrailClear":
        if (value) clearAll();
        return true;
      case "animalTrailReset":
        if (value) {
          settings.mode = 1;
          settings.density = 64;
          settings.customMax = 44;
          settings.speciesMode = 0;
          settings.size = 112;
          settings.glow = 80;
          settings.frequency = 100;
          settings.speed = 100;
          settings.richness = 82;
          settings.pingPong = true;
          settings.flocking = true;
          settings.speedReactive = true;
          settings.colorLink = true;
          settings.particles = true;
          settings.lowPower = false;
          settings.autoPause = true;
          clearAll();
        }
        return true;
      default:
        return false;
    }
  }

  function frame(hostDt) {
    var now = performance.now();
    resize();
    if (paused || !settings.enabled || document.hidden) {
      if (!idleCleared) {
        ctx.clearRect(0, 0, width, height);
        idleCleared = true;
      }
      lastFrameTime = now;
      lastRenderTime = now;
      return;
    }
    updateIdleBatch(now);
    // 等待下一批时仍由宿主循环低成本检查；没有可见内容则不重绘。
    if (activeAnimals === 0 && burstQueue === 0 && !hasActiveParticles() && now - lastPointerTime > 2600) {
      if (!idleCleared) {
        ctx.clearRect(0, 0, width, height);
        idleCleared = true;
      }
      lastFrameTime = now;
      lastRenderTime = now;
      return;
    }
    idleCleared = false;
    var isInteracting = now - lastPointerTime < 1400;
    currentTargetFps = isLowPower() ? 24 : isInteracting ? 45 : 24;
    if (lastRenderTime && now - lastRenderTime < 1000 / currentTargetFps) return;
    var rawDt = Math.max(0, (now - lastFrameTime) / 1000);
    lastFrameTime = now;
    lastRenderTime = now;
    updatePerformance(now);
    var dt = Math.min(0.04, rawDt || hostDt || 0.016);
    prunePath(now);
    updateSpawning(now);
    pointerControlledAnimals = 0;
    for (var i = 0; i < animals.length; i++) updateAnimal(animals[i], dt, now);
    applySeparation(now);
    updateParticles(dt);
    drawScene(now);
  }

  function activeIdentityStatus() {
    var visualKeys = new Set();
    var nameKeys = new Set();
    var duplicateSpecies = 0;
    var followerAnimals = 0;
    var pingPongAnimals = 0;
    var idleAnimals = 0;
    var trailAnimals = 0;
    for (var i = 0; i < animals.length; i++) {
      if (!animals[i].active) continue;
      if (!animals[i].autonomous) followerAnimals++;
      if (animals[i].origin === "idle") idleAnimals++;
      else trailAnimals++;
      if (animals[i].archetype === "shuttler") pingPongAnimals++;
      var item = species[animals[i].speciesIndex];
      var visualKey = identityVisual(item);
      var nameKey = item.nameKey || identityName(item);
      if (visualKeys.has(visualKey) || nameKeys.has(nameKey)) duplicateSpecies++;
      visualKeys.add(visualKey);
      nameKeys.add(nameKey);
    }
    return {
      uniqueSpecies: Math.min(visualKeys.size, nameKeys.size),
      duplicateSpecies: duplicateSpecies,
      followerAnimals: followerAnimals,
      pingPongAnimals: pingPongAnimals,
      idleAnimals: idleAnimals,
      trailAnimals: trailAnimals
    };
  }

  window.AnimalTrailSystem = {
    frame: frame,
    onPointer: onPointer,
    onProperty: onProperty,
    setPaused: setPaused,
    setHostLowPower: setHostLowPower,
    clear: clearAll,
    status: function () {
      var identityStatus = activeIdentityStatus();
      var profile = modeProfile();
      return {
        enabled: settings.enabled,
        generationMode: "idle-batches-plus-mouse-trail",
        activeAnimals: activeAnimals,
        imagesReady: imagesReady,
        fps: Math.round(smoothedFps),
        adaptiveLowPower: adaptiveLowPower,
        hostLowPower: hostLowPower,
        pathPoints: path.length,
        pathDistance: Math.round(pathDistance),
        speedClass: speedClass,
        catalogSpecies: catalogCount,
        uniqueCatalogVisuals: uniqueVisualCount,
        usedCatalogVisuals: usedVisualKeys.size,
        dynamicImagesLoaded: dynamicImagesLoaded,
        rejectedCatalogImages: rejectedCatalogImages,
        activeUniqueSpecies: identityStatus.uniqueSpecies,
        duplicateSpecies: identityStatus.duplicateSpecies,
        followerAnimals: identityStatus.followerAnimals,
        pingPongAnimals: identityStatus.pingPongAnimals,
        pointerControlledAnimals: pointerControlledAnimals,
        idleAnimals: identityStatus.idleAnimals,
        trailAnimals: identityStatus.trailAnimals,
        idleBatch: {
          id: idleBatchId,
          target: IDLE_BATCH_SIZE,
          spawned: idleBatchSpawned,
          active: activeIdleBatchCount(),
          species: idleBatchSpeciesIndexes.map(function (index) { return species[index] ? species[index].slug : ""; }),
          previousSpecies: previousIdleBatchSpeciesIndexes.map(function (index) { return species[index] ? species[index].slug : ""; })
        },
        idleCycleUniqueSpecies: idleCycleVisualKeys.size,
        overlapPairs: overlapPairs,
        profile: { target: profile.target, max: profile.max },
        softRetiringAnimals: retiringCount(),
        burstQueue: burstQueue,
        gestures: {
          swipes: metrics.swipes,
          circles: metrics.circles,
          verticalUp: metrics.verticalUp,
          verticalDown: metrics.verticalDown
        },
        spawns: metrics.spawns,
        trailSpawns: metrics.trailSpawns,
        burstSpawns: metrics.burstSpawns,
        idleSpawns: metrics.idleSpawns,
        idleBatches: metrics.idleBatches,
        idleBatchesCompleted: metrics.idleBatchesCompleted,
        softRetired: metrics.softRetired,
        clears: metrics.clears
      };
    }
  };

  resize();
})();
