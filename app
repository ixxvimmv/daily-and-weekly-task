/* UI: tabs, task list, editing, drag & drop, undo, search, export/import, themes */
(function () {
  "use strict";

  const App = window.App;
  const $ = function (id) { return document.getElementById(id); };

  const els = {
    tabs: $("tabs"),
    title: $("panel-title"),
    counter: $("panel-counter"),
    progressBar: $("progress-bar"),
    filterNote: $("filter-note"),
    filterText: $("filter-text"),
    clearFilter: $("clear-filter"),
    search: $("search-input"),
    statusFilter: $("status-filter"),
    sort: $("sort-select"),
    celebrate: $("celebrate"),
    list: $("task-list"),
    empty: $("empty-msg"),
    form: $("task-form"),
    input: $("task-input"),
    due: $("due-input"),
    priority: $("priority-input"),
    recurring: $("recurring-input"),
    clearDone: $("clear-done"),
    clearAll: $("clear-all"),
    accent: $("accent-select"),
    mode: $("mode-btn"),
    exportBtn: $("export-btn"),
    importBtn: $("import-btn"),
    importFile: $("import-file"),
    toast: $("toast"),
    toastText: $("toast-text"),
    toastUndo: $("toast-undo"),
    status: $("status"),
  };

  const PRIORITY_LABELS = { high: "High", medium: "Medium", low: "Low" };
  const MODE_LABELS = { system: "🖥️ Auto", light: "☀️ Light", dark: "🌙 Dark" };

  /* ---------- UI state ---------- */
  const ui = {
    activeDay: loadActiveDay(),
    filterDate: null,
    search: "",
    status: "all",
    sort: "manual",
    editing: null,      // { day, id }
    justAdded: null,
    focusAfter: null,   // { day, id, action }
    focusEdit: false,
    dragged: null,      // { day, id }
    undo: null,
    toastTimer: null,
  };

  function loadActiveDay() {
    const saved = App.storage.get(App.KEYS.active);
    return App.DAYS.some(function (d) { return d.key === saved; }) ? saved : "today";
  }

  function dayInfo(key) {
    return App.DAYS.find(function (d) { return d.key === key; });
  }

  function weekdayKey() {
    return ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][new Date().getDay()];
  }

  function isAggregated() {
    return Boolean(ui.filterDate || ui.search);
  }

  /* ---------- Messages ---------- */
  function announce(message) {
    els.status.textContent = "";
    setTimeout(function () { els.status.textContent = message; }, 40);
  }

  function hideToast() {
    els.toast.hidden = true;
    ui.undo = null;
  }

  function notify(message, undoFn) {
    ui.undo = undoFn || null;
    els.toastText.textContent = message;
    els.toastUndo.hidden = !undoFn;
    els.toast.hidden = false;
    clearTimeout(ui.toastTimer);
    ui.toastTimer = setTimeout(hideToast, undoFn ? 8000 : 4000);
    announce(message);
  }

  function runUndo() {
    if (!ui.undo) return;
    const fn = ui.undo;
    hideToast();
    fn();
    renderAll();
    announce("Restored");
  }

  /* ---------- Scope / items ---------- */
  // Everything the current view is about, before the status filter and sorting
  function getScope() {
    let items = isAggregated()
      ? App.tasks.allItems()
      : App.tasks.list(ui.activeDay).map(function (task) { return { day: ui.activeDay, task: task }; });

    if (ui.filterDate) {
      items = items.filter(function (i) { return i.task.due === ui.filterDate; });
    }
    if (ui.search) {
      const q = ui.search.toLowerCase();
      items = items.filter(function (i) { return i.task.text.toLowerCase().indexOf(q) !== -1; });
    }
    return items;
  }

  function getItems(scope) {
    let items = scope || getScope();
    if (ui.status === "active") items = items.filter(function (i) { return !i.task.done; });
    else if (ui.status === "done") items = items.filter(function (i) { return i.task.done; });
    return App.tasks.sortItems(items, ui.sort);
  }

  function canReorder() {
    return ui.sort === "manual" && ui.status === "all" && !isAggregated();
  }

  /* ---------- Rendering ---------- */
  function renderAll() {
    renderTabs();
    renderPanel();
    App.calendar.render();
  }

  function renderTabs() {
    const todayKey = weekdayKey();
    els.tabs.textContent = "";

    App.DAYS.forEach(function (d) {
      const open = App.tasks.list(d.key).filter(function (t) { return !t.done; }).length;
      const active = d.key === ui.activeDay;

      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "tab";
      btn.id = "tab-" + d.key;
      btn.dataset.day = d.key;
      btn.setAttribute("role", "tab");
      btn.setAttribute("aria-controls", "panel");
      btn.setAttribute("aria-selected", String(active));
      btn.setAttribute("aria-label", d.label + (open ? ", " + open + " open" : ""));
      btn.tabIndex = active ? 0 : -1;
      btn.classList.toggle("active", active);
      if (d.key === todayKey) btn.classList.add("is-today");

      btn.appendChild(document.createTextNode(d.label));
      if (open) {
        const badge = document.createElement("span");
        badge.className = "badge";
        badge.setAttribute("aria-hidden", "true");
        badge.textContent = open;
        btn.appendChild(badge);
      }
      els.tabs.appendChild(btn);
    });
  }

  function renderPanel() {
    const aggregated = isAggregated();
    const scope = getScope();
    const items = getItems(scope);
    const day = dayInfo(ui.activeDay);

    // Title
    if (ui.filterDate) els.title.textContent = "Due " + App.dates.formatLong(ui.filterDate);
    else if (ui.search) els.title.textContent = "Search results";
    else els.title.textContent = day.title;

    // Filter note
    els.filterNote.hidden = !aggregated;
    if (ui.filterDate) {
      els.filterText.textContent = "Showing tasks from all days due on " + App.dates.formatLong(ui.filterDate) + ".";
    } else if (ui.search) {
      els.filterText.textContent = "Showing tasks from all days matching \u201C" + ui.search + "\u201D.";
    }

    // Counter + progress
    const doneCount = scope.filter(function (i) { return i.task.done; }).length;
    els.counter.textContent = doneCount + " / " + scope.length + " done";
    els.progressBar.style.width = scope.length ? (doneCount / scope.length) * 100 + "%" : "0%";

    // List
    els.list.textContent = "";
    items.forEach(function (item) { els.list.appendChild(buildItem(item, aggregated)); });

    // Empty message
    els.empty.hidden = items.length > 0;
    if (!items.length) {
      if (aggregated) els.empty.textContent = "Nothing matches.";
      else if (!scope.length) els.empty.textContent = "No tasks yet. Add one below!";
      else els.empty.textContent = "No tasks match this filter.";
    }

    // Celebration banner (only when a whole day list is completed)
    els.celebrate.hidden = !(!aggregated && scope.length > 0 && doneCount === scope.length);

    // Form
    els.input.placeholder = "Add a task to " + day.label + "...";
    els.clearDone.hidden = aggregated;
    els.clearAll.hidden = aggregated;

    applyFocus();
  }

  function applyFocus() {
    if (ui.focusEdit) {
      ui.focusEdit = false;
      const field = els.list.querySelector(".edit-text");
      if (field) {
        field.focus();
        field.select();
      }
    }
    if (ui.focusAfter) {
      const target = ui.focusAfter;
      ui.focusAfter = null;
      const li = Array.prototype.find.call(els.list.children, function (el) {
        return el.dataset.id === target.id && el.dataset.day === target.day;
      });
      const btn = li && li.querySelector('[data-action="' + target.action + '"]');
      if (btn) btn.focus();
    }
  }

  function makeChip(text, className) {
    const chip = document.createElement("span");
    chip.className = "chip" + (className ? " " + className : "");
    chip.textContent = text;
    return chip;
  }

  function makeButton(label, className, action, ariaLabel) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn btn-small " + className;
    btn.dataset.action = action;
    btn.textContent = label;
    btn.setAttribute("aria-label", ariaLabel);
    return btn;
  }

  function buildItem(item, aggregated) {
    const day = item.day;
    const task = item.task;

    if (ui.editing && ui.editing.day === day && ui.editing.id === task.id) {
      return buildEditItem(item);
    }

    const li = document.createElement("li");
    li.className = "task";
    li.dataset.id = task.id;
    li.dataset.day = day;
    li.dataset.priority = task.priority;
    li.draggable = true;
    li.classList.toggle("done", task.done);
    if (ui.justAdded === task.id) li.classList.add("enter");

    const main = document.createElement("div");
    main.className = "task-main";

    const text = document.createElement("span");
    text.className = "task-text";
    text.textContent = task.text; // textContent keeps user text from being treated as HTML
    main.appendChild(text);

    const meta = document.createElement("div");
    meta.className = "task-meta";

    if (task.priority !== "none") {
      meta.appendChild(makeChip(PRIORITY_LABELS[task.priority], "chip-" + task.priority));
    }
    if (task.due) {
      const today = App.dates.today();
      if (!task.done && task.due < today) {
        meta.appendChild(makeChip("Overdue · " + App.dates.format(task.due), "chip-overdue"));
      } else if (!task.done && task.due === today) {
        meta.appendChild(makeChip("Due today", "chip-today"));
      } else {
        meta.appendChild(makeChip("Due " + App.dates.format(task.due)));
      }
    }
    if (task.recurring) meta.appendChild(makeChip("↻ Weekly"));
    if (aggregated) meta.appendChild(makeChip(dayInfo(day).label));
    if (meta.children.length) main.appendChild(meta);

    const actions = document.createElement("div");
    actions.className = "task-actions";
    actions.appendChild(
      makeButton(
        task.done ? "Undo" : "Done",
        "btn-success",
        "toggle",
        (task.done ? "Mark as not done: " : "Mark as done: ") + task.text
      )
    );
    actions.appendChild(makeButton("Edit", "btn-muted", "edit", "Edit: " + task.text));
    actions.appendChild(makeButton("Remove", "btn-danger", "remove", "Remove: " + task.text));

    li.append(main, actions);
    return li;
  }

  function buildEditItem(item) {
    const day = item.day;
    const task = item.task;

    const li = document.createElement("li");
    li.className = "task editing";
    li.dataset.id = task.id;
    li.dataset.day = day;
    li.dataset.priority = task.priority;

    const dayOptions = App.DAYS.map(function (d) {
      return '<option value="' + d.key + '">' + d.label + "</option>";
    }).join("");

    const form = document.createElement("form");
    form.className = "edit-form";
    form.innerHTML =
      '<input type="text" class="edit-text" maxlength="200" aria-label="Task text">' +
      '<div class="form-row">' +
      '<label>Due <input type="date" class="edit-due"></label>' +
      '<label>Priority <select class="edit-priority">' +
      '<option value="none">None</option><option value="low">Low</option>' +
      '<option value="medium">Medium</option><option value="high">High</option></select></label>' +
      '<label>Day <select class="edit-day">' + dayOptions + "</select></label>" +
      '<label class="check"><input type="checkbox" class="edit-recurring"> Repeat weekly</label>' +
      "</div>" +
      '<div class="form-buttons">' +
      '<button type="submit" class="btn">Save</button>' +
      '<button type="button" class="btn btn-muted" data-action="cancel-edit">Cancel</button>' +
      "</div>";

    form.querySelector(".edit-text").value = task.text;
    form.querySelector(".edit-due").value = task.due;
    form.querySelector(".edit-priority").value = task.priority;
    form.querySelector(".edit-day").value = day;
    form.querySelector(".edit-recurring").checked = task.recurring;

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      const text = form.querySelector(".edit-text").value.trim();
      if (!text) {
        form.querySelector(".edit-text").focus();
        return;
      }
      App.tasks.update(day, task.id, {
        text: text,
        due: form.querySelector(".edit-due").value,
        priority: form.querySelector(".edit-priority").value,
        recurring: form.querySelector(".edit-recurring").checked,
      });
      const newDay = form.querySelector(".edit-day").value;
      if (newDay !== day) {
        App.tasks.move(day, task.id, newDay);
        notify("Task moved to " + dayInfo(newDay).label + ".");
      } else {
        announce("Task updated");
      }
      ui.editing = null;
      ui.focusAfter = { day: newDay, id: task.id, action: "edit" };
      renderAll();
    });

    form.addEventListener("keydown", function (e) {
      if (e.key === "Escape") cancelEdit();
    });

    li.appendChild(form);
    return li;
  }

  function startEdit(day, id) {
    ui.editing = { day: day, id: id };
    ui.focusEdit = true;
    renderAll();
  }

  function cancelEdit() {
    if (!ui.editing) return;
    ui.focusAfter = { day: ui.editing.day, id: ui.editing.id, action: "edit" };
    ui.editing = null;
    renderAll();
  }

  /* ---------- Tabs ---------- */
  function showTab(day, focus) {
    ui.activeDay = day;
    ui.editing = null;
    App.storage.set(App.KEYS.active, day);
    clearFilters(true);
    renderAll();
    if (focus) $("tab-" + day).focus();
  }

  els.tabs.addEventListener("click", function (e) {
    const tab = e.target.closest(".tab");
    if (tab) showTab(tab.dataset.day);
  });

  els.tabs.addEventListener("keydown", function (e) {
    const tab = e.target.closest(".tab");
    if (!tab) return;
    const keys = App.DAYS.map(function (d) { return d.key; });
    let index = keys.indexOf(tab.dataset.day);
    if (e.key === "ArrowRight") index = (index + 1) % keys.length;
    else if (e.key === "ArrowLeft") index = (index - 1 + keys.length) % keys.length;
    else if (e.key === "Home") index = 0;
    else if (e.key === "End") index = keys.length - 1;
    else return;
    e.preventDefault();
    showTab(keys[index], true);
  });

  /* ---------- Filters (search, status, sort, calendar date) ---------- */
  function clearFilters(skipRender) {
    ui.filterDate = null;
    ui.search = "";
    els.search.value = "";
    els.due.value = "";
    App.calendar.setSelected(null);
    if (!skipRender) renderPanel();
  }

  els.clearFilter.addEventListener("click", function () { clearFilters(); });

  els.search.addEventListener("input", function () {
    ui.search = els.search.value.trim();
    renderPanel();
  });

  els.search.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && els.search.value) {
      els.search.value = "";
      ui.search = "";
      renderPanel();
    }
  });

  els.statusFilter.addEventListener("change", function () {
    ui.status = els.statusFilter.value;
    renderPanel();
  });

  els.sort.addEventListener("change", function () {
    ui.sort = els.sort.value;
    renderPanel();
  });

  function onCalendarSelect(iso) {
    ui.filterDate = iso;
    ui.editing = null;
    els.due.value = iso || "";
    App.calendar.setSelected(iso);
    renderPanel();
  }

  /* ---------- Adding tasks ---------- */
  els.form.addEventListener("submit", function (e) {
    e.preventDefault();
    const text = els.input.value.trim();
    if (!text) {
      els.input.focus();
      return;
    }

    const task = App.tasks.add(ui.activeDay, {
      text: text,
      due: els.due.value,
      priority: els.priority.value,
      recurring: els.recurring.checked,
    });
    if (!task) return;

    els.input.value = "";
    els.priority.value = "none";
    els.recurring.checked = false;
    els.due.value = ui.filterDate || "";

    ui.justAdded = task.id;
    renderAll();
    ui.justAdded = null;

    const visible = getItems().some(function (i) { return i.task.id === task.id; });
    if (visible) announce("Task added");
    else notify("Added to " + dayInfo(ui.activeDay).label + " (hidden by the current filters).");

    els.input.focus();
  });

  els.clearDone.addEventListener("click", function () {
    const day = ui.activeDay;
    const removed = App.tasks.clearDone(day);
    if (!removed.length) {
      notify("No completed tasks to clear.");
      return;
    }
    notify(removed.length + (removed.length === 1 ? " task" : " tasks") + " cleared.", function () {
      App.tasks.restore(day, removed);
    });
    renderAll();
  });

  els.clearAll.addEventListener("click", function () {
    const day = ui.activeDay;
    const removed = App.tasks.clearAll(day);
    if (!removed.length) return;
    notify("Cleared all " + removed.length + (removed.length === 1 ? " task." : " tasks."), function () {
      App.tasks.restore(day, removed);
    });
    renderAll();
  });

  /* ---------- Task list actions ---------- */
  els.list.addEventListener("click", function (e) {
    const btn = e.target.closest("button[data-action]");
    if (!btn) return;
    const li = btn.closest("li");
    const day = li.dataset.day;
    const id = li.dataset.id;
    const action = btn.dataset.action;

    if (action === "toggle") {
      const task = App.tasks.toggle(day, id);
      if (task) announce(task.done ? "Marked as done" : "Marked as not done");
      ui.focusAfter = { day: day, id: id, action: "toggle" };
      renderAll();
    } else if (action === "edit") {
      startEdit(day, id);
    } else if (action === "cancel-edit") {
      cancelEdit();
    } else if (action === "remove") {
      li.classList.add("leaving");
      setTimeout(function () {
        const removed = App.tasks.remove(day, id);
        if (removed.length) {
          notify("Task removed.", function () { App.tasks.restore(day, removed); });
        }
        renderAll();
      }, 160);
    }
  });

  els.list.addEventListener("dblclick", function (e) {
    const li = e.target.closest("li.task");
    if (!li || li.classList.contains("editing") || e.target.closest("button")) return;
    startEdit(li.dataset.day, li.dataset.id);
  });

  els.toastUndo.addEventListener("click", runUndo);

  document.addEventListener("keydown", function (e) {
    const tag = document.activeElement ? document.activeElement.tagName : "";
    const typing = tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT";
    if ((e.ctrlKey || e.metaKey) && !e.shiftKey && e.key.toLowerCase() === "z" && ui.undo && !typing) {
      e.preventDefault();
      runUndo();
    }
  });

  /* ---------- Drag & drop (reorder in a list, or drop on a tab to move) ---------- */
  function clearDropMarks() {
    els.list.querySelectorAll(".drop-before, .drop-after").forEach(function (el) {
      el.classList.remove("drop-before", "drop-after");
    });
    els.tabs.querySelectorAll(".drop-target").forEach(function (el) {
      el.classList.remove("drop-target");
    });
  }

  function finishDrag() {
    clearDropMarks();
    els.list.querySelectorAll(".dragging").forEach(function (el) { el.classList.remove("dragging"); });
    ui.dragged = null;
  }

  els.list.addEventListener("dragstart", function (e) {
    const li = e.target.closest("li.task");
    if (!li || li.classList.contains("editing")) return;
    ui.dragged = { day: li.dataset.day, id: li.dataset.id };
    li.classList.add("dragging");
    e.dataTransfer.effectAllowed = "move";
    try { e.dataTransfer.setData("text/plain", li.dataset.id); } catch (err) { /* ignore */ }
  });

  els.list.addEventListener("dragover", function (e) {
    if (!ui.dragged || !canReorder() || ui.dragged.day !== ui.activeDay) return;
    const li = e.target.closest("li.task");
    if (!li || li.dataset.id === ui.dragged.id) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    const rect = li.getBoundingClientRect();
    const after = e.clientY > rect.top + rect.height / 2;
    clearDropMarks();
    li.classList.add(after ? "drop-after" : "drop-before");
  });

  els.list.addEventListener("drop", function (e) {
    if (!ui.dragged || !canReorder() || ui.dragged.day !== ui.activeDay) return;
    const li = e.target.closest("li.task");
    if (!li) return;
    e.preventDefault();
    const after = li.classList.contains("drop-after");
    App.tasks.reorder(ui.dragged.day, ui.dragged.id, li.dataset.id, after);
    finishDrag();
    renderAll();
    announce("Task reordered");
  });

  els.list.addEventListener("dragend", finishDrag);

  els.tabs.addEventListener("dragover", function (e) {
    const tab = e.target.closest(".tab");
    if (!ui.dragged || !tab || tab.dataset.day === ui.dragged.day) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    clearDropMarks();
    tab.classList.add("drop-target");
  });

  els.tabs.addEventListener("dragleave", function (e) {
    const tab = e.target.closest(".tab");
    if (tab) tab.classList.remove("drop-target");
  });

  els.tabs.addEventListener("drop", function (e) {
    const tab = e.target.closest(".tab");
    if (!ui.dragged || !tab || tab.dataset.day === ui.dragged.day) return;
    e.preventDefault();
    const target = tab.dataset.day;
    App.tasks.move(ui.dragged.day, ui.dragged.id, target);
    finishDrag();
    renderAll();
    notify("Task moved to " + dayInfo(target).label + ".");
  });

  /* ---------- Theme controls ---------- */
  function syncSettingsUI() {
    const s = App.settings.get();
    els.accent.value = s.accent;
    els.mode.textContent = MODE_LABELS[s.mode];
    els.mode.setAttribute("aria-label", "Color mode: " + s.mode + ". Click to change.");
  }

  els.accent.addEventListener("change", function () {
    App.settings.set({ accent: els.accent.value });
    syncSettingsUI();
  });

  els.mode.addEventListener("click", function () {
    const modes = App.settings.MODES;
    const next = modes[(modes.indexOf(App.settings.get().mode) + 1) % modes.length];
    App.settings.set({ mode: next });
    syncSettingsUI();
    announce("Color mode: " + next);
  });

  /* ---------- Export / import ---------- */
  els.exportBtn.addEventListener("click", function () {
    const json = JSON.stringify(App.tasks.exportData(), null, 2);
    const url = URL.createObjectURL(new Blob([json], { type: "application/json" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = "task-tracker-" + App.dates.today() + ".json";
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
    notify("Exported your tasks.");
  });

  els.importBtn.addEventListener("click", function () { els.importFile.click(); });

  els.importFile.addEventListener("change", function () {
    const file = els.importFile.files[0];
    els.importFile.value = "";
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function () {
      try {
        const obj = JSON.parse(String(reader.result));
        if (!window.confirm("Replace all current tasks with the contents of \u201C" + file.name + "\u201D?")) return;
        const count = App.tasks.importData(obj);
        if (obj && obj.settings) App.settings.set(obj.settings);
        syncSettingsUI();
        App.calendar.setCollapsed(App.settings.get().calendarCollapsed);
        ui.editing = null;
        clearFilters(true);
        renderAll();
        notify("Imported " + count + (count === 1 ? " task." : " tasks."));
      } catch (err) {
        notify("Couldn't import that file: " + err.message);
      }
    };
    reader.onerror = function () { notify("Couldn't read that file."); };
    reader.readAsText(file);
  });

  /* ---------- Weekly reset & new-day handling ---------- */
  function checkNewWeek() {
    if (App.tasks.weeklyReset()) {
      renderAll();
      notify("New week! Your weekly tasks were un-checked.");
    }
  }

  window.addEventListener("focus", checkNewWeek);
  document.addEventListener("visibilitychange", function () {
    if (!document.hidden) checkNewWeek();
  });

  /* ---------- Init ---------- */
  App.tasks.weeklyReset();
  syncSettingsUI();
  App.calendar.init({
    getDueInfo: App.tasks.dueInfo,
    onSelect: onCalendarSelect,
    onNewDay: function () {
      checkNewWeek();
      renderAll();
    },
  });
  renderAll();

  // Offline support / "Add to home screen" (needs http(s), not file://)
  if ("serviceWorker" in navigator && /^https?:$/.test(location.protocol)) {
    navigator.serviceWorker.register("sw.js").catch(function () { /* optional */ });
  }
})();
