# Profile Launcher — Windows beta

A local utility for separate Codex desktop accounts and project shortcuts. Independent of OpenAI; requires the official desktop app installed separately. Version: 0.1.0-beta.1. No ads, analytics, account sharing, cloud sync or payments are included.

## Install and update

Extract the complete release ZIP, then double-click `Install.cmd`. The per-user default is `%LOCALAPPDATA%\ProfileLauncher`; no administrator installation or dependency download is needed. Installation creates a **Profile Launcher** desktop shortcut when that name is free, or preserves an existing matching shortcut. An unrelated shortcut is never overwritten.

For a custom location: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -Destination "D:\Tools\ProfileLauncher"`. Add `-NoShortcut` to omit desktop integration. Keep the app in a stable, writable local folder.

To update, exit the launcher from its tray menu and run the new package's installer against the same destination. Signed-in Codex profiles can keep running. Installation preserves `profiles/` and unknown files; edited managed scripts must be preserved separately before updating. A failed file-copy update rolls back managed files. Package checksums detect accidental tampering; they are not a publisher signature. This beta is unsigned and has not been validated against enterprise application-control policies.

## Everyday use

- **Add profile** opens a name/color editor. Create as many separate accounts as needed; use **Edit profile** to rename/recolor them. Folder IDs remain unchanged, preserving account data.
- **Launch** starts a stopped profile. **Focus** restores an existing visible/minimized window. **Reopen** asks the app to reopen a background profile without stopping its tasks. Status refreshes every three seconds. **Unknown / Unavailable** means process state could not be determined; it does not mean the account stopped.
- **Projects...** stores local folder shortcuts under that profile. Choose **Open selected** to request a new chat in that folder, using the selected profile. Removing a shortcut never deletes its project folder. The documented workspace deep link is passed directly to the selected app/data-root pair. It does not submit a prompt, merge account histories, or change project trust settings.
- **Open all profiles** opens them in list order, 15 seconds apart. A new cold start requires 2.5 GB free RAM; existing profiles bypass that launcher-specific threshold.
- **Fully close** forcefully stops that selected profile's process tree and interrupts its tasks. It cancels pending launches. Saved sign-in and chats stay on disk.
- Closing or minimizing the launcher hides it to the Windows tray. Double-click the tray icon to restore it, or use the tray's profile actions. **Exit launcher** releases hotkeys and cancels pending launches; it does not close Codex profiles.
- **Ctrl+Alt+Shift+L** opens the launcher. **Ctrl+Alt+Shift+1** through **9** open/focus/reopen the first nine profiles in list order. If another app owns a hotkey, the launcher reports the conflict. Disable hotkeys using **Global hotkeys** in the tray menu.
- Opening the launcher again for the same data folder signals the existing instance to restore, rather than creating another launcher window.

Profile labels are user-assigned names, not independently verified account identities. Check the account shown by Codex when signing in, especially in a shared browser.

## Data and existing installations

Runtime data is stored in `profiles/` beside the installed scripts, including `launcher.json` metadata, a bounded redacted event log, and each account's `codex/` and `desktop/` folders. These folders can contain credentials, chats and personal files. Do not publish or copy them into a release archive.

Existing PBX and Personal folders beside an older version are adopted in place on first use. New installations start with an empty profile list and need their own sign-in. Use `-DataRoot "absolute\path\to\profiles"` with `Launcher.ps1` to explicitly reuse an existing profile root; no automatic account migration or copying is performed. Separate folders are not an operating-system filesystem security boundary.

## Diagnostics

**Diagnostics** previews a local JSON report before export. It includes app/launcher/Windows versions, free memory, profile count and states, health codes and up to 50 sanitized event records. It omits profile names, project paths, credentials, chat content, environment variables and raw exception messages. Nothing is uploaded automatically. Unknown app builds are labeled unverified; known build recognition is not a blanket compatibility guarantee.

Read-only CLI check: `powershell.exe -NoProfile -File .\Launcher.ps1 -Profile Check`. It prints the same redacted report and returns failure for a missing app or invalid metadata. Corrupt metadata is reported and never silently reset.

## Remove

Exit the launcher, then run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1` from its installation folder. Removal deletes only unchanged managed application files and the matching desktop shortcut. Account folders, metadata, diagnostics, edited scripts, project folders, unknown files and legacy backups are retained. Delete account data separately only after deciding it is no longer needed.

## Development and tests

The repository copy defaults to its own `launcher/profiles/`, not the owner's signed-in installation. Run from the repository root:

- UI: `powershell.exe -NoProfile -STA -File .\launcher\Launcher.ps1`
- Tests: `powershell.exe -NoProfile -File .\launcher\tests\Run-Tests.ps1`
- Package: `powershell.exe -NoProfile -File .\launcher\Build.ps1`

Native hotkey/window tests require a normal interactive Windows desktop outside the restricted agent sandbox. Tests use synthetic data and mocked account actions; no packages are installed. See [verification record](tests/TDD.md). Build uses an explicit source allowlist and outputs an unsigned ZIP under `dist/`. No runtime data or tests enter the ZIP. Commercial demand, final branding/licensing and paid distribution remain unvalidated.
