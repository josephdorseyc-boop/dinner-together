// v0.2.2 outcome-based regression checks (+ recovery-candidate readiness mirror). Faithful JS mirror of the corrected
// Scheduling.swift + SessionStore semantics. Validates the ALGORITHMS only —
// it is NOT proof the Swift app compiles or behaves correctly on-device.
// Matching native tests cover core outcomes; native execution is still pending.
const assert = require('node:assert/strict');
const MIN = 60000;
const t0 = 1760000000 * 1000;
let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };

// ---------- mirror of Scheduling.swift ----------
const effMinutes = (step, durations) => Math.max(1, Math.min(480, durations[step.id] ?? step.minutes));

function plan(menu, session) {
  const out = [];
  for (const dish of menu.dishes) {
    const total = dish.reduce((s, x) => s + effMinutes(x, session.durationOverrides), 0);
    let cursor = session.serveAt - total * MIN;
    let prevEnd = null;
    for (const step of dish) {
      const m = effMinutes(step, session.durationOverrides);
      const baseStart = cursor; cursor += m * MIN;
      const plannedStart = Math.max(baseStart, prevEnd ?? baseStart);
      const plannedEnd = plannedStart + m * MIN;
      const rec = session.records[step.id];
      let dispStart, dispEnd;
      let expectedEnd;
      if (rec?.state === 'cooking') {
        dispStart = rec.actualStart ?? plannedStart;
        dispEnd = rec.timerDeadline ?? dispStart + (rec.confirmedMinutes ?? m) * MIN;
        expectedEnd = rec.timerDeadline ?? dispEnd;
      } else if (rec?.state === 'done') {
        dispStart = plannedStart; dispEnd = plannedEnd;
        expectedEnd = rec.actualEnd ?? plannedEnd;
      } else { dispStart = plannedStart; dispEnd = plannedEnd; expectedEnd = plannedEnd; }
      // r5: running-max carry (review r4 product note) — mirrors projectedEnds.
      prevEnd = Math.max(prevEnd ?? expectedEnd, expectedEnd);
      out.push({ step, minutes: m, start: dispStart, end: dispEnd, plannedStart, plannedEnd, id: step.id });
    }
  }
  return out.sort((a, b) => a.start - b.start || (a.id < b.id ? -1 : 1));
}

function dependencyInfo(plan_, menu, session, stepID) {
  const dish=menu.dishes.find(d=>d.some(s=>s.id===stepID));
  const idx=dish?.findIndex(s=>s.id===stepID)??-1;
  if(idx<=0)return null;
  const pred=dish.slice(0,idx).filter(s=>(session.records[s.id]?.state??'notStarted')!=='done').at(-1);
  if(!pred)return null;
  return {predecessorTitle:pred.title,readyAt:session.records[pred.id]?.timerDeadline??plan_.find(p=>p.id===pred.id)?.plannedEnd??session.serveAt};
}
function blockedInfo(plan_,menu,session,stepID,now){
 const p=plan_.find(s=>s.id===stepID);
 return !p||now<p.plannedStart?null:dependencyInfo(plan_,menu,session,stepID);
}
function expectedMealEnd(menu,session){
 const ends=plan(menu,session).map(p=>{const r=session.records[p.id];
 return r?.state==='done'?(r.actualEnd??p.plannedEnd):r?.state==='cooking'?(r.timerDeadline??p.end):p.plannedEnd;});
 return ends.length?Math.max(...ends):session.serveAt;
}

// ---------- recovery candidate: now-aware readiness (mirrors Scheduling.swift additions) ----------
const READINESS_NOTICE_THRESHOLD = MIN;
function projectedEnds(menu, session, now) {
  const byID = Object.fromEntries(plan(menu, session).map(p => [p.id, p]));
  const ends = {};
  for (const dish of menu.dishes) {
    let prevEnd = null;
    for (const step of dish) {
      const p = byID[step.id]; if (!p) continue;
      const rec = session.records[step.id];
      const state = rec?.state ?? 'notStarted';
      let end;
      if (state === 'done') end = rec.actualEnd ?? p.plannedEnd;
      else if (state === 'cooking') end = Math.max(rec.timerDeadline ?? p.end, now);
      else { const floor = Math.max(prevEnd ?? now, now); end = Math.max(p.plannedStart, floor) + p.minutes * MIN; }
      ends[step.id] = end;
      // Review finding 1: the dependency carry is a running maximum, so an
      // out-of-order Done step cannot pull later steps ahead of earlier work.
      prevEnd = Math.max(prevEnd ?? end, end);
    }
  }
  return ends;
}
const projectedReadiness = (menu, session, now) => {
  const v = Object.values(projectedEnds(menu, session, now)); return v.length ? Math.max(...v) : session.serveAt;
};
const allSteps = menu => menu.dishes.flat();
function readinessReport(menu, session, now) {
  // Review finding 2: a finished dinner has no unfinished work to report on.
  if (!allSteps(menu).some(s => (session.records[s.id]?.state ?? 'notStarted') !== 'done')) return null;
  const ends = projectedEnds(menu, session, now);
  const rank = id => ({ cooking: 2, notStarted: 1, done: 0 })[session.records[id]?.state ?? 'notStarted'];
  const entries = Object.entries(ends);
  if (!entries.length) return null;
  const critical = entries.reduce((best, cur) => {
    if (!best) return cur;
    if (cur[1] !== best[1]) return cur[1] > best[1] ? cur : best;
    if (rank(cur[0]) !== rank(best[0])) return rank(cur[0]) > rank(best[0]) ? cur : best;
    return cur[0] < best[0] ? cur : best;
  }, null);
  const readyAt = critical[1], drift = readyAt - session.serveAt;
  if (drift < READINESS_NOTICE_THRESHOLD) return null;
  const dish = menu.dishes.find(d => d.some(s => s.id === critical[0])) ?? [];
  const lowerBound = dish.some(s => { const r = session.records[s.id]; return r?.state === 'cooking' && (r.timerDeadline ?? now) <= now; });
  return { serveAt: session.serveAt, estimatedReadyAt: readyAt,
    driftMinutes: Math.max(1, Math.round(drift / MIN)),
    lowerBoundMinutes: Math.max(1, Math.floor(drift / MIN)),   // r5 A2-1: 'at least' may only claim the floor
    moveMinutes: Math.max(1, Math.ceil(drift / MIN)),          // review finding 4: round UP for the move
    estimateIsLowerBound: lowerBound,
    criticalStepID: critical[0],
    reason: holdUpReason(menu, session, now, critical[0], readyAt) };
}
function holdUpReason(menu, session, now, criticalID, readyAt) {
  const dish = menu.dishes.find(d => d.some(s => s.id === criticalID));
  const step = dish?.find(s => s.id === criticalID);
  if (!step) return 'Some steps are running later than planned.';
  const planByID = Object.fromEntries(plan(menu, session).map(p => [p.id, p]));
  const rec = session.records[step.id], state = rec?.state ?? 'notStarted';
  if (state === 'done') return `"${step.title}" finished at ${readyAt}.`;
  if (state === 'cooking') {
    const deadline = rec.timerDeadline ?? readyAt;
    return deadline <= now ? `The "${step.title}" timer ended at ${deadline} — check the food; mark this step done when it's ready.`
                           : `The "${step.title}" timer ends at ${deadline}.`;
  }
  const pendingMinutes = dish.filter(s => (session.records[s.id]?.state ?? 'notStarted') === 'notStarted')
    .reduce((t, s) => t + effMinutes(s, session.durationOverrides), 0);
  const remaining = `about ${pendingMinutes} min of ${step.dish} steps remain`;
  const firstIndex = dish.findIndex(s => (session.records[s.id]?.state ?? 'notStarted') !== 'done');
  if (firstIndex < 0) return `About ${pendingMinutes} min of ${step.dish} steps remain.`;
  const first = dish[firstIndex], firstRec = session.records[first.id], fs = firstRec?.state ?? 'notStarted';
  if (fs === 'cooking') {
    const deadline = firstRec.timerDeadline ?? now;
    return deadline <= now ? `The "${first.title}" timer ended at ${deadline} — check the food; mark that step done when it's ready. After it, ${remaining}.`
                           : `The "${first.title}" timer ends at ${deadline}, then ${remaining}.`;
  }
  if (fs === 'notStarted') {
    const lateBy = now - (planByID[first.id]?.plannedStart ?? now);
    if (lateBy >= MIN) return `"${first.title}" is ${Math.floor(lateBy / MIN)} min late to start, and ${remaining}.`;
    const lateFinish = dish.slice(0, firstIndex).map(s => {
      const r = session.records[s.id], p = planByID[s.id];
      if (!r || r.state !== 'done' || r.actualEnd == null || !p) return null;
      const late = r.actualEnd - p.plannedEnd;
      return late >= MIN ? { step: s, minutes: Math.round(late / MIN) } : null;
    }).filter(Boolean).sort((a, b) => b.minutes - a.minutes)[0];
    if (lateFinish) return `"${lateFinish.step.title}" finished ${lateFinish.minutes} min late.`;
  }
  return `About ${pendingMinutes} min of ${step.dish} steps remain.`;
}

