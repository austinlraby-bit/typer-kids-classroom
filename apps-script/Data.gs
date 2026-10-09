function saveProgress(token, request) {
  try {
    const auth = requireSession_(token);
    request = request || {};
    const saveId = validateId_(request.saveId, 'save');
    const json = JSON.stringify(request.profile || {});
    if (json.length > KQ.MAX_PROGRESS_BYTES) throw new Error('Progress data is too large to save.');
    const lock = LockService.getScriptLock();
    lock.waitLock(KQ.LOCK_WAIT_MS);
    try {
      const sheet = getSpreadsheet_().getSheetByName(KQ.PROGRESS);
      const row = progressRow_(sheet, auth.studentId);
      const existing = row ? parseProgressRow_(sheet.getRange(row, 1, 1, 6).getValues()[0], auth.name) : freshProgress_(auth.studentId, auth.name);
      const sync = existing.profile._classroomSync || { version: 0, saveIds: [] };
      if (sync.saveIds.indexOf(saveId) !== -1) return { ok: true, version: sync.version, duplicate: true };
      const expected = Number(request.expectedVersion || 0);
      if (expected !== sync.version) {
        return { ok: false, conflict: true, version: sync.version, progress: existing };
      }
      const profile = sanitizeProfile_(request.profile, auth.studentId, auth.name);
      profile._classroomSync = { version: sync.version + 1, saveIds: sync.saveIds.concat(saveId).slice(-20), updatedAt: new Date().toISOString() };
      const values = progressValues_(auth.studentId, profile);
      if (row) sheet.getRange(row, 1, 1, values.length).setValues([values]);
      else sheet.appendRow(values);
      return { ok: true, version: profile._classroomSync.version };
    } finally {
      lock.releaseLock();
    }
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function saveActivity(token, request) {
  try {
    const auth = requireSession_(token);
    request = request || {};
    const sessionId = validateId_(request.sessionId, 'session');
    const seconds = Math.max(0, Math.min(86400, Math.floor(Number(request.activeSeconds) || 0)));
    const activity = String(request.activity || 'typing').slice(0, 80);
    const startedAt = new Date(request.startedAt);
    const date = isNaN(startedAt.getTime()) ? new Date() : startedAt;
    const lock = LockService.getScriptLock();
    lock.waitLock(KQ.LOCK_WAIT_MS);
    try {
      const sheet = getSpreadsheet_().getSheetByName(KQ.SESSIONS);
      const row = sessionRow_(sheet, sessionId);
      if (row) {
        const current = Number(sheet.getRange(row, 4).getValue()) || 0;
        if (seconds > current) sheet.getRange(row, 4, 1, 2).setValues([[seconds, activity]]);
      } else {
        sheet.appendRow([sessionId, auth.studentId, date, seconds, activity]);
      }
      return { ok: true, activeSeconds: seconds };
    } finally {
      lock.releaseLock();
    }
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function loadProgress_(studentId, name) {
  const sheet = getSpreadsheet_().getSheetByName(KQ.PROGRESS);
  const row = progressRow_(sheet, studentId);
  if (!row) return freshProgress_(studentId, name);
  return parseProgressRow_(sheet.getRange(row, 1, 1, 6).getValues()[0], name);
}

function freshProgress_(studentId, name) {
  return { version: 0, profile: {
    id: studentId, name: name, avatar: '🦊', created: new Date().toISOString(),
    settings: {}, lessons: {}, keyStats: {}, history: [], bests: { rain: 0, race: 0, bubbles: 0 },
    _classroomSync: { version: 0, saveIds: [] }
  }};
}

function parseProgressRow_(row, name) {
  let profile;
  try { profile = JSON.parse(row[5] || '{}'); } catch (e) { profile = {}; }
  profile = sanitizeProfile_(profile, String(row[0]), name);
  const sync = profile._classroomSync || { version: 0, saveIds: [] };
  return { version: Number(sync.version || 0), profile: profile };
}

function sanitizeProfile_(input, studentId, name) {
  const p = input && typeof input === 'object' ? input : {};
  const clean = {
    id: studentId,
    name: name,
    avatar: String(p.avatar || '🦊').slice(0, 8),
    created: String(p.created || new Date().toISOString()).slice(0, 40),
    settings: objectOnly_(p.settings),
    lessons: objectOnly_(p.lessons),
    keyStats: objectOnly_(p.keyStats),
    history: Array.isArray(p.history) ? p.history.slice(0, 200) : [],
    bests: objectOnly_(p.bests),
    typerKids: objectOnly_(p.typerKids),
    _classroomSync: objectOnly_(p._classroomSync)
  };
  return clean;
}

function objectOnly_(value) { return value && typeof value === 'object' && !Array.isArray(value) ? value : {}; }
function validateId_(value, label) {
  value = String(value || '');
  if (!/^[A-Za-z0-9_-]{8,100}$/.test(value)) throw new Error('Invalid ' + label + ' identifier.');
  return value;
}
function progressRow_(sheet, studentId) { return findRow_(sheet, 1, studentId); }
function sessionRow_(sheet, sessionId) { return findRow_(sheet, 1, sessionId); }
function findRow_(sheet, column, value) {
  if (!sheet || sheet.getLastRow() < 2) return 0;
  const cell = sheet.getRange(2, column, sheet.getLastRow() - 1, 1).createTextFinder(String(value)).matchEntireCell(true).findNext();
  return cell ? cell.getRow() : 0;
}
function progressValues_(studentId, p) {
  const typerProgress = p.typerKids && p.typerKids.progress;
  const lessonIds = typerProgress
    ? Object.keys(typerProgress).filter(id => typerProgress[id] && typerProgress[id].c)
    : Object.keys(p.lessons || {}).filter(id => p.lessons[id] && p.lessons[id].stars >= 2);
  const currentLesson = Math.max(1, lessonIds.length + 1);
  const typerRows = typerProgress ? Object.values(typerProgress).filter(Boolean) : [];
  const bestWpm = typerRows.length
    ? typerRows.reduce((m, h) => Math.max(m, Number(h.w) || 0), 0)
    : (p.history || []).reduce((m, h) => Math.max(m, Number(h.wpm) || 0), 0);
  const acc = typerRows.length ? typerRows.filter(h => h.a != null) : (p.history || []).filter(h => h.acc != null);
  const accuracy = acc.length
    ? Math.round(acc.reduce((s, h) => s + Number(typerRows.length ? h.a : h.acc || 0), 0) / acc.length)
    : 0;
  return [studentId, currentLesson, lessonIds.join(','), bestWpm, accuracy, JSON.stringify(p)];
}
