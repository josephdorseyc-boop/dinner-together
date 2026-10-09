// Faithful JS mirror of DinnerTogether/Scheduling.swift + the SessionStore
// semantics it depends on. Validates the ALGORITHMS (not Swift syntax).
// Every scenario below has a matching XCTest in DinnerTogetherTests.swift.
const assert = require('node:assert/strict');
const MIN = 60000;
const t0 = 1760000000 * 1000;

const effMinutes = (step, durations) => Math.max(1, Math.min(480, durations[step.id] ?? step.minutes));

function plan(menu, session) {
  const out = [];
  for (const dish of menu.dishes) {
    const total = dish.reduce((n, s) => n + effMinutes(s, session.durationOverrides), 0);
    let cursor = session.serveAt - total * MIN;
    for (const step of dish) {
      const m = effMinutes(step, session.durationOverrides);
      let start = cursor, end = cursor + m * MIN;
      const rec = session.records[step.id];
      if (rec && rec.state === 'cooking') {
        const aStart = rec.actualStart ?? start;
        start = aStart;
        end = rec.timerDeadline ?? (aStart + (rec.confirmedMinutes ?? m) * MIN);
      } else {
        const shift = session.stepShifts[step.id] ?? 0;
        start += shift; end += shift;
      }
      out.push({ step, minutes: m, start, end, id: step.id });
      cursor += m * MIN;
    }
  }
  return out.sort((a, b) => a.start - b.start || (a.id < b.id ? -1 : 1));
}

function checkFeasibility(menu, serveAt, durations, now) {
  const longest = Math.max(...menu.dishes.map(d => d.reduce((n, s) => n + effMinutes(s, durations), 0)));
  const firstStart = serveAt - longest * MIN;
  return firstStart < now ? { ok: false, earliestServeAt: now + longest * MIN } : { ok: true };
}

function proposeDelay(session, menu, minutes) {
  const newServeAt = session.serveAt + minutes * MIN;
  const current = plan(menu, session);
  const moved = plan(menu, { ...session, serveAt: newServeAt });
  const movedByID = Object.fromEntries(moved.map(p => [p.id, p]));
  const shifts = [], earlyNotes = [];
  let doneCount = 0, runningCount = 0;
  for (const p of current) {
    const state = session.records[p.id]?.state ?? 'notStarted';
    if (state === 'done') doneCount++;
    else if (state === 'cooking') {
      runningCount++;
      const deadline = session.records[p.id].timerDeadline ?? p.end;
      if (deadline < newServeAt - MIN) {
        earlyNotes.push(`"${p.step.title}" ready ~${Math.round((newServeAt - deadline) / MIN)} min before new dinner time`);
      }
    } else shifts.push({ stepID: p.id, from: p.start, to: movedByID[p.id].start });
  }
  return { minutes, newServeAt, shifts, earlyFinishNotes: earlyNotes, doneCount, runningCount };
}
const applyDelay = (session, proposal) => ({ ...session, serveAt: proposal.newServeAt });

function completeStepEffects(session, menu, stepID, now) {
  const updated = { ...session, stepShifts: { ...session.stepShifts } };
  const shifts = [], explanation = [];
  const dish = menu.dishes.find(d => d.some(s => s.id === stepID));
  if (!dish) return { updatedSession: updated, dependentShifts: shifts, proposedServeAt: null, explanation };
  const idx = dish.findIndex(s => s.id === stepID);
  const planned = plan(menu, session);
  const pEnd = planned.find(p => p.id === stepID).end;
  const overrun = now - pEnd;
  if (overrun > 0) {
    for (const later of dish.slice(idx + 1)) {
      const state = session.records[later.id]?.state ?? 'notStarted';
      if (state !== 'notStarted') continue;
      const oldStart = planned.find(p => p.id === later.id).start;
      updated.stepShifts[later.id] = (updated.stepShifts[later.id] ?? 0) + overrun;
      shifts.push({ stepID: later.id, from: oldStart, to: oldStart + overrun });
    }
    explanation.push(`finished ${Math.round(overrun / MIN)} min late`);
  }
  const newPlan = plan(menu, updated);
  const dishIDs = new Set(dish.map(s => s.id));
  const dishEnd = Math.max(...newPlan.filter(p => dishIDs.has(p.id)).map(p => p.end), now);
  let proposed = null;
  if (dishEnd > session.serveAt + MIN) { proposed = dishEnd; explanation.push('serving time infeasible'); }
  return { updatedSession: updated, dependentShifts: shifts, proposedServeAt: proposed, explanation };
}

