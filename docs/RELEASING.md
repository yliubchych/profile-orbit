# Launcher releases and updates

## User flow

Installed beta.4 and newer launchers expose **Updates** in the main window and **Check for updates...** in the tray. Checking and downloading run in a background PowerShell runspace. Users choose **Install and restart**; there is no scheduled polling or silent installation. Earlier versions require a one-time manual install to obtain the updater.

The fixed source is the public repository [yliubchych/profile-orbit](https://github.com/yliubchych/profile-orbit). Its visibility was verified as public on 2026-10-21 following the owner's instruction. No token or profile-data transfer is needed. The client lists up to 300 releases, selects the highest newer compatible semantic version, and ignores drafts. Beta versions accept beta/stable releases; stable versions accept stable releases only.

## Preparing a release

1. Update `launcher/VERSION` and the user guide version. Tags must equal that version, optionally prefixed with `v`.
2. Run the regression commands in [testing](TESTING.md). Native hotkey and registry tests need the interactive desktop outside the sandbox.
3. Run `powershell.exe -NoProfile -File .\launcher\Build.ps1` from the repository root. If an archive exists, use a fresh `-Output` directory; the builder refuses to overwrite it.
4. Inspect the ZIP: only `Get-LauncherReleaseFiles` entries plus `package-manifest.json` belong in it. Never upload runtime profiles, installed directories, tests, or a source-code ZIP as an update.
5. After owner authorization to commit/push and publish, publish a GitHub Release at the tested commit/tag. Attach the exact built `ProfileLauncher-<version>.zip`. Mark versions with a prerelease suffix as prereleases. GitHub must report the asset's `sha256:` digest and `uploaded` state before it becomes eligible.
6. Verify an unauthenticated check and download from the published asset. Keep synthetic install/restart checks separate from a live installed-copy acceptance test.

Source pushes or Git tags alone do not distribute updates. GitHub's automatically generated source archives are not launcher packages. Release publishing is not automated by a workflow in this repository.

## Verified beta.5 deployment — 2026-10-22

- Published [v0.1.0-beta.5](https://github.com/yliubchych/profile-orbit/releases/tag/v0.1.0-beta.5) from commit `f02efab`, with the prerelease flag and the allowlisted ZIP. GitHub reported the uploaded asset digest `sha256:6a63ec1db0d183d445da4284114de232e88cce041217e3e70bbd022f5ac2b9a8`.
- The production update functions selected and downloaded the release without authentication, validated its archive/manifest, and hash-matched it against the tested local ZIP.
- Backed up only the old managed files, then upgraded the existing desktop installation from beta.1 to beta.5. Every deployed managed file matched the downloaded package; profile metadata/folder names and existing account process identities were unchanged.
- Startup using the existing desktop shortcut target/arguments exited the bootstrap and opened one detached launcher window. A native probe attached to the running launcher's console object and observed `GetConsoleWindow() == 0`, confirming no console window. Installed read-only diagnostics reported beta.5, two profiles and no health errors.

## Installation boundaries

`Updates.ps1` restricts URLs to the fixed repository/tag/name, verifies the archive digest, rejects unexpected/duplicate ZIP entries and excessive expanded sizes, then checks every managed file against the manifest and validates the version. Adding/removing managed filenames in a future release requires an updater compatibility plan.

The installed updater copies its own trusted helper scripts into staging; it does not execute a downloaded installer. The helper waits for the original launcher process identity to exit, serializes updates per installation, revalidates the archive, refuses downgrades or locally edited installations, invokes existing installer rollback, and restarts with the original data root. It strips inherited CODEX_/OPENAI_ environment variables. Codex account processes are not stopped.

Downloads/helpers remain in `%LOCALAPPDATA%\ProfileLauncherUpdates`; users may clear this cache when no update is running. Check/download failures leave the launcher open. Installation failures show an error and attempt to reopen the installed launcher. This unsigned flow depends on trust in GitHub and repository publishing access, not a separately signed publisher identity.
