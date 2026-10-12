# Typer Kids Classroom

This project adapts [Typer Kids](https://github.com/lohanidamodar/typer_kids) for a teacher-managed classroom.

## What changed

- Students enter a shared six-digit classroom code before the roster is revealed, then use their personal four-digit PIN.
- First-time students create and confirm their own PIN.
- The built-in local profile picker is bypassed in classroom mode.
- Lesson progress, arcade scores, streaks, and difficult-key data sync to the teacher's Google Sheet.
- Active typing time is recorded through the Apps Script classroom bridge.
- Progress is stored in a compact format so the complete curriculum fits within Google Sheets limits.

## Hosting

The compiled Flutter site belongs on a static HTTPS host such as GitHub Pages. The files in `apps-script/` form the Google Apps Script shell and backend. Set the Apps Script `TYPER_KIDS_URL` property by running `setTyperKidsUrl('https://your-static-site.example')` before deploying the web app.

Run `configureClassroomCode()` once from the Apps Script editor to generate a new classroom code. The code appears in the execution log; share it only with students and caregivers who should have access. Running it again immediately replaces the old classroom code.

## License

Typer Kids is licensed under GPL-3.0. This derivative remains under the same license; see `LICENSE`.
