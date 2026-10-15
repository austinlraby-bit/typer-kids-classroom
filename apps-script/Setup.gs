function setupKeyQuest() {
  const active = SpreadsheetApp.getActiveSpreadsheet();
  const ss = active || SpreadsheetApp.create('KeyQuest Classroom Data');
  PropertiesService.getScriptProperties().setProperty('SPREADSHEET_ID', ss.getId());
  if (!PropertiesService.getScriptProperties().getProperty('PIN_PEPPER')) {
    PropertiesService.getScriptProperties().setProperty('PIN_PEPPER', Utilities.getUuid() + Utilities.getUuid());
  }
  if (!PropertiesService.getScriptProperties().getProperty('CLASS_CODE_HASH')) {
    configureClassroomCode();
  }
  setupSheet_(ss, KQ.STUDENTS, ['Student ID', 'First Name', 'Last Initial', 'PIN', 'Active']);
  setupSheet_(ss, KQ.PROGRESS, ['Student ID', 'Current Lesson', 'Completed Lessons', 'Best WPM', 'Accuracy', 'Progress Data']);
  const sessions = setupSheet_(ss, KQ.SESSIONS, ['Session ID', 'Student ID', 'Date', 'Active Seconds', 'Activity', 'Last Server Update', 'Last Reported Seconds']);
  sessions.getRange('C:C').setNumberFormat('yyyy-mm-dd hh:mm');
  const summary = setupSheet_(ss, KQ.SUMMARY, ['Student']);
  const settings = setupSheet_(ss, KQ.SETTINGS, ['Setting', 'Value']);
  if (settings.getLastRow() < 2) settings.getRange(2, 1, 2, 2).setValues([
    ['Weekly goal (minutes)', KQ.DEFAULT_GOAL_MINUTES],
    ['Week starts', 'Monday']
  ]);
  if (!settingExists_(settings, 'Pokémon encounter (minutes)')) {
    settings.appendRow(['Pokémon encounter (minutes)', KQ.DEFAULT_PRACTICE_MINUTES]);
  }
  if (!settingExists_(settings, 'Region thresholds')) {
    settings.appendRow(['Region thresholds', '0,15,35,60,90,120,150,185,220']);
  }
  setupSheet_(ss, KQ.POKEMON, [
    'Student ID', 'Caught JSON', 'Selected Region', 'Companion ID',
    'Practice Seconds', 'Unclaimed Encounters', 'Transactions JSON',
    'Accuracy Records JSON', 'Updated At'
  ]);
  createWeeklySummary_();
  [KQ.STUDENTS, KQ.PROGRESS, KQ.SESSIONS, KQ.SUMMARY, KQ.SETTINGS, KQ.POKEMON].forEach(name => {
    const sh = ss.getSheetByName(name);
    sh.setFrozenRows(1);
    sh.getRange(1, 1, 1, sh.getLastColumn()).setFontWeight('bold').setBackground('#4f6df5').setFontColor('#ffffff');
    sh.autoResizeColumns(1, sh.getLastColumn());
  });
  return 'KeyQuest is ready: ' + ss.getUrl();
}

function settingExists_(sheet, name) {
  if (!sheet || sheet.getLastRow() < 2) return false;
  return !!sheet.getRange(2, 1, sheet.getLastRow() - 1, 1)
    .createTextFinder(name).matchEntireCell(true).findNext();
}

function setupSheet_(ss, name, headers) {
  let sheet = ss.getSheetByName(name);
  if (!sheet) sheet = ss.insertSheet(name);
  if (sheet.getMaxColumns() < headers.length) sheet.insertColumnsAfter(sheet.getMaxColumns(), headers.length - sheet.getMaxColumns());
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  return sheet;
}

function onOpen() {
  SpreadsheetApp.getUi().createMenu('KeyQuest')
    .addItem('Set up / repair sheets', 'setupKeyQuest')
    .addItem('Hash new or changed PINs', 'hashStudentPins')
    .addItem('Refresh weekly summary', 'refreshWeeklySummary')
    .addItem('Reset selected student progress', 'resetSelectedStudentProgress')
    .addToUi();
}

function hashStudentPins() {
  const sheet = getSpreadsheet_().getSheetByName(KQ.STUDENTS);
  if (!sheet || sheet.getLastRow() < 2) return 'No students found.';
  const range = sheet.getRange(2, 1, sheet.getLastRow() - 1, 5);
  const values = range.getDisplayValues();
  let changed = 0;
  values.forEach((r, i) => {
    if (!r[0]) { r[0] = 'stu_' + Utilities.getUuid().replace(/-/g, '').slice(0, 16); changed++; }
    const pin = String(r[3] || '');
    if (/^\d{4}$/.test(pin)) {
      const salt = Utilities.getUuid().replace(/-/g, '');
      r[3] = 'v1$' + salt + '$' + hashPin_(pin, salt);
      changed++;
    }
    if (!r[4]) r[4] = 'TRUE';
  });
  range.setValues(values);
  sheet.getRange(2, 4, values.length, 1).setNumberFormat('@');
  return changed + ' student record(s) updated. Plaintext PINs were replaced with salted hashes.';
}

