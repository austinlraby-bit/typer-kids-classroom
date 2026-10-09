/**
 * Typer Kids Classroom — Google Apps Script bridge.
 * The classroom shell is a derivative of Typer Kids (GPL-3.0).
 */

const KQ = Object.freeze({
  STUDENTS: 'Students',
  PROGRESS: 'Progress',
  SESSIONS: 'Sessions',
  SUMMARY: 'Weekly Summary',
  SETTINGS: 'Settings',
  SESSION_TTL: 21600,
  // Google Sheets cells accept at most 50,000 characters.
  MAX_PROGRESS_BYTES: 45000,
  LOCK_WAIT_MS: 20000,
  DEFAULT_GOAL_MINUTES: 30
});

function doGet() {
  return HtmlService.createTemplateFromFile('Index').evaluate()
    .setTitle('Typer Kids Classroom')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DEFAULT)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1, viewport-fit=cover');
}

function getTyperKidsUrl() {
  return PropertiesService.getScriptProperties().getProperty('TYPER_KIDS_URL') || '';
}

function setTyperKidsUrl(url) {
  url = String(url || '').trim().replace(/\/$/, '');
  if (!/^https:\/\//.test(url)) throw new Error('Use the full https:// address for the Typer Kids site.');
  PropertiesService.getScriptProperties().setProperty('TYPER_KIDS_URL', url);
  return url;
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

function logDataSpreadsheetUrl() {
  console.log(getSpreadsheet_().getUrl());
}

function getSpreadsheet_() {
  const id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('KeyQuest is not set up. Run setupKeyQuest() from the Apps Script editor.');
  return SpreadsheetApp.openById(id);
}

function publicError_(err) {
  console.error(err && err.stack ? err.stack : err);
  const message = err && err.message ? err.message : String(err);
  if (/not set up|temporarily busy|session expired|invalid|sign in|incorrect|four|too many|ask your teacher|no longer active|not found|already set|not active/i.test(message)) return message;
  return 'KeyQuest could not complete that request. Please try again.';
}
