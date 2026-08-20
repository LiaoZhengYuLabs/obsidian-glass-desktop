(function () {
  "use strict";

  if (window.SpaceEnvironmentSystem && typeof window.SpaceEnvironmentSystem.destroy === "function") {
    window.SpaceEnvironmentSystem.destroy();
  }

  var config = window.SpaceEnvironmentConfig;
  var root = document.getElementById("space-environment");
  if (!config || !root) return;

  var background = root.querySelector(".space-background");
  var starField = root.querySelector(".space-star-field");
  var constellationLayer = root.querySelector(".space-constellation-layer");
  var blackHoleLayer = root.querySelector(".space-black-hole-layer");
  var meteorLayer = root.querySelector(".space-meteor-layer");
  var heroLayer = root.querySelector(".space-hero-layer");
  var motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  var wallpaperHost = window.__ANIMAL_TRAIL_WALLPAPER_HOST__ === true;
  var layerNames = ["far", "middle", "near"];
  var state = {
    destroyed: false,
    paused: false,
    hostPaused: false,
    hostLowPower: false,
    documentPaused: wallpaperHost ? false : document.hidden,
    reducedMotion: motionQuery.matches,
    cometTimer: 0,
    extraCometTimer: 0,
    constellationTimer: 0,
    extraConstellationTimer: 0,
    resizeTimer: 0,
    activeComets: new Set(),
    extraComets: new Set(),
    activeConstellations: new Set(),
    extraConstellations: new Set(),
    activeMeteors: 0,
    activeHero: 0,
    stars: 0,
    starLayers: { far: 0, middle: 0, near: 0 },
    blackHoleParticles: 0,
    blackHoleSize: 0,
    parallaxFrame: 0,
    lastScheduleDelay: 0,
    lastComet: null,
    lastBurstCount: 0,
    lastConstellation: null,
    nextConstellation: 0,
    nextExtraConstellation: 6,
    nextConstellationSlot: 0,
    spawned: { regular: 0, rare: 0, extra: 0, constellations: 0, extraConstellations: 0 }
  };

  // Projected from the real Western constellation line data used by
  // d3-celestial/Stellarium. Radii reflect visual star magnitude.
  var constellationDefinitions = [
    { name: "白羊座", symbol: "♈", abbr: "ARI", points: [[90, 27.4], [29.3, 49], [11.6, 64], [10, 72.6]], lines: [[0, 1], [1, 2], [2, 3]], radii: [1.43, 1.86, 1.69, 1.35] },
    { name: "金牛座", symbol: "♉", abbr: "TAU", points: [[90, 34], [52.8, 45.2], [48.5, 46.7], [43.1, 47.3], [45, 42.7], [48.4, 38.7], [83.2, 16], [31.6, 54.9], [11.4, 61.5], [33.1, 70.5], [10, 63.2], [17.3, 84]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [3, 7], [7, 8], [8, 9], [8, 10], [10, 11]], radii: [1.6, 2.17, 1.48, 1.42, 1.38, 1.45, 1.96, 1.48, 1.39, 1.34, 1.43, 1.24] },
    { name: "双子座", symbol: "♊", abbr: "GEM", points: [[10, 49.6], [17.1, 49.6], [35.7, 40.3], [59.8, 22.2], [80.5, 16.4], [90, 30.1], [81.7, 34.1], [67.7, 51.4], [53.5, 56.4], [30.2, 71.2], [36.9, 83.6], [65.9, 70.7]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9], [9, 10], [7, 11]], radii: [1.51, 1.63, 1.58, 1.21, 1.98, 2.09, 1.3, 1.46, 1.32, 1.88, 1.5, 1.43] },
    { name: "巨蟹座", symbol: "♋", abbr: "CNC", points: [[71.4, 79.1], [57.3, 53.4], [55.9, 39.8], [59.4, 10], [28.6, 90]], lines: [[0, 1], [1, 2], [2, 3], [1, 4]], radii: [1.25, 1.34, 1.14, 1.1, 1.45] },
    { name: "狮子座", symbol: "♌", abbr: "LEO", points: [[24.6, 68.2], [23.9, 55.8], [32.2, 47.8], [67.3, 46], [90, 61.5], [67.4, 59.2], [30, 38.5], [14.5, 31.8], [10, 37.6]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0], [2, 6], [6, 7], [7, 8]], radii: [2.04, 1.46, 1.86, 1.71, 1.83, 1.5, 1.48, 1.35, 1.6] },
    { name: "处女座", symbol: "♍", abbr: "VIR", points: [[10, 38.2], [12.1, 46.7], [25.1, 51], [34.7, 52.4], [47.3, 59.6], [54.1, 69.6], [76.6, 60.5], [88.6, 59.9], [43.8, 30.4], [40.9, 43.8], [58.3, 50.9], [70.2, 47.1], [90, 46.5]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [8, 9], [9, 3], [4, 10], [10, 11], [11, 12]], radii: [1.31, 1.43, 1.35, 1.66, 1.22, 2.14, 1.3, 1.36, 1.63, 1.49, 1.49, 1.26, 1.39] },
    { name: "天秤座", symbol: "♎", abbr: "LIB", points: [[39.5, 72.4], [26.6, 36.1], [52.2, 10], [70.4, 31.2], [71.8, 83.6], [73.4, 90]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [1, 3]], radii: [1.52, 1.66, 1.7, 1.34, 1.43, 1.41] },
    { name: "天蝎座", symbol: "♏", abbr: "SCO", points: [[10, 34.1], [11.1, 23.8], [14.8, 15.5], [26.4, 32.5], [32.5, 35], [37.2, 40.3], [47.8, 58.2], [49, 69.2], [51, 81.9], [63.9, 84.5], [82.4, 83.8], [90, 75.3], [86.3, 72.1], [79.7, 66.4]], lines: [[0, 1], [1, 2], [1, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9], [9, 10], [10, 11], [11, 12], [12, 13]], radii: [1.62, 1.79, 1.71, 1.62, 2.12, 1.64, 1.79, 1.59, 1.42, 1.51, 1.9, 1.6, 1.76, 1.97] },
    { name: "射手座", symbol: "♐", abbr: "SGR", points: [[18.3, 68.4], [22.9, 61.7], [20.7, 48.9], [25.6, 36.6], [15.6, 24.3], [63.9, 90], [64.8, 79.2], [49.9, 49.1], [38, 41], [86.8, 82.7], [90, 64.2], [87.2, 39], [73.8, 35.1], [65.8, 34], [59, 36.1], [44.7, 39], [10, 50.6], [52.9, 42.9], [51.3, 26.2], [54.9, 24.2], [60.4, 18.4], [63.3, 15.3], [63.3, 10], [46.5, 24.5], [44, 29.1]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [5, 6], [6, 7], [7, 8], [8, 3], [9, 10], [10, 11], [11, 12], [12, 13], [13, 14], [14, 15], [15, 8], [8, 2], [2, 16], [16, 1], [1, 7], [7, 17], [17, 15], [15, 18], [18, 19], [19, 20], [20, 21], [21, 22], [18, 23], [23, 24], [24, 15]], radii: [1.57, 1.92, 1.67, 1.64, 1.36, 1.33, 1.33, 1.7, 1.55, 1.29, 1.22, 1.13, 1.16, 1.04, 1.09, 1.85, 1.6, 1.51, 1.39, 1.63, 1.08, 1.34, 1.18, 1.45, 1.09] },
    { name: "摩羯座", symbol: "♑", abbr: "CAP", points: [[10, 24.2], [13, 32.3], [20, 43.2], [35.5, 69.9], [40.6, 75.8], [71.8, 59.7], [90, 37.2], [83.8, 39.1], [67.8, 39.7], [53.2, 41.1]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9], [9, 0]], radii: [1.24, 1.58, 1.11, 1.28, 1.29, 1.38, 1.63, 1.4, 1.24, 1.3] },
    { name: "水瓶座", symbol: "♒", abbr: "AQR", points: [[10, 49.3], [12.3, 48.3], [30.2, 42], [45.9, 32.4], [53.2, 34.4], [56.5, 31.8], [59.5, 32], [67.4, 45.7], [79, 48.7], [75.1, 70.7], [46.2, 57.3], [51, 46.1], [54.9, 29.3], [81.4, 68.8], [90, 64.6]], lines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9], [2, 10], [3, 11], [5, 12], [13, 8], [8, 14]], radii: [1.38, 1.12, 1.62, 1.61, 1.36, 1.42, 1.31, 1.39, 1.21, 1.41, 1.24, 1.27, 1.1, 1.33, 1.1] },
    { name: "双鱼座", symbol: "♓", abbr: "PSC", points: [[68.3, 34], [67.4, 24.1], [70.9, 29.2], [67.3, 40.4], [76.3, 50.6], [82.5, 61.7], [90, 73.2], [86.2, 72.4], [80.7, 68.3], [75.7, 67.1], [68.3, 64.5], [63.5, 64], [57.1, 64.5], [34.9, 65.8], [26.2, 68], [20.8, 66.7], [17.4, 68.5], [16, 72.3], [20.4, 75.9], [27.1, 75], [29.1, 71.9], [10, 71.3]], lines: [[0, 1], [1, 2], [2, 0], [0, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9], [9, 10], [10, 11], [11, 12], [12, 13], [13, 14], [14, 15], [15, 16], [16, 17], [17, 18], [18, 19], [19, 20], [20, 14], [17, 21]], radii: [1.14, 1.18, 1.12, 1.14, 1.42, 1.25, 1.37, 1.15, 1.2, 1.09, .99, 1.25, 1.2, 1.31, 1.28, 1.25, 1.03, 1.4, 1.06, 1.19, 1.06, 1.19] }
  ];

  // Supplemental silhouettes make sparse real star maps readable at a
  // glance. The original points and lines above remain the scientific layer;
  // these low-cost guide paths are only a visual recognition aid.
  var constellationGuideLines = {
    ARI: [
      [[18, 67], [30, 50], [44, 54], [58, 42], [72, 53], [84, 37]],
      [[30, 50], [23, 34]],
      [[58, 42], [68, 27]]
    ],
    TAU: [
      [[25, 60], [38, 43], [50, 57], [62, 43], [75, 60]],
      [[38, 43], [29, 25], [20, 34]],
      [[62, 43], [71, 25], [80, 34]],
      [[45, 58], [50, 70], [55, 58]]
    ],
    GEM: [
      [[25, 75], [25, 25], [38, 18], [48, 28]],
      [[65, 75], [65, 25], [78, 18], [88, 28]],
      [[25, 41], [65, 41]]
    ],
    CNC: [
      [[25, 50], [40, 32], [60, 32], [75, 50], [60, 68], [40, 68], [25, 50]],
      [[40, 32], [50, 50], [60, 32]],
      [[40, 68], [50, 50], [60, 68]]
    ],
    LEO: [
      [[20, 65], [30, 50], [42, 38], [55, 30], [65, 40], [57, 52], [45, 57], [34, 66]],
      [[45, 57], [60, 68], [78, 62], [86, 48]],
      [[60, 68], [70, 80]]
    ],
    VIR: [
      [[18, 58], [32, 48], [45, 53], [57, 42], [70, 50], [84, 38]],
      [[45, 53], [42, 30], [50, 18]],
      [[45, 53], [56, 66], [72, 74]]
    ],
    LIB: [
      [[20, 36], [50, 36], [80, 36]],
      [[35, 36], [28, 68], [42, 68], [35, 36]],
      [[65, 36], [58, 68], [72, 68], [65, 36]],
      [[50, 36], [50, 20]]
    ],
    SCO: [
      [[18, 35], [30, 28], [42, 38], [50, 52], [55, 67], [68, 76], [82, 70], [88, 58]],
      [[82, 70], [90, 82], [82, 88]],
      [[30, 28], [26, 17]]
    ],
    SGR: [
      [[22, 68], [45, 48], [78, 18]],
      [[70, 18], [78, 18], [75, 27]],
      [[38, 48], [48, 57], [58, 48]],
      [[45, 48], [58, 62], [70, 72]]
    ],
    CAP: [
      [[18, 35], [32, 55], [50, 70], [68, 55], [84, 36], [65, 38], [50, 48], [34, 38], [18, 35]],
      [[50, 70], [62, 82], [80, 78]]
    ],
    AQR: [
      [[16, 34], [28, 44], [40, 34], [52, 44], [64, 34], [76, 44], [88, 34]],
      [[16, 58], [28, 68], [40, 58], [52, 68], [64, 58], [76, 68], [88, 58]]
    ],
    PSC: [
      [[18, 50], [28, 38], [40, 44], [46, 56], [38, 66], [26, 62], [18, 50]],
      [[82, 50], [72, 38], [60, 44], [54, 56], [62, 66], [74, 62], [82, 50]],
      [[46, 56], [54, 56]],
      [[46, 56], [50, 50], [54, 56]]
    ]
  };

  var constellationSlots = [
    { x: 9, y: 10, width: 17, rotation: -5 },
    { x: 34, y: 8, width: 18, rotation: 4 },
    { x: 57, y: 43, width: 17, rotation: -3 },
    { x: 10, y: 51, width: 18, rotation: 3 },
    { x: 35, y: 59, width: 17, rotation: -4 },
    { x: 63, y: 68, width: 16, rotation: 5 },
    { x: 53, y: 18, width: 15, rotation: -2 }
  ];

  function randomBetween(min, max) {
    return Math.random() * (max - min) + min;
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function toBoolean(value) {
    return value === true || value === 1 || value === "1" || value === "true";
  }

  function numericValue(value, fallback) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function isLowPower() {
    return config.performance.lowPower || state.hostLowPower;
  }

  function removeChildren(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function responsiveFactor() {
    if (window.innerWidth <= 720) return config.performance.mobileStarFactor;
    if (window.innerWidth <= 1100) return config.performance.tabletStarFactor;
    return 1;
  }

  function desiredStarCount() {
    var areaFactor = clamp((window.innerWidth * window.innerHeight) / (1920 * 1080), 0.72, 1.18);
    var powerFactor = isLowPower() ? config.performance.lowPowerStarFactor : 1;
    return clamp(
      Math.round(config.stars.count * areaFactor * responsiveFactor() * powerFactor),
      config.stars.minCount,
      config.stars.maxCount
    );
  }

  function allocateLayerCounts(total) {
    var far = Math.floor(total * config.stars.layers.far.ratio);
    var middle = Math.floor(total * config.stars.layers.middle.ratio);
    return {
      far: far,
      middle: middle,
      near: Math.max(1, total - far - middle)
    };
  }

  function starColor(layerName) {
    var roll = Math.random();
    if (layerName === "near" && roll > 0.86) return "#fff2de";
    if (roll > 0.7) return "#e8f2ff";
    return "#ffffff";
  }

  function starGlowColor(layerName) {
    if (layerName === "near") return "rgba(222, 235, 255, .52)";
    if (layerName === "middle") return "rgba(218, 232, 252, .28)";
    return "rgba(214, 230, 252, .12)";
  }

  function createStar(layerName, layerConfig) {
    var star = document.createElement("span");
    var core = document.createElement("i");
    var size = randomBetween(layerConfig.sizeMin, layerConfig.sizeMax);
    var quiet = Math.random() < config.stars.quietChance;
    var brightness = config.stars.brightness;
    var baselineCeiling = layerConfig.opacityMin + (layerConfig.opacityMax - layerConfig.opacityMin) * 0.72;
    var minOpacity = randomBetween(layerConfig.opacityMin, baselineCeiling) * brightness;
    var layerStrength = layerName === "far" ? 0.62 : layerName === "middle" ? 0.82 : 1;
    var amplitude = config.stars.twinkleStrength * layerStrength * randomBetween(0.48, 1);
    if (quiet) amplitude *= randomBetween(0.08, 0.2);
    var maxOpacity = clamp(
      minOpacity + amplitude,
      minOpacity + 0.008,
      Math.min(0.96, layerConfig.opacityMax * brightness + config.stars.twinkleStrength * 0.32)
    );
    var drift = config.stars.drift.enabled && Math.random() < config.stars.drift.chance;

    star.className = "space-star space-star--" + layerName;
    if (quiet) star.classList.add("space-star--quiet");
    if (drift) star.classList.add("space-star--drift");
    star.dataset.layer = layerName;
    star.style.left = randomBetween(0.7, 99.3).toFixed(2) + "%";
    star.style.top = randomBetween(0.7, 99.3).toFixed(2) + "%";
    star.style.setProperty("--star-size", size.toFixed(2) + "px");
    star.style.setProperty("--star-color", starColor(layerName));
    star.style.setProperty("--star-glow-color", starGlowColor(layerName));
    star.style.setProperty("--star-glow", randomBetween(layerConfig.glowMin, layerConfig.glowMax).toFixed(1) + "px");
    star.style.setProperty("--star-min-opacity", minOpacity.toFixed(3));
    star.style.setProperty("--star-max-opacity", maxOpacity.toFixed(3));
    star.style.setProperty("--star-mid-opacity", (minOpacity + (maxOpacity - minOpacity) * 0.58).toFixed(3));
    star.style.setProperty(
      "--star-twinkle-scale",
      randomBetween(quiet ? 1.005 : 1.018, quiet ? 1.02 : layerName === "near" ? 1.12 : 1.09).toFixed(3)
    );
    star.style.setProperty(
      "--star-duration",
      randomBetween(config.stars.durationMin, config.stars.durationMax).toFixed(0) + "ms"
    );
    star.style.setProperty(
      "--star-delay",
      (-randomBetween(0, config.stars.delayMax)).toFixed(0) + "ms"
    );

    if (drift) {
      var driftDistance = randomBetween(config.stars.drift.distanceMin, config.stars.drift.distanceMax);
      var driftAngle = randomBetween(0, Math.PI * 2);
      var driftX = Math.cos(driftAngle) * driftDistance;
      var driftY = Math.sin(driftAngle) * driftDistance;
      star.style.setProperty("--star-drift-x-from", (-driftX * 0.5).toFixed(2) + "px");
      star.style.setProperty("--star-drift-y-from", (-driftY * 0.5).toFixed(2) + "px");
      star.style.setProperty("--star-drift-x-to", (driftX * 0.5).toFixed(2) + "px");
      star.style.setProperty("--star-drift-y-to", (driftY * 0.5).toFixed(2) + "px");
      star.style.setProperty(
        "--star-drift-duration",
        randomBetween(config.stars.drift.durationMin, config.stars.drift.durationMax).toFixed(0) + "ms"
      );
      star.style.setProperty(
        "--star-drift-delay",
        (-randomBetween(0, config.stars.drift.durationMax)).toFixed(0) + "ms"
      );
    }

    core.className = "space-star-core";
    star.appendChild(core);
    return star;
  }

  function buildStars() {
    removeChildren(starField);
    if (!config.enabled || !config.stars.enabled) {
      state.stars = 0;
      state.starLayers = { far: 0, middle: 0, near: 0 };
      return;
    }

    var count = desiredStarCount();
    var counts = allocateLayerCounts(count);
    var fragment = document.createDocumentFragment();

    layerNames.forEach(function (layerName) {
      var layer = document.createElement("div");
      var layerFragment = document.createDocumentFragment();
      layer.className = "space-star-layer space-star-layer--" + layerName;
      layer.dataset.starLayer = layerName;
      for (var index = 0; index < counts[layerName]; index++) {
        layerFragment.appendChild(createStar(layerName, config.stars.layers[layerName]));
      }
      layer.appendChild(layerFragment);
      fragment.appendChild(layer);
    });

    starField.appendChild(fragment);
    state.stars = count;
    state.starLayers = counts;
    root.classList.toggle("space-no-twinkle", !config.stars.twinkle);
    root.classList.toggle("space-no-drift", !config.stars.drift.enabled);
  }

  function constellationMotionAllowed() {
    return !state.destroyed &&
      !state.paused &&
      config.enabled &&
      config.constellations.enabled &&
      // The adaptive host guard only reduces the expensive fluid layer.
      // Keep the lightweight constellation animation visible unless the user
      // explicitly enables the deep-space low-power property.
      !config.performance.lowPower;
  }

  function setSvgAttribute(node, name, value) {
    node.setAttribute(name, String(value));
  }

  function removeConstellation(constellation) {
    if (!constellation || (!state.activeConstellations.has(constellation) && !state.extraConstellations.has(constellation))) return;
    state.activeConstellations.delete(constellation);
    state.extraConstellations.delete(constellation);
    clearTimeout(constellation._spaceCleanupTimer);
    if (constellation.parentNode) constellation.parentNode.removeChild(constellation);
  }

  function clearActiveConstellations() {
    Array.from(state.activeConstellations).concat(Array.from(state.extraConstellations)).forEach(removeConstellation);
  }

  function createConstellation(definition, lifetime, slotIndex) {
    var svgNamespace = "http://www.w3.org/2000/svg";
    var slot = constellationSlots[slotIndex];
    var wrapper = document.createElement("div");
    var svg = document.createElementNS(svgNamespace, "svg");
    var guideLines = document.createElementNS(svgNamespace, "g");
    var lines = document.createElementNS(svgNamespace, "g");
    var stars = document.createElementNS(svgNamespace, "g");
    var glyph = document.createElement("span");
    var label = document.createElement("span");
    var tint = state.nextConstellation % 3;

    wrapper.className = "space-constellation space-constellation--tone-" + tint;
    wrapper.dataset.constellation = definition.name;
    wrapper.dataset.constellationCode = definition.abbr;
    wrapper.dataset.slot = String(slotIndex);
    wrapper.style.left = slot.x + "%";
    wrapper.style.top = slot.y + "%";
    wrapper.style.width = slot.width + "vw";
    wrapper.style.setProperty("--constellation-duration", lifetime + "ms");
    wrapper.style.setProperty("--constellation-rotation", slot.rotation + "deg");
    wrapper.style.setProperty("--constellation-drift-x", randomBetween(-11, 11).toFixed(1) + "px");
    wrapper.style.setProperty("--constellation-drift-y", randomBetween(-8, 8).toFixed(1) + "px");

    setSvgAttribute(svg, "viewBox", "0 0 100 100");
    setSvgAttribute(svg, "preserveAspectRatio", "xMidYMid meet");
    svg.classList.add("space-constellation-map");
    guideLines.classList.add("space-constellation-guide-lines");
    lines.classList.add("space-constellation-lines");
    stars.classList.add("space-constellation-stars");

    (constellationGuideLines[definition.abbr] || []).forEach(function (path) {
      var polyline = document.createElementNS(svgNamespace, "polyline");
      setSvgAttribute(polyline, "points", path.map(function (point) {
        return point[0] + "," + point[1];
      }).join(" "));
      guideLines.appendChild(polyline);
    });

    definition.lines.forEach(function (edge, index) {
      var start = definition.points[edge[0]];
      var end = definition.points[edge[1]];
      var line = document.createElementNS(svgNamespace, "line");
      setSvgAttribute(line, "x1", start[0]);
      setSvgAttribute(line, "y1", start[1]);
      setSvgAttribute(line, "x2", end[0]);
      setSvgAttribute(line, "y2", end[1]);
      line.style.setProperty("--constellation-line-delay", (index * 75) + "ms");
      lines.appendChild(line);
    });

    definition.points.forEach(function (point, index) {
      var halo = document.createElementNS(svgNamespace, "circle");
      var core = document.createElementNS(svgNamespace, "circle");
      var radius = definition.radii && definition.radii[index]
        ? definition.radii[index]
        : index % 4 === 0 ? 1.65 : index % 3 === 0 ? 1.3 : 1.02;
      setSvgAttribute(halo, "cx", point[0]);
      setSvgAttribute(halo, "cy", point[1]);
      setSvgAttribute(halo, "r", radius * 3.1);
      setSvgAttribute(core, "cx", point[0]);
      setSvgAttribute(core, "cy", point[1]);
      setSvgAttribute(core, "r", radius);
      halo.classList.add("space-constellation-star-halo");
      core.classList.add("space-constellation-star-core");
      core.style.setProperty("--constellation-star-delay", (-index * 310) + "ms");
      core.style.setProperty("--constellation-star-duration", randomBetween(1800, 3600).toFixed(0) + "ms");
      stars.appendChild(halo);
      stars.appendChild(core);
    });

    glyph.className = "space-constellation-glyph";
    glyph.textContent = definition.symbol;
    glyph.setAttribute("aria-hidden", "true");
    label.className = "space-constellation-label";
    label.textContent = definition.symbol + "  " + definition.name + " · " + definition.abbr;
    wrapper.title = definition.name + " (" + definition.abbr + ")";
    svg.appendChild(guideLines);
    svg.appendChild(lines);
    svg.appendChild(stars);
    wrapper.appendChild(glyph);
    wrapper.appendChild(svg);
    wrapper.appendChild(label);
    return wrapper;
  }

  function chooseConstellationSlot() {
    var usedNodes = Array.from(state.activeConstellations).concat(Array.from(state.extraConstellations));
    var used = new Set(usedNodes.map(function (node) {
      return Number(node.dataset.slot);
    }));
    for (var offset = 0; offset < constellationSlots.length; offset++) {
      var candidate = (state.nextConstellationSlot + offset) % constellationSlots.length;
      if (!used.has(candidate)) {
        state.nextConstellationSlot = (candidate + 1) % constellationSlots.length;
        return candidate;
      }
    }
    return state.nextConstellationSlot++ % constellationSlots.length;
  }

  function spawnConstellation(isExtra) {
    if (!constellationMotionAllowed() || !constellationLayer) return null;
    var channel = isExtra ? state.extraConstellations : state.activeConstellations;
    var channelConfig = isExtra ? config.extraConstellations : config.constellations;
    if (!channelConfig || !channelConfig.enabled) return null;
    while (channel.size >= channelConfig.maxActive) {
      removeConstellation(channel.values().next().value);
    }

    var definitionIndex = (isExtra ? state.nextExtraConstellation : state.nextConstellation) % constellationDefinitions.length;
    var definition = constellationDefinitions[definitionIndex];
    var lifetimes = config.constellations.lifetimes;
    var lifetime = lifetimes[definitionIndex % lifetimes.length];
    var constellation = createConstellation(definition, lifetime, chooseConstellationSlot());
    if (isExtra) state.nextExtraConstellation++;
    else state.nextConstellation++;
    state.spawned.constellations++;
    if (isExtra) state.spawned.extraConstellations++;
    state.lastConstellation = {
      name: definition.name,
      symbol: definition.symbol,
      lifetime: lifetime
    };
    constellationLayer.appendChild(constellation);
    channel.add(constellation);
    constellation.dataset.constellationChannel = isExtra ? "extra" : "standard";

    constellation.addEventListener("animationend", function onAnimationEnd(event) {
      if (event.target === constellation && event.animationName === "space-constellation-life") {
        removeConstellation(constellation);
      }
    });
    constellation._spaceCleanupTimer = window.setTimeout(function () {
      removeConstellation(constellation);
    }, lifetime + 320);
    return constellation;
  }

  function scheduleConstellation() {
    clearTimeout(state.constellationTimer);
    state.constellationTimer = 0;
    if (!constellationMotionAllowed()) return;
    state.constellationTimer = window.setTimeout(function () {
      if (state.destroyed) return;
      spawnConstellation(false);
      scheduleConstellation();
    }, config.constellations.spawnInterval);
  }

  function scheduleExtraConstellation() {
    clearTimeout(state.extraConstellationTimer);
    state.extraConstellationTimer = 0;
    if (!constellationMotionAllowed() || !config.extraConstellations || !config.extraConstellations.enabled) return;
    state.extraConstellationTimer = window.setTimeout(function () {
      if (state.destroyed) return;
      spawnConstellation(true);
      scheduleExtraConstellation();
    }, config.extraConstellations.spawnInterval);
  }

  function createBlackHolePart(className, tagName) {
    var element = document.createElement(tagName || "div");
    element.className = className;
    return element;
  }

  function desiredBlackHoleSize() {
    var viewportScale = clamp(Math.min(window.innerWidth, window.innerHeight) / 1080, 0.72, 1.12);
    return clamp(config.blackHole.baseSize * viewportScale * config.blackHole.sizeScale, 210, 540);
  }

  function applyBlackHoleGeometry() {
    if (!blackHoleLayer) return;
    var scene = blackHoleLayer.querySelector(".space-black-hole");
    if (!scene) return;
    var size = desiredBlackHoleSize();
    var compression = clamp(config.blackHole.diskCompression, 0.2, 0.48);
    scene.style.setProperty("--black-hole-size", size.toFixed(1) + "px");
    scene.style.setProperty("--black-hole-position-x", config.blackHole.positionX.toFixed(1) + "%");
    scene.style.setProperty("--black-hole-position-y", config.blackHole.positionY.toFixed(1) + "%");
    scene.style.setProperty("--black-hole-intensity", config.blackHole.intensity.toFixed(2));
    scene.style.setProperty("--black-hole-tilt", config.blackHole.tilt.toFixed(1) + "deg");
    scene.style.setProperty("--black-hole-disk-compression", compression.toFixed(3));
    scene.style.setProperty("--black-hole-particle-counter-scale", (1 / compression).toFixed(3));
    scene.style.setProperty("--black-hole-spin-duration", config.blackHole.spinDuration.toFixed(0) + "ms");
    scene.style.setProperty("--black-hole-counter-spin-duration", config.blackHole.counterSpinDuration.toFixed(0) + "ms");
    scene.style.setProperty("--black-hole-pulse-duration", config.blackHole.pulseDuration.toFixed(0) + "ms");
    Array.from(scene.querySelectorAll(".space-black-hole-orbit")).forEach(function (orbit) {
      var radiusRatio = numericValue(orbit.dataset.radiusRatio, 0.4);
      orbit.style.setProperty("--black-hole-particle-radius", (size * radiusRatio).toFixed(1) + "px");
    });
    state.blackHoleSize = size;
  }

  function buildBlackHole() {
    if (!blackHoleLayer) return;
    removeChildren(blackHoleLayer);
    state.blackHoleParticles = 0;
    state.blackHoleSize = 0;
    if (!config.blackHole.enabled) return;

    var scene = createBlackHolePart("space-black-hole");
    var aura = createBlackHolePart("space-black-hole-aura");
    var lensing = createBlackHolePart("space-black-hole-lensing");
    var backPlane = createBlackHolePart("space-black-hole-disk-plane space-black-hole-disk-plane--back");
    var backSurface = createBlackHolePart("space-black-hole-disk-surface space-black-hole-disk-surface--back");
    var core = createBlackHolePart("space-black-hole-core");
    var frontPlane = createBlackHolePart("space-black-hole-disk-plane space-black-hole-disk-plane--front");
    var frontSurface = createBlackHolePart("space-black-hole-disk-surface space-black-hole-disk-surface--front");
    var photonRing = createBlackHolePart("space-black-hole-photon-ring");
    var particleField = createBlackHolePart("space-black-hole-particle-field");
    var particleCount = isLowPower() ? 0 : clamp(Math.round(config.blackHole.particleCount), 0, 18);

    backPlane.appendChild(backSurface);
    frontPlane.appendChild(frontSurface);
    for (var index = 0; index < particleCount; index++) {
      var orbit = createBlackHolePart("space-black-hole-orbit");
      var particle = createBlackHolePart("space-black-hole-particle", "i");
      var radiusRatio = randomBetween(0.29, 0.49);
      orbit.dataset.radiusRatio = radiusRatio.toFixed(4);
      orbit.style.setProperty("--black-hole-orbit-start", randomBetween(0, 360).toFixed(1) + "deg");
      orbit.style.setProperty("--black-hole-orbit-duration", randomBetween(14000, 29000).toFixed(0) + "ms");
      orbit.style.setProperty("--black-hole-orbit-delay", (-randomBetween(0, 29000)).toFixed(0) + "ms");
      particle.style.setProperty("--black-hole-particle-size", randomBetween(0.8, 2.2).toFixed(1) + "px");
      particle.style.setProperty("--black-hole-particle-opacity", randomBetween(0.18, 0.58).toFixed(2));
      particle.style.setProperty(
        "--black-hole-particle-color",
        Math.random() > 0.46 ? "rgba(239, 218, 188, .9)" : "rgba(216, 229, 244, .82)"
      );
      orbit.appendChild(particle);
      particleField.appendChild(orbit);
    }

    scene.appendChild(aura);
    scene.appendChild(backPlane);
    scene.appendChild(particleField);
    scene.appendChild(core);
    scene.appendChild(frontPlane);
    scene.appendChild(lensing);
    scene.appendChild(photonRing);
    blackHoleLayer.appendChild(scene);
    state.blackHoleParticles = particleCount;
    applyBlackHoleGeometry();
  }

  function cometMotionAllowed() {
    return !state.destroyed &&
      !state.paused &&
      config.enabled &&
      config.comets.enabled &&
      // Host low power is an automatic fluid safeguard, not a request to
      // remove the user's meteor layer.
      !config.performance.lowPower &&
      (config.comets.regular.enabled || config.comets.rare.enabled);
  }

  function nextCometDelay(first) {
    var min = first ? config.comets.firstSpawnMin : config.comets.spawnMin;
    var max = first ? config.comets.firstSpawnMax : config.comets.spawnMax;
    var delay = randomBetween(min, max) * config.comets.frequencyScale;
    if (!first && Math.random() < config.comets.longGapChance) {
      delay *= randomBetween(config.comets.longGapMultiplierMin, config.comets.longGapMultiplierMax);
    }
    return delay;
  }

  function scheduleComet(first) {
    clearTimeout(state.cometTimer);
    state.cometTimer = 0;
    if (!cometMotionAllowed()) return;
    var delay = nextCometDelay(Boolean(first));
    state.lastScheduleDelay = delay;
    state.cometTimer = window.setTimeout(function () {
      if (state.destroyed) return;
      spawnScheduledComet();
      scheduleComet(false);
    }, delay);
  }

  function chooseRareComet() {
    if (!config.comets.regular.enabled) return config.comets.rare.enabled;
    return config.comets.rare.enabled && Math.random() < config.comets.rare.probability;
  }

  function chooseTrajectory() {
    var entranceRoll = Math.random();
    var trajectory;
    if (entranceRoll < 0.34) {
      var fromLeft = Math.random() < 0.5;
      trajectory = {
        entrance: "top",
        startX: randomBetween(7, 93),
        startY: randomBetween(-8, -2),
        angle: fromLeft ? randomBetween(20, 70) : randomBetween(110, 160)
      };
    } else if (entranceRoll < 0.52) {
      trajectory = {
        entrance: "top-left",
        startX: randomBetween(-10, 5),
        startY: randomBetween(-7, 18),
        angle: randomBetween(24, 62)
      };
    } else if (entranceRoll < 0.7) {
      trajectory = {
        entrance: "top-right",
        startX: randomBetween(95, 108),
        startY: randomBetween(-7, 18),
        angle: randomBetween(118, 156)
      };
    } else if (entranceRoll < 0.85) {
      trajectory = {
        entrance: "left",
        startX: randomBetween(-10, -3),
        startY: randomBetween(12, 52),
        angle: randomBetween(20, 54)
      };
    } else {
      trajectory = {
        entrance: "right",
        startX: randomBetween(103, 110),
        startY: randomBetween(12, 52),
        angle: randomBetween(126, 160)
      };
    }
    return trajectory;
  }

  function removeComet(comet) {
    if (!comet || !state.activeComets.has(comet)) return;
    state.activeComets.delete(comet);
    state.extraComets.delete(comet);
    clearTimeout(comet._spaceCleanupTimer);
    if (comet.classList.contains("space-comet--rare")) {
      state.activeHero = Math.max(0, state.activeHero - 1);
    } else {
      state.activeMeteors = Math.max(0, state.activeMeteors - 1);
    }
    if (comet.parentNode) comet.parentNode.removeChild(comet);
  }

  function clearActiveComets() {
    Array.from(state.activeComets).forEach(removeComet);
  }

  function createComet(isRare) {
    var cometConfig = isRare ? config.comets.rare : config.comets.regular;
    var trajectory = chooseTrajectory();
    var wrapper = document.createElement("div");
    var body = document.createElement("div");
    var tail = document.createElement("div");
    var glow = document.createElement("div");
    var head = document.createElement("div");
    var baseHeadSize = randomBetween(cometConfig.headSizeMin, cometConfig.headSizeMax);
    var baseTailLength = randomBetween(cometConfig.tailLengthMin, cometConfig.tailLengthMax);
    var visualHeadMax = isRare ? 16 : cometConfig.headSizeMax;
    var visualTailMax = isRare ? 270 : cometConfig.tailLengthMax;
    var allowedScaleMin = Math.max(
      cometConfig.scaleMin,
      cometConfig.headSizeMin / baseHeadSize,
      cometConfig.tailLengthMin / baseTailLength
    );
    var allowedScaleMax = Math.min(
      cometConfig.scaleMax,
      visualHeadMax / baseHeadSize,
      visualTailMax / baseTailLength
    );
    var scale = allowedScaleMax >= allowedScaleMin
      ? randomBetween(allowedScaleMin, allowedScaleMax)
      : clamp(1, cometConfig.scaleMin, cometConfig.scaleMax);
    var headSize = baseHeadSize * config.comets.sizeScale;
    var tailLength = baseTailLength * config.comets.sizeScale;
    var opacity = randomBetween(cometConfig.opacityMin, cometConfig.opacityMax);
    var brightness = randomBetween(cometConfig.brightnessMin, cometConfig.brightnessMax);
    var duration = randomBetween(cometConfig.durationMin, cometConfig.durationMax);
    var diagonal = Math.hypot(window.innerWidth, window.innerHeight);
    var travelDistance = diagonal * randomBetween(1.04, 1.26) + tailLength * scale;
    var tailHeight = clamp(headSize * (isRare ? 0.82 : 0.62), isRare ? 6 : 5, isRare ? 14 : 8.5);
    var glowSize = headSize * (isRare ? 5.2 : 3.5);

    wrapper.className = "space-comet " +
      (isRare ? "space-hero-comet space-comet--rare" : "space-meteor space-comet--regular");
    wrapper.dataset.cometType = isRare ? "rare" : "regular";
    wrapper.dataset.entrance = trajectory.entrance;
    body.className = "space-comet-body" + (isRare ? " space-hero-body" : "");
    tail.className = "space-comet-tail " + (isRare ? "space-hero-tail" : "space-meteor-streak");
    glow.className = "space-comet-glow " + (isRare ? "space-hero-glow" : "space-meteor-glow");
    head.className = "space-comet-head " + (isRare ? "space-hero-core" : "space-meteor-head");

    wrapper.style.setProperty("--start-x", trajectory.startX.toFixed(2) + "vw");
    wrapper.style.setProperty("--start-y", trajectory.startY.toFixed(2) + "vh");
    wrapper.style.setProperty("--comet-angle", trajectory.angle.toFixed(1) + "deg");
    wrapper.style.setProperty("--comet-distance", travelDistance.toFixed(0) + "px");
    wrapper.style.setProperty("--comet-duration", duration.toFixed(0) + "ms");
    wrapper.style.setProperty("--comet-scale", scale.toFixed(2));
    wrapper.style.setProperty("--comet-opacity", opacity.toFixed(2));
    wrapper.style.setProperty("--comet-brightness", brightness.toFixed(2));
    wrapper.style.setProperty("--comet-head-size", headSize.toFixed(1) + "px");
    wrapper.style.setProperty("--comet-tail-length", tailLength.toFixed(0) + "px");
    wrapper.style.setProperty("--comet-tail-height", tailHeight.toFixed(1) + "px");
    wrapper.style.setProperty("--comet-glow-size", glowSize.toFixed(1) + "px");
    wrapper.style.setProperty("--comet-entry-distance", Math.min(72, travelDistance * 0.08).toFixed(0) + "px");

    body.appendChild(tail);
    body.appendChild(glow);
    body.appendChild(head);
    wrapper.appendChild(body);
    return {
      element: wrapper,
      duration: duration,
      data: {
        type: isRare ? "rare" : "regular",
        entrance: trajectory.entrance,
        angle: trajectory.angle,
        descentAngle: trajectory.angle > 90 ? 180 - trajectory.angle : trajectory.angle,
        headSize: headSize,
        tailLength: tailLength,
        visualHeadSize: headSize * scale,
        visualTailLength: tailLength * scale,
        scale: scale,
        opacity: opacity,
        duration: duration,
        distance: travelDistance
      }
    };
  }

  function spawnComet(isRare, isExtra) {
    var standardCount = state.activeComets.size - state.extraComets.size;
    var extraCount = state.extraComets.size;
    var channelLimit = isExtra && config.extraComets ? config.extraComets.maxActive : config.comets.maxActive;
    if (!cometMotionAllowed() || (isExtra ? extraCount >= channelLimit : standardCount >= channelLimit)) return null;
    var cometConfig = isRare ? config.comets.rare : config.comets.regular;
    if (!cometConfig.enabled) return null;

    var created = createComet(isRare);
    var wrapper = created.element;
    var layer = isRare ? heroLayer : meteorLayer;
    layer.appendChild(wrapper);
    state.activeComets.add(wrapper);
    if (isExtra) {
      state.extraComets.add(wrapper);
      wrapper.dataset.cometChannel = "extra";
    } else {
      wrapper.dataset.cometChannel = "standard";
    }
    if (isRare) {
      state.activeHero++;
      state.spawned.rare++;
    } else {
      state.activeMeteors++;
      state.spawned.regular++;
    }
    if (isExtra) state.spawned.extra++;
    state.lastComet = created.data;

    wrapper.addEventListener("animationend", function onAnimationEnd(event) {
      if (event.target === wrapper && event.animationName === "space-comet-flight") {
        removeComet(wrapper);
      }
    });
    wrapper._spaceCleanupTimer = window.setTimeout(function () {
      removeComet(wrapper);
    }, created.duration + 260);
    return wrapper;
  }

  function spawnScheduledComet() {
    var standardCount = state.activeComets.size - state.extraComets.size;
    if (standardCount >= config.comets.maxActive) return null;
    var available = config.comets.maxActive - standardCount;
    var count = 1;
    if (Math.random() < config.comets.burstChance) {
      count = Math.floor(randomBetween(config.comets.burstMin, config.comets.burstMax + 1));
    }
    count = Math.min(count, available);
    var first = null;
    for (var index = 0; index < count; index++) {
      var comet = spawnComet(chooseRareComet());
      if (!first) first = comet;
    }
    state.lastBurstCount = count;
    return first;
  }

  function spawnExtraComet() {
    if (!config.extraComets || !config.extraComets.enabled || state.extraComets.size >= config.extraComets.maxActive) return null;
    var available = config.extraComets.maxActive - state.extraComets.size;
    var count = 1;
    if (Math.random() < config.extraComets.burstChance) {
      count = Math.floor(randomBetween(config.extraComets.burstMin, config.extraComets.burstMax + 1));
    }
    count = Math.min(count, available);
    var first = null;
    for (var index = 0; index < count; index++) {
      var rare = config.comets.rare.enabled && Math.random() < config.extraComets.rareProbability;
      var comet = spawnComet(rare, true);
      if (!first) first = comet;
    }
    return first;
  }

  function scheduleExtraComet() {
    clearTimeout(state.extraCometTimer);
    state.extraCometTimer = 0;
    if (!cometMotionAllowed() || !config.extraComets || !config.extraComets.enabled) return;
    state.extraCometTimer = window.setTimeout(function () {
      if (state.destroyed) return;
      spawnExtraComet();
      scheduleExtraComet();
    }, randomBetween(config.extraComets.spawnMin, config.extraComets.spawnMax));
  }

  function applyVisualConfig(rebuildStars, rebuildBlackHole) {
    root.hidden = !config.enabled;
    background.style.display = config.background.enabled ? "block" : "none";
    if (blackHoleLayer) blackHoleLayer.style.display = config.blackHole.enabled ? "block" : "none";
    root.style.setProperty("--space-background-opacity", String(config.background.opacity));
    root.style.setProperty("--space-background-image", "url('" + config.background.image + "')");
    root.classList.toggle("space-low-power", isLowPower());
    root.classList.toggle("space-host-low-power", state.hostLowPower);
    root.classList.toggle("space-reduced-motion", state.reducedMotion);
    root.classList.toggle("space-no-twinkle", !config.stars.twinkle);
    root.classList.toggle("space-no-drift", !config.stars.drift.enabled);
    if (constellationLayer) {
      constellationLayer.style.display = config.constellations.enabled ? "block" : "none";
    }
    root.classList.toggle(
      "space-black-hole-static",
      !config.blackHole.motion || state.reducedMotion || isLowPower()
    );
    if (rebuildStars !== false) buildStars();
    if (rebuildBlackHole) buildBlackHole();
    else applyBlackHoleGeometry();
  }

  function updatePauseState(firstSchedule) {
    if (state.destroyed) return;
    state.paused = state.hostPaused || state.documentPaused;
    root.classList.toggle("space-paused", state.paused);
    clearTimeout(state.cometTimer);
    clearTimeout(state.extraCometTimer);
    clearTimeout(state.constellationTimer);
    clearTimeout(state.extraConstellationTimer);
    state.cometTimer = 0;
    state.extraCometTimer = 0;
    state.constellationTimer = 0;
    state.extraConstellationTimer = 0;
    if (!cometMotionAllowed()) {
      clearActiveComets();
    } else {
      scheduleComet(Boolean(firstSchedule));
      scheduleExtraComet();
    }
    if (!constellationMotionAllowed()) {
      clearActiveConstellations();
    } else {
      scheduleConstellation();
      scheduleExtraConstellation();
    }
  }

  function setPaused(value) {
    if (state.destroyed) return false;
    state.hostPaused = Boolean(value);
    updatePauseState(false);
    return true;
  }

  function setHostLowPower(value) {
    if (state.destroyed) return false;
    var next = Boolean(value);
    if (state.hostLowPower === next) return true;
    state.hostLowPower = next;
    applyVisualConfig(true, true);
    updatePauseState(false);
    return true;
  }

  function onProperty(name, value) {
    if (state.destroyed) return false;
    var rebuildStars = false;
    var rebuildBlackHole = false;
    switch (name) {
      case "spaceEnvironmentEnabled":
        config.enabled = toBoolean(value);
        break;
      case "spaceBackgroundEnabled":
        config.background.enabled = toBoolean(value);
        break;
      case "spaceStarTwinkle":
        config.stars.twinkle = toBoolean(value);
        break;
      case "spaceStarDrift":
        config.stars.drift.enabled = toBoolean(value);
        break;
      case "spaceConstellationsEnabled":
        config.constellations.enabled = toBoolean(value);
        break;
      case "spaceBlackHoleEnabled":
        config.blackHole.enabled = toBoolean(value);
        rebuildBlackHole = true;
        break;
      case "spaceBlackHoleMotion":
        config.blackHole.motion = toBoolean(value);
        break;
      case "spaceBlackHoleIntensity":
        config.blackHole.intensity = clamp(numericValue(value, 58) / 100, 0.2, 1);
        break;
      case "spaceBlackHoleSize":
        config.blackHole.sizeScale = clamp(numericValue(value, 100) / 100, 0.6, 1.4);
        break;
      case "spaceBlackHolePositionX":
        config.blackHole.positionX = clamp(numericValue(value, 76), 12, 88);
        break;
      case "spaceBlackHolePositionY":
        config.blackHole.positionY = clamp(numericValue(value, 29), 12, 78);
        break;
      case "spaceStarCount":
        config.stars.count = clamp(
          numericValue(value, config.stars.count),
          config.stars.minCount,
          config.stars.maxCount
        );
        rebuildStars = true;
        break;
      case "spaceStarBrightness":
        config.stars.brightness = clamp(numericValue(value, 84) / 100, 0.2, 1.15);
        rebuildStars = true;
        break;
      case "spaceStarTwinkleStrength":
        config.stars.twinkleStrength = clamp(numericValue(value, 16) / 100, 0.01, 0.35);
        rebuildStars = true;
        break;
      case "spaceMeteorsEnabled":
        config.comets.regular.enabled = toBoolean(value);
        break;
      case "spaceHeroCometEnabled":
        config.comets.rare.enabled = toBoolean(value);
        break;
      case "spaceCometFrequency":
        config.comets.frequencyScale = clamp(100 / Math.max(1, numericValue(value, 100)), 0.55, 2);
        break;
      case "spaceCometSize":
        config.comets.sizeScale = clamp(numericValue(value, 100) / 100, 0.6, 1.6);
        break;
      case "spaceHeroProbability":
        config.comets.rare.probability = clamp(numericValue(value, 10) / 100, 0, 0.3);
        break;
      case "spaceLowPower":
        config.performance.lowPower = toBoolean(value);
        rebuildStars = true;
        rebuildBlackHole = true;
        break;
      default:
        return false;
    }
    applyVisualConfig(rebuildStars, rebuildBlackHole);
    updatePauseState(false);
    return true;
  }

  function onPointerMove(event) {
    if (state.destroyed || state.reducedMotion || !config.parallax.enabled || isLowPower() || state.paused) return;
    if (state.parallaxFrame) return;
    var x = (event.clientX / Math.max(1, window.innerWidth) - 0.5) * config.parallax.strength;
    var y = (event.clientY / Math.max(1, window.innerHeight) - 0.5) * config.parallax.strength;
    state.parallaxFrame = requestAnimationFrame(function () {
      if (state.destroyed) {
        state.parallaxFrame = 0;
        return;
      }
      root.style.setProperty("--space-shift-x", x.toFixed(2) + "px");
      root.style.setProperty("--space-shift-y", y.toFixed(2) + "px");
      root.style.setProperty("--space-far-shift-x", (x * 0.12).toFixed(2) + "px");
      root.style.setProperty("--space-far-shift-y", (y * 0.12).toFixed(2) + "px");
      root.style.setProperty("--space-middle-shift-x", (x * 0.3).toFixed(2) + "px");
      root.style.setProperty("--space-middle-shift-y", (y * 0.3).toFixed(2) + "px");
      root.style.setProperty("--space-near-shift-x", (x * 0.52).toFixed(2) + "px");
      root.style.setProperty("--space-near-shift-y", (y * 0.52).toFixed(2) + "px");
      root.style.setProperty("--space-black-hole-shift-x", (x * 0.18).toFixed(2) + "px");
      root.style.setProperty("--space-black-hole-shift-y", (y * 0.18).toFixed(2) + "px");
      state.parallaxFrame = 0;
    });
  }

  function onResize() {
    if (state.destroyed) return;
    clearTimeout(state.resizeTimer);
    state.resizeTimer = window.setTimeout(function () {
      if (state.destroyed) return;
      buildStars();
      applyBlackHoleGeometry();
    }, 180);
  }

  function onReducedMotionChange(event) {
    if (state.destroyed) return;
    state.reducedMotion = event.matches;
    applyVisualConfig(false, false);
    updatePauseState(false);
  }

  function onVisibilityChange() {
    if (state.destroyed) return;
    state.documentPaused = wallpaperHost ? false : document.hidden;
    updatePauseState(false);
  }

  function onPageHide() {
    destroy();
  }

  function destroy() {
    if (state.destroyed) return false;
    state.destroyed = true;
    state.paused = true;
    clearTimeout(state.cometTimer);
    clearTimeout(state.extraCometTimer);
    clearTimeout(state.constellationTimer);
    clearTimeout(state.extraConstellationTimer);
    clearTimeout(state.resizeTimer);
    state.cometTimer = 0;
    state.extraCometTimer = 0;
    state.constellationTimer = 0;
    state.extraConstellationTimer = 0;
    state.resizeTimer = 0;
    if (state.parallaxFrame) {
      cancelAnimationFrame(state.parallaxFrame);
      state.parallaxFrame = 0;
    }
    clearActiveComets();
    clearActiveConstellations();
    removeChildren(starField);
    if (constellationLayer) removeChildren(constellationLayer);
    if (blackHoleLayer) removeChildren(blackHoleLayer);
    removeChildren(meteorLayer);
    removeChildren(heroLayer);
    state.stars = 0;
    state.starLayers = { far: 0, middle: 0, near: 0 };
    state.blackHoleParticles = 0;
    state.blackHoleSize = 0;
    state.activeMeteors = 0;
    state.activeHero = 0;
    state.lastConstellation = null;
    root.hidden = true;
    document.removeEventListener("visibilitychange", onVisibilityChange);
    window.removeEventListener("resize", onResize);
    window.removeEventListener("mousemove", onPointerMove);
    window.removeEventListener("pagehide", onPageHide);
    if (motionQuery.removeEventListener) {
      motionQuery.removeEventListener("change", onReducedMotionChange);
    } else if (motionQuery.removeListener) {
      motionQuery.removeListener(onReducedMotionChange);
    }
    return true;
  }

  document.addEventListener("visibilitychange", onVisibilityChange);
  window.addEventListener("resize", onResize, { passive: true });
  window.addEventListener("mousemove", onPointerMove, { passive: true });
  window.addEventListener("pagehide", onPageHide);
  if (motionQuery.addEventListener) {
    motionQuery.addEventListener("change", onReducedMotionChange);
  } else if (motionQuery.addListener) {
    motionQuery.addListener(onReducedMotionChange);
  }

  window.SpaceEnvironmentSystem = {
    setPaused: setPaused,
    setHostLowPower: setHostLowPower,
    onProperty: onProperty,
    previewMeteor: function () { return spawnComet(false); },
    previewHeroComet: function () { return spawnComet(true); },
    previewExtraComet: spawnExtraComet,
    previewRandomComet: spawnScheduledComet,
    previewConstellation: function () { return spawnConstellation(false); },
    previewExtraConstellation: function () { return spawnConstellation(true); },
    destroy: destroy,
    status: function () {
      return {
        enabled: config.enabled,
        destroyed: state.destroyed,
        paused: state.paused,
        reducedMotion: state.reducedMotion,
        stars: state.stars,
        starLayers: {
          far: state.starLayers.far,
          middle: state.starLayers.middle,
          near: state.starLayers.near
        },
        blackHole: {
          enabled: config.blackHole.enabled,
          motion: config.blackHole.motion && !state.reducedMotion && !isLowPower(),
          particles: state.blackHoleParticles,
          size: state.blackHoleSize,
          intensity: config.blackHole.intensity,
          positionX: config.blackHole.positionX,
          positionY: config.blackHole.positionY
        },
        activeComets: state.activeComets.size,
        activeExtraComets: state.extraComets.size,
        activeMeteors: state.activeMeteors,
        activeHero: state.activeHero,
        activeConstellations: state.activeConstellations.size,
        activeExtraConstellations: state.extraConstellations.size,
        lastConstellation: state.lastConstellation,
        lastScheduleDelay: state.lastScheduleDelay,
        lastBurstCount: state.lastBurstCount,
        lastComet: state.lastComet,
        spawned: {
          regular: state.spawned.regular,
          rare: state.spawned.rare,
          extra: state.spawned.extra,
          constellations: state.spawned.constellations,
          extraConstellations: state.spawned.extraConstellations
        },
        lowPower: isLowPower(),
        hostLowPower: state.hostLowPower,
        wallpaperHost: wallpaperHost
      };
    }
  };

  applyVisualConfig(true, true);
  // Seed two lightweight zodiac cards so the astronomy layer is visible
  // immediately after Lively starts instead of waiting for the first timer.
  spawnConstellation();
  spawnConstellation();
  updatePauseState(true);
})();
