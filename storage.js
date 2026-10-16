/* Shared namespace, constants, date helpers and safe localStorage access */
(function () {
  "use strict";

  const App = (window.App = window.App || {});

  App.DAYS = [
    { key: "today", label: "Today", title: "Today's Tasks" },
    { key: "monday", label: "Monday", title: "Monday" },
    { key: "tuesday", label: "Tuesday", title: "Tuesday" },
    { key: "wednesday", label: "Wednesday", title: "Wednesday" },
    { key: "thursday", label: "Thursday", title: "Thursday" },
    { key: "friday", label: "Friday", title: "Friday" },
    { key: "saturday", label: "Saturday", title: "Saturday" },
    { key: "sunday", label: "Sunday", title: "Sunday" },
  ];

  // Day lists keep their old localStorage keys ("monday", ...) so existing data still loads.
  App.KEYS = {
    active: "taskTracker:activeTab",
    settings: "taskTracker:settings",
    weekReset: "taskTracker:weekReset",
  };

  App.makeId = function () {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  };

  /* ---------- Dates (all local time, ISO format YYYY-MM-DD) ---------- */
  function pad(n) {
    return String(n).padStart(2, "0");
  }

  function toISO(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }

  function parse(iso) {
    const parts = iso.split("-").map(Number);
    return new Date(parts[0], parts[1] - 1, parts[2]);
  }

  App.dates = {
    pad: pad,
    toISO: toISO,
    parse: parse,
    today: function () {
      return toISO(new Date());
    },
    isValid: function (iso) {
      return typeof iso === "string" && /^\d{4}-\d{2}-\d{2}$/.test(iso) && toISO(parse(iso)) === iso;
    },
    // Monday of the week that contains `date`
    weekStart: function (date) {
      const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
      d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
      return toISO(d);
    },
    format: function (iso) {
      return parse(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });
    },
    formatLong: function (iso) {
      return parse(iso).toLocaleDateString(undefined, {
        weekday: "short", month: "short", day: "numeric", year: "numeric",
      });
    },
  };

  /* ---------- Storage (never throws) ---------- */
  App.storage = {
    get: function (key) {
      try { return localStorage.getItem(key); } catch (e) { return null; }
    },
    set: function (key, value) {
      try { localStorage.setItem(key, value); return true; } catch (e) { return false; }
    },
    getJSON: function (key, fallback) {
      const raw = this.get(key);
      if (raw == null) return fallback;
      try { return JSON.parse(raw); } catch (e) { return fallback; }
    },
    setJSON: function (key, value) {
      return this.set(key, JSON.stringify(value));
    },
  };
})();
