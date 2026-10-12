function enterClassroom(code) {
  try {
    code = String(code || '').trim();
    if (!/^\d{6}$/.test(code)) throw new Error('Enter the six-digit classroom code.');
    const attemptCache = CacheService.getScriptCache();
    const attempts = Number(attemptCache.get('class-attempts') || 0);
    if (attempts >= 10) throw new Error('Too many classroom code tries. Wait one minute, then try again.');
    const stored = PropertiesService.getScriptProperties().getProperty('CLASS_CODE_HASH');
    if (!stored) throw new Error('The classroom code is not set up yet. Ask your teacher.');
    const parts = stored.split('$');
    if (parts.length !== 3 || parts[0] !== 'v1' || !constantTimeEqual_(parts[2], digest_(parts[1] + ':' + code))) {
      attemptCache.put('class-attempts', String(attempts + 1), 60);
      Utilities.sleep(250);
      throw new Error('That classroom code is not correct.');
    }
    attemptCache.remove('class-attempts');
    const token = Utilities.getUuid() + Utilities.getUuid();
    CacheService.getScriptCache().put('class:' + digest_(token), '1', KQ.CLASS_GATE_TTL);
    return { ok: true, classToken: token };
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function requireClassroom_(classToken) {
  if (!classToken || typeof classToken !== 'string' || classToken.length > 200) throw new Error('Your classroom access expired. Enter the classroom code again.');
  const key = 'class:' + digest_(classToken);
  const cache = CacheService.getScriptCache();
  if (!cache.get(key)) throw new Error('Your classroom access expired. Enter the classroom code again.');
  cache.put(key, '1', KQ.CLASS_GATE_TTL);
}

function getLoginRoster(classToken) {
  try {
    requireClassroom_(classToken);
    const sheet = getSpreadsheet_().getSheetByName(KQ.STUDENTS);
    if (!sheet || sheet.getLastRow() < 2) return { ok: true, students: [] };
    const range = sheet.getRange(2, 1, sheet.getLastRow() - 1, 5);
    const rows = range.getDisplayValues();
    let changed = false;
    rows.forEach(r => {
      if (!r[0] && r[1]) { r[0] = 'stu_' + Utilities.getUuid().replace(/-/g, '').slice(0, 16); changed = true; }
      if (!r[4] && r[1]) { r[4] = 'TRUE'; changed = true; }
    });
    if (changed) range.setValues(rows);
    const students = rows
      .filter(r => r[0] && String(r[4]).toLowerCase() !== 'false' && r[4] !== '0')
      .map(r => ({ id: String(r[0]), name: `${r[1]}${r[2] ? ' ' + r[2] + '.' : ''}`, needsPin: !String(r[3]).startsWith('v1$') }))
      .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));
    return { ok: true, students: students };
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function createStudentPin(classToken, studentId, pin) {
  try {
    requireClassroom_(classToken);
    studentId = String(studentId || '');
    pin = String(pin || '');
    if (!/^\d{4}$/.test(pin)) throw new Error('Choose exactly four numbers for your PIN.');
    const lock = LockService.getScriptLock();
    lock.waitLock(KQ.LOCK_WAIT_MS);
    try {
      const sheet = getSpreadsheet_().getSheetByName(KQ.STUDENTS);
      const row = findRow_(sheet, 1, studentId);
      if (!row) throw new Error('That student was not found. Ask your teacher for help.');
      const values = sheet.getRange(row, 1, 1, 5).getDisplayValues()[0];
      if (String(values[4]).toLowerCase() === 'false' || values[4] === '0') throw new Error('Your account is not active. Ask your teacher for help.');
      if (String(values[3]).startsWith('v1$')) throw new Error('A PIN is already set for this name. Ask your teacher if you forgot it.');
      const salt = Utilities.getUuid().replace(/-/g, '');
      sheet.getRange(row, 4).setNumberFormat('@').setValue('v1$' + salt + '$' + hashPin_(pin, salt));
    } finally {
      lock.releaseLock();
    }
    return login(classToken, studentId, pin);
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function login(classToken, studentId, pin) {
  try {
    requireClassroom_(classToken);
    studentId = String(studentId || '');
    pin = String(pin || '');
    if (!/^\d{4}$/.test(pin)) throw new Error('Enter a four-digit PIN.');
    const attemptKey = 'attempt:' + digest_(studentId);
    const attemptCache = CacheService.getScriptCache();
    const attempts = Number(attemptCache.get(attemptKey) || 0);
    if (attempts >= 8) throw new Error('Too many tries for this name. Wait one minute, then try again.');
    const found = findStudent_(studentId);
    if (!found || !found.active || !verifyPin_(pin, found.pinHash)) {
      attemptCache.put(attemptKey, String(attempts + 1), 60);
      Utilities.sleep(250);
      throw new Error('The name or PIN is incorrect.');
    }
    attemptCache.remove(attemptKey);
    const token = Utilities.getUuid() + Utilities.getUuid();
    const session = { studentId: found.id, name: found.name, issued: Date.now() };
    CacheService.getScriptCache().put('auth:' + digest_(token), JSON.stringify(session), KQ.SESSION_TTL);
    const progress = loadProgress_(found.id, found.name);
    return { ok: true, token: token, student: { id: found.id, name: found.name }, progress: progress };
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function validateSession(token) {
  try {
    const auth = requireSession_(token);
    return { ok: true, student: { id: auth.studentId, name: auth.name } };
  } catch (err) {
    return { ok: false, error: publicError_(err) };
  }
}

function logout(token) {
  if (token) CacheService.getScriptCache().remove('auth:' + digest_(String(token)));
  return { ok: true };
}

function requireSession_(token) {
  if (!token || typeof token !== 'string' || token.length > 200) throw new Error('Your session expired. Please sign in again.');
  const key = 'auth:' + digest_(token);
  const cache = CacheService.getScriptCache();
  const raw = cache.get(key);
  if (!raw) throw new Error('Your session expired. Please sign in again.');
  const auth = JSON.parse(raw);
  const found = findStudent_(auth.studentId);
  if (!found || !found.active) {
    cache.remove(key);
    throw new Error('Your session is no longer active. Please ask your teacher.');
  }
  cache.put(key, raw, KQ.SESSION_TTL);
  return auth;
}

function findStudent_(studentId) {
  const sheet = getSpreadsheet_().getSheetByName(KQ.STUDENTS);
  if (!sheet || sheet.getLastRow() < 2) return null;
  const finder = sheet.getRange(2, 1, sheet.getLastRow() - 1, 1)
    .createTextFinder(String(studentId)).matchEntireCell(true).findNext();
  if (!finder) return null;
  const r = sheet.getRange(finder.getRow(), 1, 1, 5).getDisplayValues()[0];
  return {
    id: String(r[0]),
    name: `${r[1]}${r[2] ? ' ' + r[2] + '.' : ''}`,
    pinHash: String(r[3]),
    active: String(r[4]).toLowerCase() !== 'false' && r[4] !== '0'
  };
}

function verifyPin_(pin, stored) {
  const parts = String(stored || '').split('$');
  if (parts.length !== 3 || parts[0] !== 'v1') return false;
  return constantTimeEqual_(parts[2], hashPin_(pin, parts[1]));
}

function hashPin_(pin, salt) {
  const pepper = PropertiesService.getScriptProperties().getProperty('PIN_PEPPER');
  if (!pepper) throw new Error('KeyQuest security is not initialized. Run setupKeyQuest().');
  return digest_(salt + ':' + pin + ':' + pepper);
}

function digest_(value) {
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(value), Utilities.Charset.UTF_8);
  return Utilities.base64EncodeWebSafe(bytes).replace(/=+$/, '');
}

function constantTimeEqual_(a, b) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}
