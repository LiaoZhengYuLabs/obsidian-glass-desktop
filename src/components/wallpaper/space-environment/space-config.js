(function () {
  "use strict";

  // Central tuning surface for the UI desktop deep-space layer.
  var regularComet = {
    enabled: true,
    headSizeMin: 4,
    headSizeMax: 10,
    tailLengthMin: 60,
    tailLengthMax: 180,
    opacityMin: 0.55,
    opacityMax: 0.9,
    scaleMin: 0.6,
    scaleMax: 1.5,
    durationMin: 700,
    durationMax: 1800,
    brightnessMin: 0.82,
    brightnessMax: 1.04
  };

  var rareComet = {
    enabled: true,
    probability: 0.1,
    headSizeMin: 8,
    headSizeMax: 15,
    tailLengthMin: 150,
    tailLengthMax: 260,
    opacityMin: 0.7,
    opacityMax: 0.88,
    scaleMin: 0.8,
    scaleMax: 1.5,
    durationMin: 1200,
    durationMax: 2500,
    brightnessMin: 0.94,
    brightnessMax: 1.04
  };

  var comets = {
    enabled: true,
    firstSpawnMin: 900,
    firstSpawnMax: 2200,
    spawnMin: 1800,
    spawnMax: 4200,
    maxActive: 7,
    burstChance: 0.72,
    burstMin: 2,
    burstMax: 3,
    frequencyScale: 1,
    sizeScale: 1,
    longGapChance: 0.04,
    longGapMultiplierMin: 1.2,
    longGapMultiplierMax: 1.45,
    regular: regularComet,
    rare: rareComet
  };

  // Additive cinematic accents. The original comet settings above stay intact.
  var extraComets = {
    enabled: true,
    spawnMin: 7200,
    spawnMax: 10800,
    maxActive: 2,
    burstChance: 0.12,
    burstMin: 1,
    burstMax: 1,
    rareProbability: 0.08
  };

  window.SpaceEnvironmentConfig = {
    enabled: true,
    background: {
      enabled: true,
      opacity: 0.22,
      // CSS resolves custom-property URLs relative to this module stylesheet.
      image: "assets/comet-space.jpg"
    },
    stars: {
      enabled: true,
      count: 188,
      minCount: 120,
      maxCount: 260,
      brightness: 0.94,
      twinkle: true,
      twinkleStrength: 0.29,
      durationMin: 1700,
      durationMax: 5400,
      delayMax: 5400,
      quietChance: 0.1,
      drift: {
        enabled: true,
        chance: 0.38,
        distanceMin: 4,
        distanceMax: 18,
        durationMin: 12000,
        durationMax: 34000
      },
      layers: {
        far: {
          ratio: 0.68,
          sizeMin: 1,
          sizeMax: 2,
          opacityMin: 0.12,
          opacityMax: 0.38,
          glowMin: 0.5,
          glowMax: 1.4
        },
        middle: {
          ratio: 0.25,
          sizeMin: 2,
          sizeMax: 3,
          opacityMin: 0.22,
          opacityMax: 0.58,
          glowMin: 1.4,
          glowMax: 3.2
        },
        near: {
          ratio: 0.07,
          sizeMin: 3,
          sizeMax: 5,
          opacityMin: 0.42,
          opacityMax: 0.82,
          glowMin: 3.5,
          glowMax: 8
        }
      }
    },
    constellations: {
      enabled: true,
      spawnInterval: 6000,
      maxActive: 5,
      fadeIn: 1500,
      lifetimes: [18000, 22000, 26000, 30000, 34000]
    },
    // One additive constellation slot; the original five-slot rotation stays intact.
    extraConstellations: {
      enabled: true,
      spawnInterval: 11000,
      maxActive: 1
    },
    blackHole: {
      enabled: true,
      motion: true,
      positionX: 76,
      positionY: 29,
      baseSize: 360,
      sizeScale: 1,
      intensity: 0.58,
      tilt: -8,
      diskCompression: 0.24,
      spinDuration: 32000,
      counterSpinDuration: 21000,
      pulseDuration: 8200,
      particleCount: 10
    },
    comets: comets,
    extraComets: extraComets,

    // Backward-compatible aliases for existing Lively controls and any local
    // scripts that read the previous configuration names.
    meteors: regularComet,
    heroComet: rareComet,
    parallax: {
      enabled: true,
      strength: 2.4
    },
    performance: {
      lowPower: false,
      lowPowerStarFactor: 0.56,
      mobileStarFactor: 0.6,
      tabletStarFactor: 0.8
    }
  };
})();