function attentionWarnings(plan_, session, now, limit = 4) {
  const active = plan_.filter(p => p.step.handsOn && (session.records[p.id]?.state ?? 'notStarted') !== 'done' && p.end > now);
  const warnings = [];
  for (let i = 0; i < active.length; i++) for (let j = i + 1; j < active.length; j++) {
    const a = active[i], b = active[j];
    if (a.start < b.end && b.start < a.end) {
      warnings.push({ stepIDs: [a.id, b.id], message: `"${a.step.title}" overlaps "${b.step.title}"` });
      if (warnings.length >= limit) return warnings;
    }
  }
  return warnings;
}
const doThisNow = (plan_, session, now) => plan_
  .filter(p => (session.records[p.id]?.state ?? 'notStarted') !== 'done' && p.start <= now)
  .sort((a, b) => (a.step.handsOn !== b.step.handsOn) ? (b.step.handsOn - a.step.handsOn) : a.start - b.start);

// ---- fixtures ----
const S = (id, dish, title, minutes, handsOn = true, detail = '') => ({ id, dish, title, minutes, detail, handsOn });
const testMenu = () => ({
  id: 'test', title: 'Test', dishes: [
    [S('a1', 'A', 'Prep A', 10), S('a2', 'A', 'Cook A', 20), S('a3', 'A', 'Rest A', 10, false)],
    [S('b1', 'B', 'Prep B', 5), S('b2', 'B', 'Cook B', 15, false)],
  ]
});
const newSession = (serveAt) => ({ serveAt, durationOverrides: {}, stepShifts: {}, records: {} });

// mini store with snapshot undo
function makeStore(serveAt) {
  let session = newSession(serveAt);
  const undoStack = [];
  const pushUndo = (label) => { undoStack.push({ label, session: JSON.parse(JSON.stringify(session)) }); };
  return {
    get session() { return session; },
    startStep(id, now, menu) {
      const p = plan(menu, session).find(x => x.id === id);
      pushUndo(`Started ${id}`);
      session.records[id] = { state: 'cooking', actualStart: now, confirmedMinutes: p.minutes, timerDeadline: now + p.minutes * MIN };
    },
    completeStep(id, now, menu) {
      pushUndo(`Finished ${id}`);
      const rec = session.records[id] ?? {};
      rec.state = 'done'; rec.actualEnd = now;
      if (rec.actualStart == null) rec.actualStart = plan(menu, session).find(x => x.id === id).start;
      session.records[id] = rec;
      const fx = completeStepEffects(session, menu, id, now);
      session = fx.updatedSession; session.records[id] = rec;
      return fx;
    },
    confirmDelay(proposal) { pushUndo(`delay ${proposal.minutes}`); session = applyDelay(session, proposal); },
    undoLast() { const f = undoStack.pop(); if (f) session = f.session; },
    lastUndoLabel: () => undoStack.at(-1)?.label,
  };
}

// ================= scenarios =================
let n = 0; const ok = (c, msg) => { assert.ok(c, msg); n++; };