function checkFeasibility(menu, serveAt, durations, now) {
  const longest = Math.max(...menu.dishes.map(d => d.reduce((s, x) => s + effMinutes(x, durations), 0)));
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
      if (deadline < newServeAt - MIN)
        earlyNotes.push(`The "${p.step.title}" timer deadline is ${deadline} — about ${Math.floor((newServeAt - deadline) / MIN)} min before the new dinner time. Check the food to confirm it's ready. We won't guess a safe holding time; check your recipe.`);
    } else if(movedByID[p.id].plannedStart!==p.plannedStart) shifts.push({ stepID: p.id, from: p.plannedStart, to: movedByID[p.id].plannedStart });
  }
  return { minutes, newServeAt, shifts, earlyFinishNotes: earlyNotes, doneCount, runningCount };
}
const applyDelay = (session, proposal) => ({ ...session, serveAt: proposal.newServeAt });

function completeStepEffects(session, menu, stepID, now, oldPlan) {
  const newPlan = plan(menu, session);
  const oldByID = Object.fromEntries(oldPlan.map(p => [p.id, p]));
  const newByID = Object.fromEntries(newPlan.map(p => [p.id, p]));
  const dish = menu.dishes.find(d => d.some(s => s.id === stepID));
  if (!dish) return { affectedSteps: [], proposedServeAt: null, explanation: [] };
  const idx = dish.findIndex(s => s.id === stepID);
  const affected = [];
  for (const later of dish.slice(idx + 1)) {
    const o = oldByID[later.id], q = newByID[later.id];
    if (o && q && (session.records[later.id]?.state??'notStarted')==='notStarted' && q.plannedStart > o.plannedStart)
      affected.push({ stepID: later.id, from: o.plannedStart, to: q.plannedStart });
  }
  const explanation = [];
  if (affected.length) {
    const mins = Math.max(...affected.map(s => Math.round((s.to - s.from) / MIN)));
    explanation.push(`finished late — ${affected.length} steps moved ~${mins} min`);
  }
  const effectiveEnd = Math.max(expectedMealEnd(menu,session),now);
  let proposed = null;
  if (effectiveEnd > session.serveAt + MIN) { proposed = effectiveEnd; explanation.push('serving infeasible'); }
  return { affectedSteps: affected, proposedServeAt: proposed, explanation };
}

function attentionWarnings(plan_, session, now, limit = 4) {
  const active = plan_.filter(p => p.step.handsOn && (session.records[p.id]?.state ?? 'notStarted') !== 'done' && p.end > now);
  const w = [];
  for (let i = 0; i < active.length; i++) for (let j = i + 1; j < active.length; j++) {
    const a = active[i], b = active[j];
    if (a.start < b.end && b.start < a.end) {
      w.push({ stepIDs: [a.id, b.id], message: `"${a.step.title}" overlaps "${b.step.title}"` });
      if (w.length >= limit) return w;
    }
  }
  return w;
}
const doThisNow = (plan_, session, now) => plan_
  .filter(p => (session.records[p.id]?.state ?? 'notStarted') !== 'done' && p.start <= now)
  .sort((a, b) => (a.step.handsOn !== b.step.handsOn) ? (b.step.handsOn - a.step.handsOn) : a.start - b.start);

// ---------- fixtures ----------
const S = (id, dish, title, minutes, handsOn = true) => ({ id, dish, title, minutes, detail: '', handsOn });
const testMenu = () => ({
  id: 'test', title: 'Test', dishes: [
    [S('a1', 'A', 'Prep A', 10), S('a2', 'A', 'Cook A', 20), S('a3', 'A', 'Rest A', 10, false)],
    [S('b1', 'B', 'Prep B', 5), S('b2', 'B', 'Cook B', 15, false)],
  ]
});
const newSession = (serveAt) => ({ serveAt, durationOverrides: {}, records: {} });

