/* Theme (accent colour + light/dark/auto) and other saved preferences */
(function () {
  "use strict";

  const App = window.App;

  const ACCENTS = ["pink", "blue", "green", "purple"];
  const MODES = ["system", "light", "dark"];
  const DEFAULTS = { accent: "pink", mode: "system", calendarCollapsed: false };

  const settings = Object.assign({}, DEFAULTS);
  validate(settings, App.storage.getJSON(App.KEYS.settings, {}));

  const media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  // Copy only valid values from `patch` into `target`
  function validate(target, patch) {
    if (!patch || typeof patch !== "object") return target;
    if (ACCENTS.indexOf(patch.accent) !== -1) target.accent = patch.accent;
    if (MODES.indexOf(patch.mode) !== -1) target.mode = patch.mode;
    if (typeof patch.calendarCollapsed === "boolean") target.calendarCollapsed = patch.calendarCollapsed;
    return target;
  }

  function resolvedMode() {
    if (settings.mode === "system") return media && media.matches ? "dark" : "light";
    return settings.mode;
  }

  function apply() {
    const root = document.documentElement;
    root.dataset.accent = settings.accent;
    root.dataset.mode = resolvedMode();

    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) {
      const bg = getComputedStyle(root).getPropertyValue("--bg").trim();
      if (bg) meta.setAttribute("content", bg);
    }
  }

  App.settings = {
    ACCENTS: ACCENTS,
    MODES: MODES,
    get: function () {
      return settings;
    },
    set: function (patch) {
      validate(settings, patch);
      App.storage.setJSON(App.KEYS.settings, settings);
      apply();
    },
    apply: apply,
  };

  if (media) {
    const onChange = function () {
      if (settings.mode === "system") apply();
    };
    if (media.addEventListener) media.addEventListener("change", onChange);
    else if (media.addListener) media.addListener(onChange);
  }

  apply();
})();
