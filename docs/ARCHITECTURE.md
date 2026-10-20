# Architecture

## Components

- `launcher/Launcher.ps1`: entry point, data-root selection, read-only health mode, and single-instance UI session.
- `launcher/Core.ps1`: validated local profile/project metadata, atomic writes, named locks, bounded redacted events, diagnostic model and singleton/hotkey definitions.
- `launcher/Windows.ps1`: installed app discovery, exact profile process matching, native visible-window enumeration/activation, sanitized process environment, profile start/stop/project dispatch and native hotkey window.
- `launcher/UI.ps1`: Windows Forms cards, profile editor, project manager, diagnostics preview/export, live refresh, delayed launch queue, tray and hotkey event routing.
- `launcher/Release.ps1`, `Install.ps1`, `Uninstall.ps1`, `Build.ps1`: explicit release allowlist, checksums, installation/rollback, conservative removal and owned-shortcut management.
- `launcher/tests/`: dependency-free PowerShell tests and synthetic native/process/UI checks. These files are not distributed.

## Data boundaries

Profiles live under the selected data root, by default `profiles/` beside the launcher. Names and colors are metadata; immutable folder IDs preserve account state when renamed. Legacy PBX/Personal folders are adopted in place. Each profile has its own `CODEX_HOME` and Electron data folder. Account state is neither copied into source nor migrated implicitly.

New process environments discard inherited CODEX_/OPENAI_ context and then set only the selected profile's home/data paths. Project links use the documented URI-encoded workspace path and are sent directly to that executable/data-root pair, never through the shared OS URL handler. No prompt is submitted automatically and no project trust setting is changed.

Named profile locks serialize start/stop operations. A per-data-root UI mutex and focus event keep one new launcher instance per root. Closing to the tray leaves that instance and its shortcuts running. Session exit releases only launcher resources.

Data folders are not an OS security boundary. Runtime files may contain credentials and private content and are excluded from both Git and the ZIP's explicit allowlist. Diagnostics contain a whitelist of health facts and sanitized event codes, not arbitrary exception text or local account/project paths.

## Distribution

Install copies only managed files, verifies a supplied package manifest, preserves runtime/unknown files, rolls back failed updates, and refuses unmanaged collisions or edited application scripts. Uninstall validates its manifest and deletes only unchanged allowlisted files; it never recursively removes the installation or profile folders. Package checksums are integrity checks, not digital signatures.

No external backend, advertising, analytics, billing, extra runtime dependency or framework migration is included.