// ---------- mini store (mirrors SessionStore semantics) ----------
function makeStore(serveAt, notif) {
  let session = newSession(serveAt);
  const undoStack = [];
  let nextRun=0;
  const pushUndo = (label) => { undoStack.push({ label, session: JSON.parse(JSON.stringify(session)) }); };
  const api = {
    get session() { return session; },
    setServeAtDirect(d) { session.serveAt = d; },
    async startStep(id, { force = false, now = Date.now(), menu } = {}) {
      const p = plan(menu, session).find(x => x.id === id);
      if (!p || (session.records[id]?.state ?? 'notStarted') !== 'notStarted') return { r: 'noOp' };
      if (!force) {
        const b = dependencyInfo(plan(menu, session), menu, session, id);
        if (b) return { r: 'blocked', ...b };
      }
      pushUndo(`Started ${id}`);
      const deadline = now + p.minutes * MIN;
      session.records[id] = { runID: ++nextRun, state: 'cooking', actualStart: now, confirmedMinutes: p.minutes, timerDeadline: deadline };
      // async authorization boundary with revalidation (issue 4)
      const runID=session.records[id].runID;
      const granted = await notif.ensureAuthorization();
      if (!granted) return { r: 'started-dropped' };
      const cur = session.records[id];
      if (!cur || cur.runID!==runID || cur.state !== 'cooking' || cur.actualStart!==now || cur.timerDeadline !== deadline) return { r: 'started-dropped' };
      notif.schedule(id, deadline);
      return { r: 'started' };
    },
    async completeStep(id, { confirmed = false, now = Date.now(), menu } = {}) {
      const p = plan(menu, session).find(x => x.id === id);
      if (!p || (session.records[id]?.state ?? 'notStarted') === 'done') return { r: 'noOp' };
      const rec = session.records[id] ?? {};
      if (rec.actualStart == null && !confirmed) return { r: 'needsStartConfirmation' };
      pushUndo(`Finished ${id}`);
      const oldPlan = plan(menu, session);
      session.records[id] = { ...rec, state: 'done', actualEnd: now }; // actualStart stays null if unknown
      notif.cancel(id);
      const fx = completeStepEffects(session, menu, id, now, oldPlan);
      return { r: 'completed', fx, session };
    },
    confirmDelay(proposal) { pushUndo('delay'); session = applyDelay(session, proposal); },
    // Recovery candidate: no cached proposal. The report is derived at call
    // time and the move goes through the reviewed delay path, once.
    readinessReport(now, menu) { return readinessReport(menu, session, now); },
    readinessMoveProposal(now, menu) {
      const report = readinessReport(menu, session, now);
      return report ? proposeDelay(session, menu, report.moveMinutes) : null;
    },
    moveDinnerToEstimatedReadiness(now, menu) {
      const report = readinessReport(menu, session, now);
      const proposal = api.readinessMoveProposal(now, menu);
      if (!report || !proposal) return null;
      pushUndo('move'); session = applyDelay(session, proposal); return proposal;
    },
    chooseMenu() { pushUndo('menu'); }, // undoable now
    undoLast() { const f = undoStack.pop(); if (f) { session = f.session; notif.cancelAll(); } },
    resetSession() { pushUndo('reset'); session = newSession(session.serveAt); notif.cancelAll(); },
    canUndo: () => undoStack.length > 0,
    undoDepth: () => undoStack.length,
  };
  return api;
}
const mockNotif = (authDelayMs = 0, grant = true) => {
  const m = { scheduled: [], cancelled: [], authCalls: 0,
    async ensureAuthorization() { m.authCalls++; if (authDelayMs) await new Promise(r => setTimeout(r, authDelayMs)); return grant; },
    schedule(id) { m.scheduled.push(id); }, cancel(id) { m.cancelled.push(id); }, cancelAll() {} };
  return m;
};
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// ================= scenarios =================
(async () => {
// 1. backward plan converges; sequential (planned) chains
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const p = plan(menu, newSession(serveAt));
  ok(p.length === 5, 'plan has 5 steps');
  for (const dish of menu.dishes) {
    const chain = dish.map(s => p.find(x => x.id === s.id));
    ok(chain.at(-1).plannedEnd === serveAt, 'chain ends at serving time');
    for (let i = 1; i < chain.length; i++) ok(chain[i - 1].plannedEnd === chain[i].plannedStart, 'planned chain sequential');
  }
}
// 2. duration overrides
{
  const p = plan(testMenu(), { ...newSession(t0 + 3600e3), durationOverrides: { a2: 30 } });
  const c = p.find(x => x.id === 'a2');
  ok(c.minutes === 30 && c.plannedEnd - c.plannedStart === 1800e3, 'override respected');
}
// 3. feasibility
{
  const menu = testMenu();
  ok(!checkFeasibility(menu, t0 + 1800e3, {}, t0).ok, 'past-start flagged');
  ok(checkFeasibility(menu, t0 + 1800e3, {}, t0).earliestServeAt === t0 + 2400e3, 'earliest offered');
  ok(checkFeasibility(menu, t0 + 3600e3, {}, t0).ok, 'feasible ok');
}
// 4. ISSUE 3: running predecessor pushes dependent; pinned display; distinct planned
{
  const menu = testMenu(), serveAt = t0; // dinner 7:00
  const s = newSession(serveAt);
  s.records['a2'] = { state: 'cooking', actualStart: t0 - 20 * MIN, confirmedMinutes: 20, timerDeadline: t0 };
  const p = plan(menu, s);
  const rest = p.find(x => x.id === 'a3');
  ok(rest.plannedStart === t0, 'rest planned at 7:00 deadline, not 6:50 clock time');
  const cook = p.find(x => x.id === 'a2');
  ok(cook.start === t0 - 20 * MIN && cook.end === t0, 'running display pinned to actuals');
  ok(cook.plannedStart === t0 - 30 * MIN, 'original planned interval kept distinct');
}
// 5. blocked: due-by-clock vs ready-to-start
{
  const menu = testMenu();
  const s = newSession(t0);
  s.records['a2'] = { state: 'cooking', actualStart: t0 - 20 * MIN, confirmedMinutes: 20, timerDeadline: t0 };
  const p = plan(menu, s);
  ok(blockedInfo(p, menu, s, 'a3', t0 - 15 * MIN) === null, 'upcoming, not blocked');
  const b = blockedInfo(p, menu, s, 'a3', t0 + 5 * MIN);
  ok(b && b.predecessorTitle === 'Cook A' && b.readyAt === t0, 'blocked with reason after planned start');
  ok(blockedInfo(p, menu, s, 'a1', t0 + 5 * MIN) === null, 'first steps never blocked');
}
// 6. ACCEPTANCE: 6:30 start, 20-min timer; 6:35 delay 10
{
  const menu = testMenu(), start630 = t0, serveAt = t0 + 80 * MIN;
  const notif = mockNotif(), store = makeStore(serveAt, notif);
  store.session.records['a1'] = { state: 'done', actualStart: start630 - 20 * MIN, actualEnd: start630 - 10 * MIN };
  ok((await store.startStep('a2', { now: start630, menu })).r === 'started', 'cook started');
  const prop = proposeDelay(store.session, menu, 10);
  ok(prop.newServeAt === serveAt + 10 * MIN, 'dinner moves 10');
  const oldA3 = plan(menu, store.session).find(x => x.id === 'a3').plannedStart;
  store.confirmDelay(prop);
  const rec = store.session.records['a2'];
  ok(rec.actualStart === start630 && rec.timerDeadline === start630 + 20 * MIN, 'actuals pinned');
  ok(store.session.records['a1'].actualEnd === start630 - 10 * MIN, 'history preserved');
  ok(plan(menu, store.session).find(x => x.id === 'a3').plannedStart === oldA3 + 10 * MIN, 'pending +10');
  ok(prop.earlyFinishNotes.length > 0, 'early finish flagged');
}
// 7. repeated delays accumulate
{
  const menu = testMenu(), notif = mockNotif(), store = makeStore(t0 + 3600e3, notif);
  await store.startStep('a2', { force:true, now: t0, menu });
  const oldA3 = plan(menu, store.session).find(x => x.id === 'a3').plannedStart;
  for (const m of [5, 10, 15]) store.confirmDelay(proposeDelay(store.session, menu, m));
  ok(store.session.serveAt === t0 + 3600e3 + 1800e3, 'serveAt +30');
  ok(store.session.records['a2'].timerDeadline === t0 + 1200e3, 'running pinned');
  ok(plan(menu, store.session).find(x => x.id === 'a3').plannedStart === oldA3 + 1800e3, 'pending +30');
}
// 8. ISSUE 2 REGRESSION (full flow): complete → proposal +67 → accept → ends +67, not +74
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const notif = mockNotif(), store = makeStore(serveAt, notif);
  const oldPlan = plan(menu, store.session);
  const a1End = oldPlan.find(x => x.id === 'a1').plannedEnd;
  store.session.records['a1'] = { state: 'done', actualStart: a1End - 10 * MIN, actualEnd: a1End + 7 * MIN };
  const fx = completeStepEffects(store.session, menu, 'a1', a1End + 7 * MIN, oldPlan);
  ok(fx.affectedSteps.length === 2, 'a2,a3 affected');
  ok(fx.proposedServeAt === serveAt + 7 * MIN, 'proposal at +67');
  // Recovery candidate: the derived report agrees with the completion effect,
  // and the explicit move applies it through the reviewed delay path.
  const rep = store.readinessReport(a1End + 7 * MIN, menu);
  ok(rep && rep.estimatedReadyAt === fx.proposedServeAt && rep.driftMinutes === 7, 'derived report matches +67');
  ok(store.moveDinnerToEstimatedReadiness(a1End + 7 * MIN, menu) !== null, 'explicit move applied');
  const finalPlan = plan(menu, store.session);
  const a3End = finalPlan.find(x => x.id === 'a3').plannedEnd;
  ok(a3End === serveAt + 7 * MIN, `a3 ends at +67 (got +${(a3End - serveAt) / MIN}) — no double apply`);
  const a2Start = finalPlan.find(x => x.id === 'a2').plannedStart;
  ok(a2Start === a1End + 7 * MIN, 'dependent consistent with actual end');
}
// 9. late completion affected; on-time no-op
{
  const menu = testMenu(), serveAt = t0 + 3600e3;
  const s = newSession(serveAt);
  const oldPlan = plan(menu, s);
  const a1End = oldPlan.find(x => x.id === 'a1').plannedEnd;
  s.records['a1'] = { state: 'done', actualStart: a1End - 600e3, actualEnd: a1End };
  const fx = completeStepEffects(s, menu, 'a1', a1End, oldPlan);
  ok(fx.affectedSteps.length === 0 && fx.proposedServeAt === null, 'on-time changes nothing');
}
// 10. start blocked without force; force works
{
  const menu = testMenu(), notif = mockNotif(), store = makeStore(Date.now() + 3600e3, notif);
  store.setServeAtDirect(Date.now() - 1800e3); // dinner 30 min ago
  const blocked = await store.startStep('a2', { now: Date.now(), menu });
  ok(blocked.r === 'blocked' && blocked.predecessorTitle === 'Prep A', 'blocked without force');
  ok((store.session.records['a2']?.state ?? 'notStarted') === 'notStarted', 'not started');
  const forced = await store.startStep('a2', { force: true, now: Date.now(), menu });
  ok(forced.r === 'started' && store.session.records['a2'].state === 'cooking', 'force starts');
}
// 11. unknown start: confirmation required; never fabricated
{
  const menu = testMenu(), notif = mockNotif(), store = makeStore(t0 + 3600e3, notif);
  ok((await store.completeStep('a1', { now: t0, menu })).r === 'needsStartConfirmation', 'asks first');
  ok((store.session.records['a1']?.state ?? 'notStarted') === 'notStarted', 'not yet done');
  ok((await store.completeStep('a1', { confirmed: true, now: t0, menu })).r === 'completed', 'completes');
  const rec = store.session.records['a1'];
  ok(rec.state === 'done' && rec.actualEnd === t0 && rec.actualStart == null, 'start stays unknown');
}
// 12. undo exact restore (start + delay)
{
  const menu = testMenu(), notif = mockNotif(), store = makeStore(t0 + 3600e3, notif);
  await store.startStep('a1', { now: t0, menu });
  store.undoLast();
  const r = store.session.records['a1'] ?? { state: 'notStarted' };
  ok(r.state === 'notStarted' && r.timerDeadline == null && r.actualStart == null, 'exact restore');
  const before = store.session.serveAt;
  store.confirmDelay(proposeDelay(store.session, menu, 10));
  store.undoLast();
  ok(store.session.serveAt === before, 'delay undone');
  ok(store.canUndo() === false, 'all actions undone; stack empty');
}
// 13. ISSUE 4: pending auth + undo/reset → no stale reminder; undisturbed → scheduled; denied → nothing
{
  const menu = testMenu();
  const n1 = mockNotif(80), s1 = makeStore(t0 + 3600e3, n1);
  const t1 = s1.startStep('a1', { now: t0, menu });
  await sleep(20); s1.undoLast();
  ok((await t1).r === 'started-dropped' && n1.scheduled.length === 0, 'undo during pending auth → dropped');
  const n2 = mockNotif(80), s2 = makeStore(t0 + 3600e3, n2);
  const t2 = s2.startStep('a1', { now: t0, menu });
  await sleep(20); s2.resetSession();
  ok((await t2).r === 'started-dropped' && n2.scheduled.length === 0, 'reset during pending auth → dropped');
  const n3 = mockNotif(), s3 = makeStore(t0 + 3600e3, n3);
  ok((await s3.startStep('a1', { now: t0, menu })).r === 'started' && n3.scheduled.length === 1, 'undisturbed → scheduled');
  const n4 = mockNotif(0, false), s4 = makeStore(t0 + 3600e3, n4);
  ok((await s4.startStep('a1', { now: t0, menu })).r === 'started-dropped' && n4.scheduled.length === 0, 'denied → nothing');
}
// 14. persistence round-trip incl. unknown start
{
  const s = newSession(t0 + 3600e3);
  s.records['a1'] = { state: 'done', actualStart: null, actualEnd: t0 + 600e3 };
  s.durationOverrides = { a1: 12 };
  const loaded = JSON.parse(JSON.stringify(s));
  ok(loaded.records['a1'].actualStart == null && loaded.durationOverrides['a1'] === 12, 'round trip');
}
// 15. date rollover
{
  const menu = testMenu(), serveAt = t0 + 20 * MIN;
  const p = plan(menu, newSession(serveAt));
  ok(p.length === 5 && Math.min(...p.map(x => x.plannedStart)) < serveAt, 'spans midnight');
  ok(proposeDelay(newSession(serveAt), menu, 10).newServeAt === serveAt + 10 * MIN, 'delay across midnight');
}
// 16. attention warnings
{
  const menu = testMenu(), s = newSession(t0 + 3600e3);
  const w = attentionWarnings(plan(menu, s), s, t0);
  ok(w.length > 0, 'pileup warns');
  const solo = { id: 'solo', title: 'Solo', dishes: [[S('x1', 'X', 'Solo', 10)]] };
  ok(attentionWarnings(plan(solo, newSession(t0 + 3600e3)), newSession(t0 + 3600e3), t0).length === 0, 'no false warning');
}
// 17. doThisNow hands-on first
{
  const menu = testMenu(), s = newSession(t0 + 3600e3), p = plan(menu, s);
  const first = Math.min(...p.map(x => x.start));
  const doing = doThisNow(p, s, first + MIN);
  ok(doing.length > 0 && doing[0].step.handsOn, 'hands-on first');
}
// 18. chooseMenu undoable
{
  const menu = testMenu(), notif = mockNotif(), store = makeStore(t0 + 3600e3, notif);
  store.chooseMenu(); store.undoLast();
  ok(store.session.serveAt === t0 + 3600e3, 'menu change undone restores session');
}
// 19. stale no-progress re-anchor
{
  const s = newSession(t0 - 3600e3); // yesterday's dinner time, never started
  const lastOpened = t0 - 86400e3;
  const stale = lastOpened < t0 - 86400e3 + 86400e3 && s.serveAt < t0; // mirrors staleStatus
  ok(stale, 'no-progress stale detected');
}
// Additional v0.2.2 outcome regressions (20–25).
{
 const m=testMenu(),s=newSession(t0+60*MIN);
 s.records.a1={state:'done',actualEnd:t0+30*MIN};
 s.records.a2={state:'cooking',actualStart:t0+40*MIN,timerDeadline:t0+60*MIN};
 ok(dependencyInfo(plan(m,s),m,s,'a3')!==null,'early Start is gated before scheduled time');
 const ns=mockNotif(),store=makeStore(t0+60*MIN,ns);
 const result=await store.startStep('a2',{now:t0,menu:m});
 ok(result.r==='blocked'&&!store.session.records.a2,'store cannot bypass early prerequisite');
}
{
 const m=testMenu(),ns=mockNotif(30),store=makeStore(t0+60*MIN,ns);
 await Promise.all([store.startStep('a1',{now:t0,menu:m}),store.startStep('b1',{now:t0,menu:m})]);
 ok(ns.scheduled.includes('a1')&&ns.scheduled.includes('b1'),'two independent starts both retain reminders');
 const ns2=mockNotif(30),store2=makeStore(t0+60*MIN,ns2);
 const start=store2.startStep('a1',{now:t0,menu:m});
 store2.confirmDelay(proposeDelay(store2.session,m,10));await start;
 ok(ns2.scheduled.includes('a1'),'dinner delay does not suppress running reminder');
}
{
 const m=testMenu(),s=newSession(t0+60*MIN);
 s.records.a1={state:'done',actualEnd:t0+30*MIN};s.records.a2={state:'done',actualEnd:t0+60*MIN};
 const before=plan(m,s);s.records.a3={state:'done',actualStart:t0+60*MIN,actualEnd:t0+64*MIN};
 const fx=completeStepEffects(s,m,'a3',t0+64*MIN,before);
 ok(fx.proposedServeAt===t0+64*MIN,'finished dish uses actual end, not unconsumed estimate');
 s.records.b2={state:'cooking',actualStart:t0+50*MIN,timerDeadline:t0+80*MIN};
 ok(expectedMealEnd(m,s)===t0+80*MIN,'latest other running dish determines meal readiness');
}
{
 const m=testMenu(),s=newSession(t0+60*MIN);
 s.records.a2={state:'cooking',actualStart:t0+50*MIN,timerDeadline:t0+70*MIN};
 const prop=proposeDelay(s,m,5);
 ok(!prop.shifts.some(x=>x.stepID==='a3'),'unchanged dependent omitted from claimed shifts');
 ok(prop.shifts.every(x=>x.to!==x.from),'all claimed shifts actually move');
}
{
 const m=testMenu(),s=newSession(t0+60*MIN);
 s.records.a2={state:'done',actualEnd:t0+50*MIN};
 ok(dependencyInfo(plan(m,s),m,s,'a3')?.predecessorTitle==='Prep A','forced or corrected middle step does not erase earlier prerequisite');
}
{
 const m=testMenu(),s=newSession(t0+60*MIN);
 s.records.a1={state:'done',actualEnd:t0+25*MIN};
 s.records.a2={state:'cooking',actualStart:t0+55*MIN,timerDeadline:t0+75*MIN};
 const old=plan(m,s);
 s.records.a3={state:'done',actualEnd:t0+50*MIN};
 ok(expectedMealEnd(m,s)===t0+75*MIN,'early final completion cannot hide running middle step');
 ok(completeStepEffects(s,m,'a3',t0+50*MIN,old).proposedServeAt===t0+75*MIN,'out-of-order completion offers later dinner');
 s.records.a2={state:'notStarted'};s.durationOverrides.a2=90;
 ok(expectedMealEnd(m,s)>s.serveAt,'early final completion cannot hide pending middle step');
 const empty={dishes:[]};
 ok(expectedMealEnd(empty,s)===s.serveAt,'empty menu uses serving time fallback');
}