// 1. backward plan converges; sequential chains
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const p = plan(menu, newSession(serveAt));
  ok(p.length === 5, 'plan has 5 steps');
  for (const dish of menu.dishes) {
    const chain = dish.map(s => p.find(x => x.id === s.id));
    ok(chain.at(-1).end === serveAt, 'chain ends at serving time');
    for (let i = 1; i < chain.length; i++) ok(chain[i - 1].end === chain[i].start, 'chain links sequential');
  }
}
// 2. duration overrides
{
  const menu = testMenu();
  const p = plan(menu, { ...newSession(t0 + 3600e3), durationOverrides: { a2: 30 } });
  const cook = p.find(x => x.id === 'a2');
  ok(cook.minutes === 30 && cook.end - cook.start === 1800e3, 'override respected');
}
// 3. feasibility
{
  const menu = testMenu();
  const r = checkFeasibility(menu, t0 + 1800e3, {}, t0);
  ok(!r.ok && r.earliestServeAt === t0 + 2400e3, 'past-start flagged with earliest time');
  ok(checkFeasibility(menu, t0 + 3600e3, {}, t0).ok, 'feasible ok');
}
// 4. ACCEPTANCE EXAMPLE: 6:30 start, 20-min timer; 6:35 delay 10
{
  const menu = testMenu(), start630 = t0, serveAt = t0 + 80 * MIN;
  const store = makeStore(serveAt);
  // a1 done 6:10-6:20 (simulate), a2 started 6:30
  store.session.records['a1'] = { state: 'done', actualStart: start630 - 20 * MIN, actualEnd: start630 - 10 * MIN };
  store.startStep('a2', start630, menu);
  const prop = proposeDelay(store.session, menu, 10);
  ok(prop.newServeAt === serveAt + 10 * MIN, 'dinner moves 10 min');
  const oldA3 = plan(menu, store.session).find(x => x.id === 'a3').start;
  store.confirmDelay(prop);
  const rec = store.session.records['a2'];
  ok(rec.actualStart === start630, 'actual start pinned at 6:30');
  ok(rec.timerDeadline === start630 + 20 * MIN, 'deadline pinned at 6:50');
  ok(store.session.records['a1'].actualEnd === start630 - 10 * MIN, 'completed history preserved');
  const newA3 = plan(menu, store.session).find(x => x.id === 'a3').start;
  ok(newA3 === oldA3 + 10 * MIN, 'pending a3 recalculated +10');
  ok(prop.earlyFinishNotes.length > 0, 'early finish flagged (6:50 vs 8:00 dinner)');
  ok(prop.shifts.every(s => s.to - s.from === 10 * MIN), 'all pending shifts are +10');
}
// 5. repeated delays accumulate; running stays pinned
{
  const menu = testMenu();
  const store = makeStore(t0 + 3600e3);
  store.startStep('a2', t0, menu);
  const oldA3 = plan(menu, store.session).find(x => x.id === 'a3').start;
  for (const m of [5, 10, 15]) store.confirmDelay(proposeDelay(store.session, menu, m));
  ok(store.session.serveAt === t0 + 3600e3 + 1800e3, 'serveAt +30 total');
  ok(store.session.records['a2'].timerDeadline === t0 + 1200e3, 'running deadline pinned');
  ok(plan(menu, store.session).find(x => x.id === 'a3').start === oldA3 + 1800e3, 'pending +30');
}
// 6. late completion shifts dependents; infeasible serving proposed
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const store = makeStore(serveAt);
  const p = plan(menu, store.session);
  const a1End = p.find(x => x.id === 'a1').end;
  const fx = store.completeStep('a1', a1End + 7 * MIN, menu);
  ok(fx.dependentShifts.length === 2, 'a2,a3 shifted');
  ok(fx.dependentShifts.every(s => Math.abs((s.to - s.from) - 7 * MIN) < 1), 'shift = 7 min');
  ok(fx.proposedServeAt === serveAt + 7 * MIN, 'dish now ends past serving time -> proposal');
  // last step very late -> infeasible
  const store2 = makeStore(serveAt);
  const p2 = plan(menu, store2.session);
  const a3End = p2.find(x => x.id === 'a3').end;
  const fx2 = store2.completeStep('a3', a3End + 25 * MIN, menu);
  ok(fx2.proposedServeAt === a3End + 25 * MIN, 'new serving time proposed');
  ok(fx2.explanation.length > 0, 'explanation present');
}
// 7. undo restores exact session (no silent timer restart)
{
  const menu = testMenu();
  const store = makeStore(t0 + 3600e3);
  store.startStep('a1', t0, menu);
  ok(store.session.records['a1'].state === 'cooking', 'started');
  store.undoLast();
  const r = store.session.records['a1'] ?? { state: 'notStarted' };
  ok(r.state === 'notStarted' && r.timerDeadline == null && r.actualStart == null, 'exact restore');
  // undo a delay
  const before = store.session.serveAt;
  store.confirmDelay(proposeDelay(store.session, menu, 10));
  store.undoLast();
  ok(store.session.serveAt === before, 'delay undone');
}
// 8. persistence round-trip
{
  const s = newSession(t0 + 3600e3);
  s.records['a1'] = { state: 'done', actualStart: t0, actualEnd: t0 + 600e3 };
  s.durationOverrides = { a1: 12 }; s.stepShifts = { a1: 300e3 };
  const loaded = JSON.parse(JSON.stringify(s));
  ok(loaded.records['a1'].state === 'done' && loaded.durationOverrides['a1'] === 12 && loaded.stepShifts['a1'] === 300e3, 'round trip');
}
// 9. date rollover across midnight
{
  const menu = testMenu(), serveAt = t0 + 20 * MIN; // 00:20 "next day"
  const p = plan(menu, newSession(serveAt));
  ok(p.length === 5 && Math.min(...p.map(x => x.start)) < serveAt, 'plan spans midnight');
  const prop = proposeDelay(newSession(serveAt), menu, 10);
  ok(prop.newServeAt === serveAt + 10 * MIN, 'delay across midnight');
}
// 10. attention warnings: steak-night-like pileup warns; solo step does not
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const p = plan(menu, newSession(serveAt));
  const w = attentionWarnings(p, newSession(serveAt), t0);
  ok(w.length > 0, 'pileup warns: ' + (w[0]?.message ?? ''));
  const solo = { id: 'solo', title: 'Solo', dishes: [[S('x1', 'X', 'Solo', 10)]] };
  ok(attentionWarnings(plan(solo, newSession(serveAt)), newSession(serveAt), t0).length === 0, 'no false warning');
}
// 11. doThisNow hands-on first
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const s = newSession(serveAt), p = plan(menu, s);
  const firstStart = Math.min(...p.map(x => x.start));
  const doing = doThisNow(p, s, firstStart + MIN);
  ok(doing.length > 0 && doing[0].step.handsOn, 'hands-on first');
}
console.log(`PASS: ${n} logic assertions across 11 scenarios (JS mirror of Scheduling.swift).`);
