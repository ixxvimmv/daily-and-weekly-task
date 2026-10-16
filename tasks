/* Task data and logic (no DOM code in this file) */
(function () {
  "use strict";

  const App = window.App;

  const PRIORITY_WEIGHT = { high: 3, medium: 2, low: 1, none: 0 };

  function normalizeTask(t) {
    t = t && typeof t === "object" ? t : {};
    return {
      id: t.id ? String(t.id) : App.makeId(),
      text: String(t.text == null ? "" : t.text).trim().slice(0, 200),
      done: Boolean(t.done),
      due: App.dates.isValid(t.due) ? t.due : "",
      priority: PRIORITY_WEIGHT.hasOwnProperty(t.priority) ? t.priority : "none",
      recurring: Boolean(t.recurring),
    };
  }

  /* ---------- Load ---------- */
  const data = {};
  App.DAYS.forEach(function (d) {
    const raw = App.storage.getJSON(d.key, []);
    data[d.key] = Array.isArray(raw) ? raw.map(normalizeTask).filter(function (t) { return t.text; }) : [];
  });

  function save(day) {
    App.storage.setJSON(day, data[day]);
  }

  function find(day, id) {
    return data[day].find(function (t) { return t.id === id; });
  }

  /* ---------- Queries ---------- */
  function list(day) {
    return data[day];
  }

  function allItems() {
    const items = [];
    App.DAYS.forEach(function (d) {
      data[d.key].forEach(function (task) { items.push({ day: d.key, task: task }); });
    });
    return items;
  }

  // Map of ISO date -> { open, total } for the calendar dots
  function dueInfo() {
    const map = new Map();
    allItems().forEach(function (item) {
      const due = item.task.due;
      if (!due) return;
      const entry = map.get(due) || { open: 0, total: 0 };
      entry.total += 1;
      if (!item.task.done) entry.open += 1;
      map.set(due, entry);
    });
    return map;
  }

  function sortItems(items, mode) {
    const indexed = items.map(function (item, i) { return { item: item, i: i }; });
    if (mode === "due") {
      indexed.sort(function (a, b) {
        const ad = a.item.task.due;
        const bd = b.item.task.due;
        if (ad && bd && ad !== bd) return ad < bd ? -1 : 1;
        if (ad && !bd) return -1;
        if (!ad && bd) return 1;
        return a.i - b.i;
      });
    } else if (mode === "priority") {
      indexed.sort(function (a, b) {
        return PRIORITY_WEIGHT[b.item.task.priority] - PRIORITY_WEIGHT[a.item.task.priority] || a.i - b.i;
      });
    }
    return indexed.map(function (x) { return x.item; });
  }

  /* ---------- Changes ---------- */
  function add(day, fields) {
    const task = normalizeTask(Object.assign({}, fields, { id: App.makeId() }));
    if (!task.text) return null;
    data[day].push(task);
    save(day);
    return task;
  }

  function update(day, id, fields) {
    const task = find(day, id);
    if (!task) return null;
    const next = normalizeTask(Object.assign({}, task, fields, { id: task.id }));
    if (!next.text) return null;
    Object.assign(task, next);
    save(day);
    return task;
  }

  function toggle(day, id) {
    const task = find(day, id);
    if (!task) return null;
    task.done = !task.done;
    save(day);
    return task;
  }

  // The remove / clear functions return [{ task, index }] so the change can be undone with restore()
  function remove(day, id) {
    const index = data[day].findIndex(function (t) { return t.id === id; });
    if (index < 0) return [];
    const removed = data[day].splice(index, 1)[0];
    save(day);
    return [{ task: removed, index: index }];
  }

  function clearDone(day) {
    const removed = [];
    const kept = [];
    data[day].forEach(function (task, index) {
      if (task.done) removed.push({ task: task, index: index });
      else kept.push(task);
    });
    data[day] = kept;
    save(day);
    return removed;
  }

  function clearAll(day) {
    const removed = data[day].map(function (task, index) { return { task: task, index: index }; });
    data[day] = [];
    save(day);
    return removed;
  }

  function restore(day, items) {
    items
      .slice()
      .sort(function (a, b) { return a.index - b.index; })
      .forEach(function (item) {
        data[day].splice(Math.min(item.index, data[day].length), 0, item.task);
      });
    save(day);
  }

  function move(fromDay, id, toDay) {
    if (fromDay === toDay) return null;
    const index = data[fromDay].findIndex(function (t) { return t.id === id; });
    if (index < 0) return null;
    const task = data[fromDay].splice(index, 1)[0];
    data[toDay].push(task);
    save(fromDay);
    save(toDay);
    return task;
  }

  function reorder(day, id, targetId, after) {
    const arr = data[day];
    const from = arr.findIndex(function (t) { return t.id === id; });
    if (from < 0 || id === targetId) return false;
    const task = arr.splice(from, 1)[0];
    const to = arr.findIndex(function (t) { return t.id === targetId; });
    if (to < 0) {
      arr.splice(from, 0, task);
      return false;
    }
    arr.splice(after ? to + 1 : to, 0, task);
    save(day);
    return true;
  }

  /* ---------- Weekly reset ---------- */
  // Un-checks completed "Repeat weekly" tasks when a new week (Monday) has started.
  function weeklyReset() {
    const weekKey = App.dates.weekStart(new Date());
    const last = App.storage.get(App.KEYS.weekReset);
    if (last === weekKey) return false;

    let changed = false;
    if (last) {
      App.DAYS.forEach(function (d) {
        let dayChanged = false;
        data[d.key].forEach(function (task) {
          if (task.recurring && task.done) {
            task.done = false;
            dayChanged = true;
          }
        });
        if (dayChanged) {
          save(d.key);
          changed = true;
        }
      });
    }
    App.storage.set(App.KEYS.weekReset, weekKey);
    return changed;
  }

  /* ---------- Export / import ---------- */
  function exportData() {
    const tasks = {};
    App.DAYS.forEach(function (d) { tasks[d.key] = data[d.key]; });
    return {
      app: "task-tracker",
      version: 2,
      exportedAt: new Date().toISOString(),
      tasks: tasks,
      settings: App.settings.get(),
    };
  }

  // Replaces all tasks. Throws if the file has no recognizable day lists.
  function importData(obj) {
    const source = obj && typeof obj === "object" ? (obj.tasks && typeof obj.tasks === "object" ? obj.tasks : obj) : null;
    if (!source) throw new Error("This doesn't look like a task tracker file.");

    const known = App.DAYS.filter(function (d) { return Array.isArray(source[d.key]); });
    if (!known.length) throw new Error("No task lists were found in this file.");

    let count = 0;
    App.DAYS.forEach(function (d) {
      const raw = Array.isArray(source[d.key]) ? source[d.key] : [];
      data[d.key] = raw.map(normalizeTask).filter(function (t) { return t.text; });
      count += data[d.key].length;
      save(d.key);
    });
    return count;
  }

  App.tasks = {
    list: list,
    allItems: allItems,
    dueInfo: dueInfo,
    sortItems: sortItems,
    add: add,
    update: update,
    toggle: toggle,
    remove: remove,
    clearDone: clearDone,
    clearAll: clearAll,
    restore: restore,
    move: move,
    reorder: reorder,
    weeklyReset: weeklyReset,
    exportData: exportData,
    importData: importData,
  };
})();
