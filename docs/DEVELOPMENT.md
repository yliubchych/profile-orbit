# Development

## Environment

Windows PowerShell 5.1, built-in .NET/Windows Forms and the official Codex desktop app installed for the Windows user. No additional package installation is required. Native UI/hotkey verification needs an interactive desktop; the restricted sandbox cannot register global hotkeys.

## Workflow

The owner requires test-driven development feature by feature. Write and run failing feature tests first, implement the slice, run that feature plus prior regression suites, then advance. Keep runtime data separate from source. Preserve user work and do not commit, publish, purchase services or migrate account data without authorization.

Use UTF-8 with BOM for PowerShell scripts containing non-ASCII text because Windows PowerShell 5.1 otherwise decodes them using its legacy default encoding. Metadata JSON is written explicitly as UTF-8.

## Commands

From repository root:

- `powershell.exe -NoProfile -STA -File .\launcher\Launcher.ps1`
- `powershell.exe -NoProfile -File .\launcher\Launcher.ps1 -Profile Check`
- `powershell.exe -NoProfile -File .\launcher\tests\Run-Tests.ps1`
- `powershell.exe -NoProfile -File .\launcher\Build.ps1`

The development launcher uses its own `launcher/profiles/`. To reuse an existing root explicitly, pass `-DataRoot` to Launcher.ps1. See the [user/setup guide](../launcher/README.md) and [test scope](TESTING.md).

Install/update/remove operations are implemented in Release.ps1 and exercised in synthetic test directories. Avoid editing the installed copy directly: prepare and verify source, create a backup of managed scripts, then deploy an allowlisted update. Never archive an installed folder wholesale.
