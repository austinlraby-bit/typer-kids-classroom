const POKEMON_REGIONS_ = ['Kanto', 'Johto', 'Hoenn', 'Sinnoh', 'Unova', 'Kalos', 'Alola', 'Galar', 'Paldea'];
const POKEMON_RANGES_ = [[1,151],[152,251],[252,386],[387,493],[494,649],[650,721],[722,809],[810,905],[906,1025]];
const POKEMON_SPECIAL_ = [144,145,146,150,151,243,244,245,249,250,251,377,378,379,380,381,382,383,384,385,386,480,481,482,483,484,485,486,487,488,489,490,491,492,493,494,638,639,640,641,642,643,644,645,646,647,648,649,716,717,718,719,720,721,772,773,785,786,787,788,789,790,791,792,793,794,795,796,797,798,799,800,801,802,807,808,809,888,889,890,891,892,893,894,895,896,897,898,905,1001,1002,1003,1004,1007,1008,1009,1010,1014,1015,1016,1017,1024,1025];

function loadPokemonState_(studentId) {
  const sheet = getSpreadsheet_().getSheetByName(KQ.POKEMON);
  if (!sheet) return freshPokemonState_(studentId);
  const row = findRow_(sheet, 1, studentId);
  if (!row) return freshPokemonState_(studentId);
  return parsePokemonRow_(sheet.getRange(row, 1, 1, 9).getValues()[0]);
}

function freshPokemonState_(studentId) {
  return {studentId: studentId, caught: {}, selectedRegion: 0, companionId: 0,
    practiceSeconds: 0, unclaimedEncounters: 0, transactions: [], accuracyRecords: {},
    thresholds: regionThresholds_(), practiceMinutes: practiceMinutes_()};
}

function parsePokemonRow_(r) {
  function json(value, fallback) { try { return JSON.parse(value || ''); } catch (_) { return fallback; } }
  return {studentId: String(r[0]), caught: json(r[1], {}), selectedRegion: Number(r[2]) || 0,
    companionId: Number(r[3]) || 0, practiceSeconds: Number(r[4]) || 0,
    unclaimedEncounters: Number(r[5]) || 0, transactions: json(r[6], []),
    accuracyRecords: json(r[7], {}), thresholds: regionThresholds_(), practiceMinutes: practiceMinutes_()};
}

function savePokemonState_(state) {
  const sheet = getSpreadsheet_().getSheetByName(KQ.POKEMON);
  if (!sheet) throw new Error('Pokémon rewards are not set up. Ask your teacher to run setup.');
  const values = [state.studentId, JSON.stringify(state.caught), state.selectedRegion,
    state.companionId, Math.floor(state.practiceSeconds), Math.floor(state.unclaimedEncounters),
    JSON.stringify((state.transactions || []).slice(-600)), JSON.stringify(state.accuracyRecords || {}), new Date()];
  const row = findRow_(sheet, 1, state.studentId);
  if (row) sheet.getRange(row, 1, 1, values.length).setValues([values]); else sheet.appendRow(values);
}

function creditPokemonPractice_(studentId, seconds) {
  if (seconds <= 0) return;
  const state = loadPokemonState_(studentId);
  const threshold = practiceMinutes_() * 60;
  state.practiceSeconds += Math.min(90, Math.floor(seconds));
  while (state.practiceSeconds >= threshold) {
    state.practiceSeconds -= threshold;
    state.unclaimedEncounters++;
  }
  savePokemonState_(state);
}

