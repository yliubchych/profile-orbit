# Feature verification record

Tests use Windows PowerShell 5.1 and built-in .NET/Windows Forms, with synthetic metadata and mocked process actions. No account data is read by these tests.

## 1. Guided profiles

- Before implementation: 8 metadata tests failed because profile commands did not exist; 4 UI tests failed because editor/card commands did not exist.
- After implementation: 8 metadata tests and 4 UI tests passed. Covers clean onboarding, add/rename/color persistence, Unicode, stable account folder identity, duplicate/invalid input, legacy folder adoption, corrupt metadata preservation, schema/traversal validation, editor save and card binding.
- Existing launch/window logic moved to Windows.ps1; UI and metadata are separate files. Legacy PBX/Personal folders are adopted in place only when present. No account state was copied.

## 2. Live status and smart actions

- Before implementation: 7 state/action tests and 1 UI refresh test failed; state/refresh functions were absent. Added a separate cross-process race regression before feature verification.
- After implementation: 8 state/action tests and 1 UI test passed; all 12 feature-1 tests also passed.
- Verified Stopped/Launch, Open/Focus, Background/Reopen and Unknown/Unavailable. Access errors and ambiguous process identity are not reported as stopped. Cold starts honor the RAM gate, existing processes bypass it, and a named mutex serializes two independent launchers into one synthetic app start.

## 3. Profile-bound project shortcuts

- Before implementation: 6 project tests and 1 UI test failed because shortcut commands were absent.
- After implementation: all 7 passed; all feature-1/2 tests remained green (28 cases total).
- The official [commands reference](https://learn.chatgpt.com/docs/reference/commands) documents `codex://threads/new?path=<absolute-path>`. The launcher URI-encodes an existing local directory and delivers it as an argument to the selected profile executable/data-root pair, not the shared OS URL handler. It does not submit a prompt or change project trust settings.
- Tests verify per-profile persistence, rename preservation, missing/file/relative/duplicate path rejection, URI encoding, selected-profile dispatch, removal without deleting folders, and project-manager/card binding. Actual signed-in app navigation still needs a live acceptance check; mocked dispatch alone does not prove the installed version honored the link.

## 4. Installation and diagnostics

- Before implementation: 8 release/diagnostic tests failed (one missing-source test initially accepted a missing-command exception; its expected error was tightened), plus 1 diagnostics UI test failed.
- After implementation and added rollback/tampered-log regressions: 12 release/diagnostic tests and 1 UI test passed; features 1–3 remained green (41 cases total).
- Tests inspect the ZIP allowlist, exercise install/update/uninstall without shortcuts in synthetic directories, preserve account/unknown/edited files, reject unmanaged collisions and manifest traversal, and force a mid-update source read failure to verify rollback. Diagnostics are constructed from whitelisted fields; tests check names, paths, API secrets and injected log fields do not appear.
- Distribution is an unsigned local beta. No signing certificate, paid update service, external analytics or payment integration was purchased or added.

## 5. Tray, hotkeys and a single launcher instance

- Before implementation: 2 singleton/key-definition tests and 3 tray/routing UI tests failed because the feature functions were absent.
- After implementation: both core tests and all 7 expanded UI/native tests passed. Two separate processes verified focus-event handoff and session release; a UI timer test verified that the signal restores a hidden launcher. Native tests verified registration conflict detection, unregister cleanup and message dispatch through the production event handler. No real keyboard event was generated.
- The native registration test failed inside the restricted sandbox and passed on the interactive desktop outside it. This environment restriction is documented in the test instructions; it is not silently skipped.

## Final audit regressions

- Added native hidden/visible/minimized window enumeration and actual mock-executable URI/environment delivery checks.
- Added test-first regressions for inherited CODEX_PROFILE/CODEX_API_KEY sanitation, full-close process identity, reopen versus repeated focus, replacement-process rejection and idempotent shortcut ownership. Each was run failing before its implementation/refactor and passing afterwards.
- Rendered empty, two-profile and four-profile layouts and inspected them. Checked control bounds and that scrolling preserves two columns. No high-DPI or independent-machine coverage is claimed.

## Final gate and local deployment — 2026-10-20

- Full `Run-Tests.ps1` run: **58 passed, 0 failed**, across 14 suites, on Windows PowerShell with native checks outside the agent sandbox.
- Built `dist/ProfileLauncher-0.1.0-beta.1.zip`. Inspected all 12 entries (11 managed files plus package manifest), and verified every archived source hash against the tested repository files. No runtime profiles or tests are included.
- Updated the existing desktop installation after backing up its managed files. Existing profile IDs and account process identities/counts were unchanged. Only legacy launcher forms were asked to close; no Codex account process was stopped.
- Verified one updated launcher window and successful duplicate-process handoff. Every deployed managed file matches the tested source. Installed read-only diagnostics detected app version 26.1013.4894.0, two profiles, and no health errors.
- The beta remains unsigned. Independent-machine and signed-in project-navigation acceptance across desktop versions remain outside the automated results above.
