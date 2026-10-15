// Bridge between Bongo Waifu (Swift) and a Live2D model rendered by pixi-live2d-display.
// Swift calls window.bongo.load / update / tap; this posts {type: ...} messages back.
(() => {
  'use strict';

  const post = (type, data = {}) => {
    try { window.webkit.messageHandlers.bongo.postMessage(Object.assign({ type }, data)); } catch (_) {}
  };
  window.addEventListener('error', (e) => post('error', { message: `${e.message} (${e.filename}:${e.lineno})` }));
  window.addEventListener('unhandledrejection', (e) => post('error', { message: String((e.reason && e.reason.message) || e.reason) }));

  if (typeof window.Live2DCubismCore === 'undefined') {
    window.bongo = { load() {}, update() {}, tap() {}, step() {}, stepIfHidden() {}, snapshot() { return null; } };
    post('error', { code: 'core-missing', message: 'Live2D Cubism Core is not installed.' });
    return;
  }

  const { Live2DModel, MotionPriority } = PIXI.live2d;
  const app = new PIXI.Application({
    view: document.getElementById('stage'),
    backgroundAlpha: 0,
    antialias: true,
    autoDensity: true,
    resolution: window.devicePixelRatio || 1,
    resizeTo: window,
  });

  let model = null;
  let config = {};
  let state = null;
  let mood = 'neutral';
  let lipIds = ['ParamMouthOpenY'];
  let eyeIds = ['ParamEyeLOpen', 'ParamEyeROpen'];

  // Fallback when a pack doesn't map moods to expressions: match expression file names.
  const moodKeywords = {
    happy: ['happy', 'smile', 'joy', 'fun'],
    excited: ['excite', 'star', 'sparkle', 'happy', 'smile'],
    surprised: ['surprise', 'shock', 'wow'],
    annoyed: ['angry', 'anger', 'annoy', 'mad', 'pout'],
    sleepy: ['sleep', 'tired'],
    smug: ['smug', 'doya', 'grin'],
    blush: ['blush', 'shy', 'embarrass', 'love', 'heart'],
  };

  // Artists' canvases often have lots of empty space, so frame the visible artwork instead:
  // render the model small once and take the bounding box of its opaque pixels (in unscaled model px).
  let visible = null;
  function measureVisible() {
    model.anchor.set(0, 0);
    model.position.set(0, 0);
    model.scale.set(1);
    const full = model.getLocalBounds();
    const k = 256 / Math.max(full.width, full.height);
    model.scale.set(k);
    const width = Math.ceil(full.width * k), height = Math.ceil(full.height * k);
    const target = PIXI.RenderTexture.create({ width, height });
    app.renderer.render(model, { renderTexture: target });
    const px = app.renderer.extract.pixels(target);
    target.destroy(true);
    // Count opaque pixels per row and column, then ignore sparse ones (floating particles, thin props).
    const rows = new Array(height).fill(0), cols = new Array(width).fill(0);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (px[(y * width + x) * 4 + 3] > 8) { rows[y]++; cols[x]++; }
      }
    }
    const dense = (counts) => {
      const limit = Math.max(...counts) * 0.06;
      const first = counts.findIndex((c) => c > limit);
      let last = counts.length - 1;
      while (last > first && counts[last] <= limit) last--;
      return [first, last];
    };
    const [minX, maxX] = dense(cols), [minY, maxY] = dense(rows);
    if (minX < 0 || minY < 0) return { x: 0, y: 0, width: full.width, height: full.height };
    return { x: minX / k, y: minY / k, width: (maxX - minX + 1) / k, height: (maxY - minY + 1) / k };
  }

  // Show the head and torso above the desk. By default the artwork's width fills most of the view, which
  // frames full-body and half-body models alike; `zoom` (artwork height / view height) overrides it.
  let fitted = '';
  let updates = 0;
  function fit() {
    if (!model) return;
    if (!visible) {
      if (++updates < 3) return; // let the model update once so its meshes are posed
      visible = measureVisible();
      fitted = '';
    }
    const w = app.renderer.screen.width;
    const h = app.renderer.screen.height;
    const key = `${w}x${h}`;
    if (key === fitted) return;
    fitted = key;
    const k = config.zoom ? (h * config.zoom) / visible.height : (w * 0.9) / visible.width;
    model.anchor.set(0, 0);
    model.scale.set(k);
    model.position.set(w / 2 - (visible.x + visible.width / 2) * k + (config.offsetX || 0) * w,
                       h * 0.04 - visible.y * k + (config.offsetY || 0) * h);
  }
  app.ticker.add(() => fit());
  // Debug: raw requestAnimationFrame rate and visibility, reported from a timer.
  let raf = 0;
  const countRaf = () => { raf++; requestAnimationFrame(countRaf); };
  requestAnimationFrame(countRaf);
  setInterval(() => {
    if (config.debug) post('log', { message: `rAF ${raf / 2}/s visibility=${document.visibilityState} ticker.started=${app.ticker.started}` });
    raf = 0;
  }, 2000);
  let frames = 0, since = performance.now();
  app.ticker.add(() => {
    if (!config.debug) return;
    frames++;
    const now = performance.now();
    if (now - since > 2000) { post('log', { message: `rendering at ${(frames * 1000 / (now - since)).toFixed(0)} fps` }); frames = 0; since = now; }
  });

  const settings = () => model.internalModel.settings;
  const expressionNames = () => (settings().expressions || []).map((e) => e.Name || e.name);
  const motionGroups = () => Object.keys(settings().motions || {});

  function setMood(next) {
    mood = next;
    if (!model) return;
    const manager = model.internalModel.motionManager.expressionManager;
    if (!manager) return;
    const keys = moodKeywords[next] || [];
    const name = next === 'neutral' ? null
      : (config.expressions && config.expressions[next]) || expressionNames().find((n) => keys.some((k) => n.toLowerCase().includes(k)));
    if (name) model.expression(name); else manager.resetExpression();
  }

  // Apply the Swift rig inside updateFocus: after motions and the model's own blink, before physics,
  // so hair physics reacts to the head movement we add.
  function patch(m) {
    const internal = m.internalModel;
    const core = internal.coreModel;
    const original = internal.updateFocus.bind(internal);
    internal.updateFocus = function () {
      original();
      if (!state) return;
      const get = (id) => core.getParameterValueById(id);
      const set = (id, v) => core.setParameterValueById(id, v);
      const add = (id, v) => core.addParameterValueById(id, v);
      add('ParamAngleX', state.angleX * 30);
      add('ParamAngleY', -state.angleY * 30 - state.tapDip * 4);
      add('ParamAngleZ', state.angleZ * 57.3);
      add('ParamBodyAngleX', state.angleX * 10);
      add('ParamBodyAngleZ', -state.angleX * 3);
      add('ParamEyeBallX', state.eyeBallX);
      add('ParamEyeBallY', -state.eyeBallY);
      add('ParamBrowLY', -state.browY * 0.1);
      add('ParamBrowRY', -state.browY * 0.1);
      add('ParamBrowLAngle', -state.browAngle);
      add('ParamBrowRAngle', -state.browAngle);
      for (const id of eyeIds) set(id, get(id) * state.eyeOpen);
      set('ParamEyeLSmile', Math.max(get('ParamEyeLSmile'), state.eyeSmile));
      set('ParamEyeRSmile', Math.max(get('ParamEyeRSmile'), state.eyeSmile));
      set('ParamCheek', Math.max(get('ParamCheek'), state.blush));
      for (const id of lipIds) set(id, Math.max(get(id), state.mouthOpen));
      add('ParamMouthForm', (state.mouthForm - 0.3) * 0.8); // relative to the rig's neutral smile
    };
  }

  async function load(url, cfg) {
    config = cfg || {};
    fitted = '';
    visible = null;
    updates = 0;
    if (model) {
      app.stage.removeChild(model);
      model.destroy();
      model = null;
    }
    const m = await Live2DModel.from(url, { autoInteract: false });
    model = m;
    app.stage.addChild(m);
    lipIds = (settings().getLipSyncParameters && settings().getLipSyncParameters()) || lipIds;
    eyeIds = (settings().getEyeBlinkParameters && settings().getEyeBlinkParameters()) || eyeIds;
    patch(m);
    fit();
    setMood(mood);
    post('loaded', { expressions: expressionNames(), motions: motionGroups() });
  }

  function tap() {
    if (!model) return;
    const groups = motionGroups();
    const group = config.tapMotion || groups.find((n) => /tap/i.test(n)) || groups.find((n) => !/idle/i.test(n));
    if (group) model.motion(group, undefined, MotionPriority.FORCE);
  }

  window.bongo = {
    load: (url, cfg) => load(url, cfg).catch((e) => post('error', { message: String((e && e.message) || e) })),
    update: (s) => {
      state = s;
      if (s.mood !== mood) setMood(s.mood);
    },
    tap,
    // Advance one frame by hand, for hosts where requestAnimationFrame doesn't run (off-screen windows).
    step: () => {
      const now = performance.now();
      PIXI.Ticker.shared.update(now); // drives the model's own update
      app.ticker.update(now); // renders
    },
    // WebKit pauses requestAnimationFrame when it thinks the page is hidden; the host calls this while
    // its window is actually visible so the model keeps moving regardless.
    stepIfHidden: () => { if (document.visibilityState === 'hidden') window.bongo.step(); },
    snapshot: () => {
      app.renderer.render(app.stage);
      return app.view.toDataURL('image/png');
    },
  };
  post('ready');
})();
