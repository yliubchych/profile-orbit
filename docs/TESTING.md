# Testing and verification

## Test-first workflow

The owner requested five features in sequence, each with failing tests before implementation and passing tests before starting the next. The evidence record is [launcher/tests/TDD.md](../launcher/tests/TDD.md). Regression cases were subsequently expanded during the final audit.

The suite uses Windows PowerShell 5.1 and built-in .NET/Windows Forms. No test framework or package installation is required. Tests use synthetic metadata/account markers and mock application actions. Native integration tests use a synthetic Electron-class window, a mock desktop executable, isolated process workers and an unused hotkey combination; they do not stop or log into real accounts.

## Commands

From the repository root:

- Full suite: `powershell.exe -NoProfile -File .\launcher\tests\Run-Tests.ps1`
- Earlier features only: add `-Through 2`, or another feature number.
- UI render: `powershell.exe -NoProfile -STA -File .\launcher\tests\Render-UI.ps1 -Count 4`.
- Read-only installed-app health: `powershell.exe -NoProfile -File .\launcher\Launcher.ps1 -Profile Check`.
- Build unsigned allowlist ZIP: `powershell.exe -NoProfile -File .\launcher\Build.ps1`.

Run the native tests on an interactive Windows desktop. The agent sandbox rejects global hotkey registration; outside-sandbox execution is required for that test. No keystrokes are sent. Synthetic files are confined to ignored `launcher/tests/.tmp/`.

## Coverage

- Guided profiles: onboarding/editor/card binding, Unicode, persistence, names/colors, stable IDs, legacy folder adoption and corrupt/invalid metadata handling.
- Live state: stopped/open/background/unknown, action routing, RAM gate, duplicate starts across two processes, native hidden/visible/minimized detection, and selected-process identity rechecks before termination.
- Projects: profile binding, valid local folders, URI encoding, missing folders, shortcut removal without data deletion, project-manager UI and actual subprocess argument/environment delivery.
- Release: ZIP allowlist, checksums, installation/update/removal, rollback, account/unknown/edited-file preservation, unsafe manifests and shortcuts, environment sanitation, redacted diagnostic reports and UI export.
- Tray/hotkeys: menu refresh, action routing, close-to-tray versus exit, ordered delayed launch/cancellation, native hotkey conflicts/release/message dispatch, and cross-process single-instance focus signaling.

Additional regression coverage exercises 60-character name boundaries, whitespace/color normalization, invalid stored lists, byte-for-byte preservation after rejected edits, atomic-write cleanup, mutex release after exceptions, missing/corrupt event logs, ordered 50-event retention, event field filtering, diagnostic failure and RAM boundaries, and empty/over-capacity hotkey mappings. These cases run automatically through the existing suite command; no additional dependencies are required.

## Practical limits

Latest regression verification on 2026-10-20: **71 tests passed across 16 suites**, including 13 additional regression tests. The full suite initially passed 70 tests and failed the existing native hotkey-registration test in the sandbox; rerunning `Feature5.UI.Tests.ps1` outside the sandbox passed all seven of its tests. This is behavioral regression coverage, not a measured line/branch coverage percentage.

The earlier 58-test release gate also inspected the source-only ZIP and hash-matched it to source; the existing desktop copy was backed up, updated and hash-matched. A second real launcher invocation handed focus to the first while existing account processes and profile IDs remained unchanged. See [TDD.md](../launcher/tests/TDD.md). Those installed-copy checks were not repeated for the test-only expansion.

The pre-feature baseline was hash-checked against the owner's installed scripts. Earlier local tests and owner feedback confirmed background reopening and repeated focus behavior. The current suite does not log into accounts or submit prompts. A documented workspace URI plus tested dispatch does not prove every future desktop version will honor navigation. No independent tester machine, enterprise policy, large profile count, high-DPI matrix, signed installer or commercial demand has been validated. These are beta limitations, not passing test claims.
