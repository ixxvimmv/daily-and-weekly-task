/* Calendar widget: month view, clock, dots for due dates, click-to-filter */
(function () {
  "use strict";

  const App = window.App;

  const MONTHS = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];

  const $ = function (id) { return document.getElementById(id); };
  const els = {
    title: $("calendar-title"),
    body: $("calendar-body"),
    time: $("time"),
    prev: $("prev-month"),
    next: $("next-month"),
    toggle: $("calendar-toggle"),
    content: $("calendar-content"),
  };

  const view = new Date();
  view.setDate(1); // always the 1st, so changing months never skips one

  let selected = null;
  let lastToday = App.dates.today();
  let handlers = {
    onSelect: function () {},
    onNewDay: function () {},
    getDueInfo: function () { return new Map(); },
  };

  function render() {
    const month = view.getMonth();
    const year = view.getFullYear();
    const todayISO = App.dates.today();
    const info = handlers.getDueInfo();

    els.title.textContent = MONTHS[month] + " " + year;

    const startOffset = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const totalCells = Math.ceil((startOffset + daysInMonth) / 7) * 7;

    els.body.textContent = "";
    let row = null;

    for (let i = 0; i < totalCells; i++) {
      if (i % 7 === 0) {
        row = document.createElement("tr");
        els.body.appendChild(row);
      }
      const cell = document.createElement("td");
      const day = i - startOffset + 1;

      if (day >= 1 && day <= daysInMonth) {
        const iso = year + "-" + App.dates.pad(month + 1) + "-" + App.dates.pad(day);
        const entry = info.get(iso);

        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "cal-day";
        btn.textContent = day;
        btn.dataset.date = iso;
        btn.setAttribute("aria-pressed", String(iso === selected));
        btn.setAttribute(
          "aria-label",
          App.dates.formatLong(iso) + (entry ? ", " + entry.open + " open of " + entry.total + " tasks due" : "")
        );

        if (iso === todayISO) btn.classList.add("today");
        if (iso === selected) btn.classList.add("selected");
        if (entry) {
          btn.classList.add("has-tasks");
          if (entry.open === 0) btn.classList.add("all-done");
        }
        cell.appendChild(btn);
      }
      row.appendChild(cell);
    }
  }

  function setCollapsed(collapsed) {
    els.content.hidden = collapsed;
    els.toggle.setAttribute("aria-expanded", String(!collapsed));
    els.toggle.setAttribute("aria-label", collapsed ? "Expand calendar" : "Collapse calendar");
    els.toggle.textContent = collapsed ? "+" : "\u2212";
  }

  function tick() {
    els.time.textContent = new Date().toLocaleTimeString();
    const today = App.dates.today();
    if (today !== lastToday) {
      lastToday = today;
      render();
      handlers.onNewDay();
    }
  }

  function init(options) {
    handlers = Object.assign(handlers, options);

    setCollapsed(App.settings.get().calendarCollapsed);

    els.prev.addEventListener("click", function () {
      view.setMonth(view.getMonth() - 1);
      render();
    });

    els.next.addEventListener("click", function () {
      view.setMonth(view.getMonth() + 1);
      render();
    });

    els.title.addEventListener("click", function () {
      const now = new Date();
      view.setFullYear(now.getFullYear(), now.getMonth(), 1);
      render();
    });

    els.toggle.addEventListener("click", function () {
      const collapse = !els.content.hidden;
      setCollapsed(collapse);
      App.settings.set({ calendarCollapsed: collapse });
    });

    els.body.addEventListener("click", function (e) {
      const btn = e.target.closest("button.cal-day");
      if (!btn) return;
      const iso = btn.dataset.date;
      handlers.onSelect(iso === selected ? null : iso);
    });

    render();
    tick();
    setInterval(tick, 1000);
  }

  App.calendar = {
    init: init,
    render: render,
    setCollapsed: setCollapsed,
    setSelected: function (iso) {
      selected = iso;
      render();
    },
  };
})();