function claimPokemon(token, request) {
  try {
    const auth = requireSession_(token);
    request = request || {};
    const source = String(request.source || '');
    const eventId = validateId_(request.eventId, 'reward');
    const lock = LockService.getScriptLock(); lock.waitLock(KQ.LOCK_WAIT_MS);
    try {
      const state = loadPokemonState_(auth.studentId);
      if (state.transactions.indexOf(eventId) !== -1) return {ok:true, duplicate:true, pokemon:state};
      const progress = loadProgress_(auth.studentId, auth.name);
      const completed = completedLessonIds_(progress);
      let special = false;
      if (source === 'lesson') {
        const lessonId = String(request.lessonId || '');
        if (completed.indexOf(lessonId) === -1 || eventId !== 'lesson_' + safeEventPart_(lessonId)) throw new Error('Finish this lesson successfully before catching a Pokémon.');
        const lessonRow = progress.profile.typerKids && progress.profile.typerKids.progress && progress.profile.typerKids.progress[lessonId];
        state.accuracyRecords[lessonId] = Math.floor(Number(lessonRow && lessonRow.a) || 0);
      } else if (source === 'practice') {
        if (state.unclaimedEncounters < 1) throw new Error('Keep practicing to earn your next encounter.');
        state.unclaimedEncounters--;
      } else if (source === 'unit') {
        const unit = Math.max(1, Math.floor(Number(request.unit) || 0));
        if (completed.length < unit * 10 || eventId !== 'unit_reward_' + unit) throw new Error('Complete this lesson unit first.');
        special = unit % 3 === 0;
      } else if (source === 'accuracy') {
        const lessonId = String(request.lessonId || '');
        const row = progress.profile.typerKids && progress.profile.typerKids.progress && progress.profile.typerKids.progress[lessonId];
        const accuracy = Math.floor(Number(row && row.a) || 0);
        const prior = Math.floor(Number(state.accuracyRecords[lessonId]) || 0);
        if (accuracy < 80 || accuracy < prior + 3) throw new Error('Beat your accuracy record by at least 3 points to earn this encounter.');
        state.accuracyRecords[lessonId] = accuracy;
      } else throw new Error('That reward type is not valid.');

      const unlocked = unlockedRegionCount_(completed.length);
      state.selectedRegion = Math.max(0, Math.min(unlocked - 1, Number(state.selectedRegion) || 0));
      const pokemonId = choosePokemon_(state, special, eventId);
      if (!pokemonId) throw new Error('This region is complete. Choose another unlocked region.');
      state.caught[String(pokemonId)] = Math.floor(Date.now() / 1000);
      if (!state.companionId) state.companionId = pokemonId;
      state.transactions.push(eventId);
      savePokemonState_(state);
      return {ok:true, caughtId:pokemonId, pokemon:state};
    } finally { lock.releaseLock(); }
  } catch (err) { return {ok:false, error:publicError_(err)}; }
}

function updatePokemonPreferences(token, request) {
  try {
    const auth = requireSession_(token), lock = LockService.getScriptLock(); lock.waitLock(KQ.LOCK_WAIT_MS);
    try {
      const state = loadPokemonState_(auth.studentId);
      const completed = completedLessonIds_(loadProgress_(auth.studentId, auth.name)).length;
      if (request && request.selectedRegion != null) {
        const region = Math.floor(Number(request.selectedRegion));
        if (region < 0 || region >= unlockedRegionCount_(completed)) throw new Error('That region is still locked.');
        state.selectedRegion = region;
      }
      if (request && request.companionId != null) {
        const id = Math.floor(Number(request.companionId));
        if (!state.caught[String(id)]) throw new Error('Catch that Pokémon before choosing it as a companion.');
        state.companionId = id;
      }
      savePokemonState_(state); return {ok:true, pokemon:state};
    } finally { lock.releaseLock(); }
  } catch (err) { return {ok:false, error:publicError_(err)}; }
}

function choosePokemon_(state, special, seed) {
  const range = POKEMON_RANGES_[state.selectedRegion] || POKEMON_RANGES_[0];
  let ids = [];
  for (let id=range[0]; id<=range[1]; id++) {
    if (!state.caught[String(id)] && (special || POKEMON_SPECIAL_.indexOf(id) === -1)) ids.push(id);
  }
  if (!ids.length && !special) {
    for (let id=range[0]; id<=range[1]; id++) if (!state.caught[String(id)]) ids.push(id);
  }
  if (!ids.length) return 0;
  const hash = digest_(state.studentId + ':' + seed);
  let n = 0; for (let i=0; i<8; i++) n = (n * 37 + hash.charCodeAt(i)) >>> 0;
  return ids[n % ids.length];
}
function completedLessonIds_(progress) {
  const rows = progress.profile.typerKids && progress.profile.typerKids.progress || {};
  return Object.keys(rows).filter(id => rows[id] && rows[id].c === true);
}
function unlockedRegionCount_(completed) {
  const t = regionThresholds_(); let n=1; for (let i=1;i<t.length;i++) if (completed>=t[i]) n=i+1; return n;
}
function safeEventPart_(value) { return String(value).replace(/[^A-Za-z0-9_-]/g, '_').slice(0,80); }
function practiceMinutes_() { return Math.max(1, Math.min(120, Number(settingValue_('Pokémon encounter (minutes)')) || KQ.DEFAULT_PRACTICE_MINUTES)); }
function regionThresholds_() {
  const raw = String(settingValue_('Region thresholds') || '0,15,35,60,90,120,150,185,220');
  const values = raw.split(',').map(Number); return values.length===9 && values.every(n=>isFinite(n)) ? values : [0,15,35,60,90,120,150,185,220];
}
function settingValue_(name) {
  const sh=getSpreadsheet_().getSheetByName(KQ.SETTINGS); if(!sh||sh.getLastRow()<2)return '';
  const rows=sh.getRange(2,1,sh.getLastRow()-1,2).getValues(); const row=rows.find(r=>r[0]===name); return row?row[1]:'';
}
