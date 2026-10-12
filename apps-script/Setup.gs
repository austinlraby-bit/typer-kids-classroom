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
  const sessions = setupSheet_(ss, KQ.SESSIONS, ['Session ID', 'Student ID', 'Date', 'Active Seconds', 'Activity']);
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
    .addItem('Refresh weekly summary', 'createWeeklySummary_')
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
  summary.clear();
  if (summary.getMaxColumns() < 29) summary.insertColumnsAfter(summary.getMaxColumns(), 29 - summary.getMaxColumns());
  summary.getRange('A1').setValue('Student');
  summary.getRange('B1').setFormula('=TODAY()-WEEKDAY(TODAY(),2)+1-7*7');
  summary.getRange('C1').setFormula('=B1+7');
  summary.getRange('B1:C1').autoFill(summary.getRange('B1:AB1'), SpreadsheetApp.AutoFillSeries.DEFAULT_SERIES);
  summary.getRange('B1:AB1').setNumberFormat('mmm d')
    .setHorizontalAlignment('center');
  summary.getRange('A2').setFormula('=SORT(FILTER(Students!B2:B&IF(Students!C2:C<>""," "&Students!C2:C&".",""),Students!A2:A<>"",Students!E2:E<>FALSE))');
  summary.getRange('AC1').setValue('Student ID');
  summary.getRange('AC2').setFormula('=SORT(FILTER(Students!A2:A,Students!A2:A<>"",Students!E2:E<>FALSE),FILTER(Students!B2:B&IF(Students!C2:C<>""," "&Students!C2:C&".",""),Students!A2:A<>"",Students!E2:E<>FALSE),TRUE)');
  summary.getRange('B2').setFormula('=IF($A2="","",IFERROR(ROUND(SUMIFS(Sessions!$D:$D,Sessions!$B:$B,$AC2,Sessions!$C:$C,">="&B$1,Sessions!$C:$C,"<"&B$1+7)/60,1),0))');
  summary.getRange('B2').autoFill(summary.getRange('B2:AB2'), SpreadsheetApp.AutoFillSeries.DEFAULT_SERIES);
  summary.getRange('B2:AB2').autoFill(summary.getRange('B2:AB200'), SpreadsheetApp.AutoFillSeries.DEFAULT_SERIES);
  const goal = weeklyGoal_();
  const rule = SpreadsheetApp.newConditionalFormatRule().whenNumberGreaterThanOrEqualTo(goal)
    .setBackground('#d9ead3').setFontColor('#274e13').setRanges([summary.getRange('B2:AB200')]).build();
  summary.setConditionalFormatRules([rule]);
  summary.setFrozenRows(1); summary.setFrozenColumns(1);
  summary.hideColumns(29);
  summary.getRange('A1:AB1').setFontWeight('bold').setBackground('#4f6df5').setFontColor('#ffffff');
  summary.autoResizeColumns(1, 28);
}

function weeklyGoal_() {
  const sh = getSpreadsheet_().getSheetByName(KQ.SETTINGS);
  if (!sh || sh.getLastRow() < 2) return KQ.DEFAULT_GOAL_MINUTES;
  const values = sh.getRange(2, 1, sh.getLastRow() - 1, 2).getValues();
  const row = values.find(r => r[0] === 'Weekly goal (minutes)');
  return row ? Number(row[1]) || KQ.DEFAULT_GOAL_MINUTES : KQ.DEFAULT_GOAL_MINUTES;
}