// ================= recovery candidate: derived readiness notice =================
// Mirrors RecoveryNoticeTests / RecoveryStoreTests in DinnerTogetherTests.swift
// (AGENT_PROMPT §6 scenarios 2–8). Same fixtures, same expected numbers.
const steakMenu = () => ({ id: 'steak', title: 'Steak night', dishes: [
  [S('s1','Steak','Prep the steak & sauce ingredients',10), S('s2','Steak','Cook the steak',20), S('s3','Steak','Rest steak & finish sauce',10)],
  [S('p1','Mash','Peel & cut potatoes',10), S('p2','Mash','Cook potatoes until tender',20,false), S('p3','Mash','Drain, mash & season',5)],
  [S('b1','Green beans','Trim beans & prep garlic',5), S('b2','Green beans','Cook & season beans',10)],
]});
// R1. on-time plan: no report, even at the exact first planned start
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  const firstStart = Math.min(...plan(menu, s).map(p => p.plannedStart));
  ok(readinessReport(menu, s, t0) === null, 'R1 nothing before cooking');
  ok(readinessReport(menu, s, firstStart) === null, 'R1 nothing at first planned start');
  ok(projectedReadiness(menu, s, firstStart) === serveAt, 'R1 projection equals dinner time');
}
// R2. scenario 2: late completion → drift reported, dinner unchanged, invariant readiness unchanged
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 37 * MIN };
  const rep = readinessReport(menu, s, t0 + 37 * MIN);
  ok(rep && rep.serveAt === serveAt && rep.estimatedReadyAt === serveAt + 7 * MIN && rep.driftMinutes === 7, 'R2 +7 drift');
  ok(rep.criticalStepID === 'a3' && rep.reason.includes('Prep A') && rep.reason.includes('7 min late'), 'R2 reason names late finish');
  ok(rep.moveMinutes === 7 && rep.estimateIsLowerBound === false, 'R2 whole-minute drift: move equals display; not a lower bound');
  ok(s.serveAt === serveAt && expectedMealEnd(menu, s) === serveAt + 7 * MIN, 'R2 dinner untouched; plan-anchored readiness unchanged');
}
// R3. pending work late to start projects forward; the plan does not creep
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  const firstStart = plan(menu, s).find(p => p.id === 'a1').plannedStart;
  const now = firstStart + 8 * MIN;
  ok(projectedReadiness(menu, s, now) === serveAt + 8 * MIN, 'R3 idle lateness counted');
  const rep = readinessReport(menu, s, now);
  ok(rep.driftMinutes === 8 && rep.criticalStepID === 'a3' && rep.reason.includes('late to start'), 'R3 report');
  ok(plan(menu, s).find(p => p.id === 'a1').plannedStart === firstStart && expectedMealEnd(menu, s) === serveAt, 'R3 plan unchanged');
}
// R4. running deadline pushes the estimate; reason names the timer
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualEnd: t0 + 40 * MIN };
  s.records.a2 = { state: 'cooking', actualStart: t0 + 40 * MIN, confirmedMinutes: 20, timerDeadline: t0 + 60 * MIN };
  const rep = readinessReport(menu, s, t0 + 45 * MIN);
  ok(rep.estimatedReadyAt === serveAt + 10 * MIN && rep.driftMinutes === 10 && rep.criticalStepID === 'a3', 'R4 +10 from deadline');
  ok(rep.reason.includes('Cook A') && rep.reason.includes('ends at'), 'R4 reason');
}
// R5. scenario 7: expired timer stays cooking, floors at now, says "check"
{
  const menu = testMenu(), serveAt = t0 + 10 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualEnd: t0 - 20 * MIN };
  s.records.a2 = { state: 'cooking', actualStart: t0 - 20 * MIN, confirmedMinutes: 20, timerDeadline: t0 };
  s.records.b1 = { state: 'done', actualEnd: t0 - 10 * MIN }; s.records.b2 = { state: 'done', actualEnd: t0 };
  const now = t0 + 5 * MIN;
  ok(s.records.a2.state === 'cooking' && s.records.a2.actualEnd == null && s.records.a2.timerDeadline === t0, 'R5 nothing fabricated');
  ok(projectedReadiness(menu, s, now) === now + 10 * MIN, 'R5 rest can start no earlier than now');
  const rep = readinessReport(menu, s, now);
  ok(rep.driftMinutes === 5 && rep.reason.includes('timer ended') && rep.reason.includes('check the food') && !rep.reason.includes('mark it done'), 'R5 report says check, never implies done');
  ok(rep.estimateIsLowerBound === true, 'R5 floored estimate is flagged as a lower bound');
}
// R6. scenario 5: final done early, middle still cooking beyond dinner
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualEnd: t0 + 25 * MIN };
  s.records.a2 = { state: 'cooking', actualStart: t0 + 55 * MIN, timerDeadline: t0 + 75 * MIN };
  s.records.a3 = { state: 'done', actualEnd: t0 + 50 * MIN };
  s.records.b1 = { state: 'done', actualEnd: t0 + 45 * MIN }; s.records.b2 = { state: 'done', actualEnd: t0 + 60 * MIN };
  const rep = readinessReport(menu, s, t0 + 3400e3); // +56:40, mid-cook
  ok(rep.estimatedReadyAt === t0 + 75 * MIN && rep.criticalStepID === 'a2' && rep.driftMinutes === 15, 'R6 running middle step sets estimate');
}
// R7. scenario 6: final done early, prerequisite pending (90-min override)
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualEnd: t0 + 25 * MIN }; s.records.a3 = { state: 'done', actualEnd: t0 + 50 * MIN };
  s.durationOverrides.a2 = 90;
  const now = t0 + 50 * MIN, rep = readinessReport(menu, s, now);
  ok(rep && rep.criticalStepID === 'a2' && rep.estimatedReadyAt >= now + 90 * MIN, 'R7 pending prerequisite sets estimate');
}
// R8. review finding 2: a finished dinner reports nothing, however late it finished
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  for (const id of ['a1', 'a2', 'b1']) s.records[id] = { state: 'done', actualEnd: t0 + 50 * MIN };
  s.records.b2 = { state: 'done', actualEnd: serveAt };
  s.records.a3 = { state: 'done', actualEnd: serveAt + 6 * MIN };
  ok(projectedReadiness(menu, s, serveAt + 6 * MIN) === serveAt + 6 * MIN, 'R8 history still honest');
  ok(readinessReport(menu, s, serveAt + 6 * MIN) === null, 'R8 finished dinner: no report');
}
// Store-level fixture: steak night, mash & beans on schedule, steak prep 7 min late at +37.
async function lateSteakPrep() {
  const menu = steakMenu(), serveAt = t0 + 60 * MIN, notif = mockNotif(), store = makeStore(serveAt, notif);
  const p1Plan = plan(menu, store.session).find(p => p.id === 'p1');
  await store.startStep('p1', { now: p1Plan.plannedStart, menu });
  await store.completeStep('p1', { now: p1Plan.plannedEnd, menu });
  await store.startStep('p2', { now: p1Plan.plannedEnd, menu });
  const s1Plan = plan(menu, store.session).find(p => p.id === 's1');
  await store.startStep('s1', { now: s1Plan.plannedStart, menu });
  const lateEnd = s1Plan.plannedEnd + 7 * MIN;
  const r = await store.completeStep('s1', { now: lateEnd, menu });
  return { menu, store, serveAt, lateEnd, fx: r.fx };
}
// R9. scenario 3: explicit move applies once; second move no-op; undo restores
{
  const { menu, store, serveAt, lateEnd } = await lateSteakPrep();
  const p2Deadline = store.session.records.p2.timerDeadline;
  ok(store.readinessReport(lateEnd, menu).driftMinutes === 7, 'R9 drift 7');
  const depth = store.undoDepth();
  ok(store.moveDinnerToEstimatedReadiness(lateEnd, menu) !== null && store.session.serveAt === serveAt + 7 * MIN, 'R9 moved to +67');
  ok(store.undoDepth() === depth + 1 && store.readinessReport(lateEnd, menu) === null, 'R9 one undo frame; no residual drift');
  ok(store.moveDinnerToEstimatedReadiness(lateEnd, menu) === null && store.session.serveAt === serveAt + 7 * MIN && store.undoDepth() === depth + 1, 'R9 second move is a no-op');
  ok(store.session.records.p2.timerDeadline === p2Deadline, 'R9 running deadline untouched');
  const s3End = plan(menu, store.session).find(p => p.id === 's3').plannedEnd;
  ok(s3End === serveAt + 7 * MIN, 'R9 dependents end once-late, not twice');
  store.undoLast();
  ok(store.session.serveAt === serveAt && store.readinessReport(lateEnd, menu).driftMinutes === 7 && store.session.records.p2.timerDeadline === p2Deadline, 'R9 undo restores');
}
// R10. scenario 4: report and move use the CURRENT readiness, not the earlier +7
{
  const { menu, store, serveAt, lateEnd } = await lateSteakPrep();
  ok(store.readinessReport(lateEnd, menu).estimatedReadyAt === serveAt + 7 * MIN, 'R10 initial +7');
  const later = lateEnd + 8 * MIN;
  ok(store.readinessReport(later, menu).estimatedReadyAt === serveAt + 15 * MIN, 'R10 idle time counted');
  await store.startStep('s2', { now: later, menu });
  const rep = store.readinessReport(later, menu);
  ok(rep.estimatedReadyAt === serveAt + 15 * MIN && rep.driftMinutes === 15, 'R10 running steak sets +15');
  store.moveDinnerToEstimatedReadiness(later, menu);
  ok(store.session.serveAt === serveAt + 15 * MIN && store.readinessReport(later, menu) === null, 'R10 applied current estimate');
}
// R11. scenario 8: undo / reset / menu change leave no stale drift
{
  const { menu, store, lateEnd } = await lateSteakPrep();
  ok(store.readinessReport(lateEnd, menu) !== null, 'R11 drift present');
  store.undoLast();
  ok(store.readinessReport(lateEnd - 7 * MIN, menu) === null, 'R11 undo clears (steak cooking to +30)');
  await store.completeStep('s1', { now: lateEnd, menu });
  ok(store.readinessReport(lateEnd, menu) !== null, 'R11 drift again');
  store.resetSession();
  ok(store.readinessReport(t0 + 10 * MIN, menu) === null, 'R11 reset clears');
}
// R12. explicit +10 delay covers +7 drift → notice clears
{
  const { menu, store, serveAt, lateEnd } = await lateSteakPrep();
  store.confirmDelay(proposeDelay(store.session, menu, 10));
  ok(store.session.serveAt === serveAt + 10 * MIN && store.readinessReport(lateEnd, menu) === null, 'R12 delay recomputes drift');
}
// R13. completion effect still reports infeasibility (recorded, not presented); dinner unchanged
{
  const { store, serveAt, fx } = await lateSteakPrep();
  ok(fx.proposedServeAt === serveAt + 7 * MIN && store.session.serveAt === serveAt, 'R13 effect computed; serveAt unchanged');
}
// R14. rounding: drift of 7m40s moves dinner by 8 whole minutes and clears the notice
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, notif = mockNotif(), store = makeStore(serveAt, notif);
  store.session.records.a1 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 37 * MIN + 40e3 };
  const now = t0 + 37 * MIN + 40e3;
  const rep = store.readinessReport(now, menu);
  ok(rep.driftMinutes === 8 && rep.moveMinutes === 8, 'R14 7m40s: display 8, move 8');
  store.moveDinnerToEstimatedReadiness(now, menu);
  ok(store.session.serveAt === serveAt + 8 * MIN && store.readinessReport(now, menu) === null, 'R14 single application within threshold');
}
// R15. review finding 1 (reviewer's repro): a1 pending, a2 done at 40, a3 pending, now 55 → 75, not 65
{
  const dishOnly = { id: 'one', title: 'One', dishes: [[S('a1','A','Prep A',10), S('a2','A','Cook A',20), S('a3','A','Rest A',10,false)]] };
  const s = newSession(t0 + 60 * MIN); s.records.a2 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 40 * MIN };
  const now = t0 + 55 * MIN, ends = projectedEnds(dishOnly, s, now);
  ok(ends.a1 === t0 + 65 * MIN && ends.a2 === t0 + 40 * MIN && ends.a3 === t0 + 75 * MIN, 'R15 carry is a running max; done step keeps its actual end');
  ok(projectedReadiness(dishOnly, s, now) === t0 + 75 * MIN, 'R15 readiness 75 (was 65)');
  ok(dependencyInfo(plan(dishOnly, s), dishOnly, s, 'a3')?.predecessorTitle === 'Prep A', 'R15 consistent with start eligibility');
  // Same shape inside the two-dish fixture used by the native test.
  const menu = testMenu(), s2 = newSession(t0 + 60 * MIN);
  s2.records.a2 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 40 * MIN };
  s2.records.b1 = { state: 'done', actualEnd: t0 + 45 * MIN };
  s2.records.b2 = { state: 'cooking', actualStart: t0 + 45 * MIN, timerDeadline: t0 + 60 * MIN };
  const rep = readinessReport(menu, s2, now);
  ok(rep.criticalStepID === 'a3' && rep.driftMinutes === 15 && rep.estimatedReadyAt === t0 + 75 * MIN, 'R15 two-dish fixture matches native test');
}
// R16. review finding 1, running variant: a1 running to 62, a2 done at 40, a3 pending → a3 ends 72
{
  const menu = testMenu(), s = newSession(t0 + 60 * MIN);
  s.records.a1 = { state: 'cooking', actualStart: t0 + 52 * MIN, timerDeadline: t0 + 62 * MIN };
  s.records.a2 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 40 * MIN };
  s.records.b1 = { state: 'done', actualEnd: t0 + 45 * MIN }; s.records.b2 = { state: 'done', actualEnd: t0 + 60 * MIN };
  const ends = projectedEnds(menu, s, t0 + 55 * MIN);
  ok(ends.a1 === t0 + 62 * MIN && ends.a2 === t0 + 40 * MIN && ends.a3 === t0 + 72 * MIN, 'R16 final ≥ running deadline + its duration');
}
// R17. review finding 4: 7 m 20 s drift → display 7, move 8; preview and apply agree; never undershoots
{
  const menu = steakMenu(), serveAt = t0 + 60 * MIN, notif = mockNotif(), store = makeStore(serveAt, notif);
  const p1Plan = plan(menu, store.session).find(p => p.id === 'p1');
  await store.startStep('p1', { now: p1Plan.plannedStart, menu });
  await store.completeStep('p1', { now: p1Plan.plannedEnd, menu });
  await store.startStep('p2', { now: p1Plan.plannedEnd, menu });
  const s1Plan = plan(menu, store.session).find(p => p.id === 's1');
  await store.startStep('s1', { now: s1Plan.plannedStart, menu });
  const lateEnd = s1Plan.plannedEnd + 7 * MIN + 20e3;
  await store.completeStep('s1', { now: lateEnd, menu });
  const rep = store.readinessReport(lateEnd, menu), preview = store.readinessMoveProposal(lateEnd, menu);
  ok(rep.estimatedReadyAt === serveAt + 7 * MIN + 20e3 && rep.driftMinutes === 7 && rep.moveMinutes === 8, 'R17 display nearest, move up');
  ok(preview.newServeAt === serveAt + 8 * MIN, 'R17 preview +8');
  const applied = store.moveDinnerToEstimatedReadiness(lateEnd, menu);
  ok(applied.newServeAt === preview.newServeAt && store.session.serveAt === serveAt + 8 * MIN, 'R17 apply matches preview');
  ok(store.session.serveAt >= rep.estimatedReadyAt && store.readinessReport(lateEnd, menu) === null, 'R17 never before the estimate; applied once');
  // Exact whole minutes don't overshoot.
  const s = newSession(serveAt); s.records.a1 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 37 * MIN };
  ok(readinessReport(testMenu(), s, t0 + 37 * MIN).moveMinutes === 7, 'R17 exact minutes: move 7');
}
// R18. review finding 2 at the store boundary: finished dinner → no report, no move, nothing changes
{
  const menu = steakMenu(), serveAt = t0 + 60 * MIN, notif = mockNotif(), store = makeStore(serveAt, notif);
  for (const step of allSteps(menu)) store.session.records[step.id] = { state: 'done', actualStart: t0 + 30 * MIN, actualEnd: t0 + 60 * MIN };
  store.session.records.s3.actualEnd = serveAt + 9 * MIN;
  const now = serveAt + 9 * MIN, depth = store.undoDepth();
  ok(store.readinessReport(now, menu) === null && store.readinessMoveProposal(now, menu) === null, 'R18 no report / preview');
  ok(store.moveDinnerToEstimatedReadiness(now, menu) === null && store.session.serveAt === serveAt && store.undoDepth() === depth, 'R18 no move, no undo frame');
}
// R19. in-order and out-of-order-final scenarios unchanged by the carry fix (regression guard)
{
  const menu = testMenu(), serveAt = t0 + 60 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 37 * MIN };
  ok(readinessReport(menu, s, t0 + 37 * MIN).estimatedReadyAt === serveAt + 7 * MIN, 'R19 in-order late prep still +7');
  const s2 = newSession(serveAt);
  s2.records.a1 = { state: 'done', actualEnd: t0 + 25 * MIN };
  s2.records.a2 = { state: 'cooking', actualStart: t0 + 55 * MIN, timerDeadline: t0 + 75 * MIN };
  s2.records.a3 = { state: 'done', actualEnd: t0 + 50 * MIN };
  s2.records.b1 = { state: 'done', actualEnd: t0 + 45 * MIN }; s2.records.b2 = { state: 'done', actualEnd: t0 + 60 * MIN };
  ok(readinessReport(menu, s2, t0 + 56 * MIN).estimatedReadyAt === t0 + 75 * MIN, 'R19 out-of-order final still bounded by running middle');
}
// R20. r5 plan() carry: a1 running to 62, a2 done out of order at 40, a3 pending → a3 planned from 62; in-order unchanged
{
  const menu = testMenu(), s = newSession(t0 + 60 * MIN);
  s.records.a1 = { state: 'cooking', actualStart: t0 + 52 * MIN, timerDeadline: t0 + 62 * MIN };
  s.records.a2 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 40 * MIN };
  const pl = plan(menu, s), a3 = pl.find(p => p.id === 'a3');
  ok(a3.plannedStart === t0 + 62 * MIN && a3.plannedEnd === t0 + 72 * MIN, 'R20 plan waits for the running prerequisite');
  const b = dependencyInfo(pl, menu, s, 'a3');
  ok(b.predecessorTitle === 'Prep A' && b.readyAt === a3.plannedStart, 'R20 plan and dependency gate agree');
  const inOrder = newSession(t0 + 60 * MIN); inOrder.records.a1 = { state: 'done', actualEnd: t0 + 25 * MIN };
  ok(plan(menu, inOrder).find(p => p.id === 'a2').plannedStart === t0 + 30 * MIN, 'R20 in-order early finish unchanged');
  // reviewer's single-dish shape: planned a3 unchanged at 50 (a1 planned end 30 < a2 actual 40), projection still 75
  const s2 = newSession(t0 + 60 * MIN); s2.records.a2 = { state: 'done', actualStart: t0 + 20 * MIN, actualEnd: t0 + 40 * MIN };
  ok(plan(menu, s2).find(p => p.id === 'a3').plannedStart === t0 + 50 * MIN && projectedReadiness(menu, s2, t0 + 55 * MIN) === t0 + 75 * MIN, 'R20 pending-first shape: plan 50, projection 75');
}
// R21. r5 A2-1: lower-bound minutes floor; 5 m 40 s → at least 5, about 6, move 6
{
  const menu = testMenu(), serveAt = t0 + 10 * MIN, s = newSession(serveAt);
  s.records.a1 = { state: 'done', actualEnd: t0 - 20 * MIN };
  s.records.a2 = { state: 'cooking', actualStart: t0 - 20 * MIN, confirmedMinutes: 20, timerDeadline: t0 };
  s.records.b1 = { state: 'done', actualEnd: t0 - 10 * MIN }; s.records.b2 = { state: 'done', actualEnd: t0 };
  const now = t0 + 5 * MIN + 40e3, rep = readinessReport(menu, s, now);
  ok(rep.estimateIsLowerBound && rep.estimatedReadyAt === now + 10 * MIN, 'R21 lower bound at now + rest');
  ok(rep.lowerBoundMinutes === 5 && rep.driftMinutes === 6 && rep.moveMinutes === 6, 'R21 floor 5 / nearest 6 / up 6');
  ok(rep.lowerBoundMinutes <= rep.driftMinutes && rep.driftMinutes <= rep.moveMinutes, 'R21 ordering');
}
// R22. r5 A2-2: early-finish notes name the timer deadline and ask to check, never claim readiness
{
  const menu = testMenu(), s = newSession(t0 + 80 * MIN);
  s.records.a1 = { state: 'done', actualStart: t0 - 20 * MIN, actualEnd: t0 - 10 * MIN };
  s.records.a2 = { state: 'cooking', actualStart: t0, confirmedMinutes: 20, timerDeadline: t0 + 20 * MIN };
  const prop = proposeDelay(s, menu, 10);
  ok(prop.earlyFinishNotes.length === 1 && prop.earlyFinishNotes[0].includes('timer deadline') && prop.earlyFinishNotes[0].includes('Check the food') && !prop.earlyFinishNotes[0].includes('will be ready'), 'R22 deadline ≠ readiness');
}
console.log(`PASS: ${n} supplemental outcome assertions (v0.2.8 + recovery candidate r5; JavaScript model, not Swift execution).`);
})().catch(e => { console.error(e); process.exit(1); });
