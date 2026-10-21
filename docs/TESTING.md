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

`Feature6.Registry.Tests.ps1` also needs outside-sandbox execution. Its real registry tests use unique disposable keys under `HKCU\Software\ProfileLauncherTests`, never the actual protocol association. The crash test terminates only its own synthetic PowerShell worker and verifies independent watchdog cleanup. Test registry keys are removed in `finally`.

## Coverage

- Guided profiles: onboarding/editor/card binding, Unicode, persistence, names/colors, stable IDs, legacy folder adoption and corrupt/invalid metadata handling.
- Live state: stopped/open/background/unknown, action routing, RAM gate, duplicate starts across two processes, native hidden/visible/minimized detection, and selected-process identity rechecks before termination.
- Projects: profile binding, valid local folders, URI encoding, missing folders, shortcut removal without data deletion, project-manager UI and actual subprocess argument/environment delivery.
- Release: ZIP allowlist, checksums, installation/update/removal, rollback, account/unknown/edited-file preservation, unsafe manifests and shortcuts, environment sanitation, redacted diagnostic reports and UI export.
- Tray/hotkeys: menu refresh, action routing, close-to-tray versus exit, ordered delayed launch/cancellation, native hotkey conflicts/release/message dispatch, and cross-process single-instance focus signaling.
- Browser returns: opaque URL validation and native argument delivery, explicit account choice/cancellation, process identity rechecks, environment isolation, default-app fallback for normal links, temporary registration restoration, exact existing-stub preservation, concurrent owner edits, setup failure, stale-owner recovery and watchdog cleanup after an actual synthetic process kill.

Additional regression coverage exercises 60-character name boundaries, whitespace/color normalization, invalid stored lists, byte-for-byte preservation after rejected edits, atomic-write cleanup, mutex release after exceptions, missing/corrupt event logs, ordered 50-event retention, event field filtering, diagnostic failure and RAM boundaries, and empty/over-capacity hotkey mappings. These cases run automatically through the existing suite command; no additional dependencies are required.

## Practical limits

Latest regression verification on 2026-10-21: **91 tests passed across 22 suites** in the full outside-sandbox gate. This includes 17 browser-return and Windows-preservation tests and three plugin-entry/UI tests. The plugin buttons were rendered and visually checked, and the source-only beta.3 ZIP was built. This is behavioral regression coverage, not a measured line/branch coverage percentage.

The real Windows association and Shell-delivery probes did not activate the temporary handler; both rolled back. A final read-only check confirmed the real `HKCU\Software\Classes\codex` retained exactly its original two string values (`URL:codex` and the empty `URL Protocol`) and no subkeys. Tests cover registry restoration, including independent watchdog cleanup after a synthetic launcher process kill; a real OS reboot was not performed. Volatile key shutdown behavior relies on Windows' registry contract. No real plugin authorization, credential transfer, or installed-launcher update was performed. See [known issues](KNOWN_ISSUES.md).

On 2026-10-21 a unique disposable URL protocol delivered to a synthetic handler and was removed afterward, while existing protocol associations were left untouched. After the owner rejected manual user steps, startup routing and its picker notice were disabled and callback/watchdog entry points were excluded from packaging. The 13-test release/install suite passed after these changes. The earlier 88-test gate covers the inactive prototype; it is not evidence of an automatic live authorization fix.

The earlier 58-test release gate also inspected the source-only ZIP and hash-matched it to source; the existing desktop copy was backed up, updated and hash-matched. A second real launcher invocation handed focus to the first while existing account processes and profile IDs remained unchanged. See [TDD.md](../launcher/tests/TDD.md). Those installed-copy checks were not repeated for the test-only expansion.

On 2026-10-21 GitHub became available in the active isolated-profile chat. Plugin management reported installed/enabled, and an authenticated read-only GitHub login request succeeded. This verifies current tool availability here; the completed authorization path was not observed, so it does not prove the candidate launcher entry point caused the connection or works across profiles/providers.

The pre-feature baseline was hash-checked against the owner's installed scripts. Earlier local tests and owner feedback confirmed background reopening and repeated focus behavior. The current suite does not log into accounts or submit prompts. A documented workspace URI plus tested dispatch does not prove every future desktop version will honor navigation. No independent tester machine, enterprise policy, large profile count, high-DPI matrix, signed installer or commercial demand has been validated. These are beta limitations, not passing test claims.