function resetSelectedStudentProgress() {
  const ss = getSpreadsheet_();
  const activeSheet = ss.getActiveSheet();
  if (activeSheet.getName() !== KQ.STUDENTS || activeSheet.getActiveRange().getRow() < 2) {
    throw new Error('Select a student row on the Students sheet first.');
  }
  const studentId = String(activeSheet.getRange(activeSheet.getActiveRange().getRow(), 1).getDisplayValue());
  const progress = ss.getSheetByName(KQ.PROGRESS);
  const row = progressRow_(progress, studentId);
  if (row) progress.deleteRow(row);
  return 'Progress reset for student ID ' + studentId;
}

function createWeeklySummary_() {
  const ss = getSpreadsheet_();
  const summary = ss.getSheetByName(KQ.SUMMARY);
  const students = ss.getSheetByName(KQ.STUDENTS);
  summary.clear();
  const goal = weeklyGoal_();
  const roster = students && students.getLastRow() >= 2
    ? students.getRange(2, 1, students.getLastRow() - 1, 5).getDisplayValues()
      .filter(r => r[0] && String(r[4]).toLowerCase() !== 'false' && r[4] !== '0')
      .map(r => ({ id: String(r[0]), name: `${r[1]}${r[2] ? ' ' + r[2] + '.' : ''}` }))
      .sort((a, b) => a.name.localeCompare(b.name))
    : [];

  const headers = ['Student', 'This Week', 'Goal', 'Status', 'Last Week', '2 Weeks Ago', '3 Weeks Ago', '4 Weeks Ago', 'Student ID'];
  summary.getRange(1, 1, 1, headers.length).setValues([headers]);
  if (roster.length) {
    summary.getRange(2, 1, roster.length, 1).setValues(roster.map(r => [r.name]));
    summary.getRange(2, 9, roster.length, 1).setValues(roster.map(r => [r.id]));
    summary.getRange(2, 3, roster.length, 1).setValues(roster.map(() => [goal]));

    const weekColumns = [2, 5, 6, 7, 8];
    weekColumns.forEach((column, weekIndex) => {
      const offset = weekIndex * 7;
      const start = `TODAY()-WEEKDAY(TODAY(),2)+1-${offset}`;
      const formulas = roster.map((_, i) => {
        const row = i + 2;
        return [`=IFERROR(ROUND(SUMIFS(Sessions!$D:$D,Sessions!$B:$B,$I${row},Sessions!$C:$C,">="&(${start}),Sessions!$C:$C,"<"&(${start})+7)/60,1),0)`];
      });
      summary.getRange(2, column, roster.length, 1).setFormulas(formulas);
    });

    summary.getRange(2, 4, roster.length, 1).setFormulas(roster.map((_, i) => {
      const row = i + 2;
      return [`=IF(B${row}>=C${row},"Goal met ✓",IF(B${row}=0,"Not started",ROUND(C${row}-B${row},1)&" min to go"))`];
    }));
    summary.getRange(2, 2, roster.length, 7).setVerticalAlignment('middle');
    summary.getRange(2, 2, roster.length, 1).setFontWeight('bold');
  }

  const lastRow = Math.max(2, roster.length + 1);
  const metGoal = SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=$B2>=$C2')
    .setBackground('#d9ead3').setFontColor('#274e13')
    .setRanges([summary.getRange(2, 2, lastRow - 1, 3)]).build();
  const active = SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=AND($B2>0,$B2<$C2)')
    .setBackground('#fff2cc').setFontColor('#7f6000')
    .setRanges([summary.getRange(2, 2, lastRow - 1, 3)]).build();
  summary.setConditionalFormatRules([metGoal, active]);
  summary.setFrozenRows(1);
  summary.setFrozenColumns(1);
  summary.hideColumns(9);
  summary.getRange(1, 1, 1, 8).setFontWeight('bold').setBackground('#4f6df5')
    .setFontColor('#ffffff').setHorizontalAlignment('center');
  summary.getRange(1, 1).setHorizontalAlignment('left');
  summary.setColumnWidth(1, 170);
  summary.setColumnWidth(2, 95);
  summary.setColumnWidth(3, 75);
  summary.setColumnWidth(4, 115);
  summary.setColumnWidths(5, 4, 100);
  summary.getRange(1, 1, lastRow, 8).setWrap(false);
}

function refreshWeeklySummary() {
  createWeeklySummary_();
  return 'Weekly Summary refreshed.';
}

function weeklyGoal_() {
  const sh = getSpreadsheet_().getSheetByName(KQ.SETTINGS);
  if (!sh || sh.getLastRow() < 2) return KQ.DEFAULT_GOAL_MINUTES;
  const values = sh.getRange(2, 1, sh.getLastRow() - 1, 2).getValues();
  const row = values.find(r => r[0] === 'Weekly goal (minutes)');
  return row ? Number(row[1]) || KQ.DEFAULT_GOAL_MINUTES : KQ.DEFAULT_GOAL_MINUTES;
}
