# Decisions

Record significant, confirmed technical or product decisions here with a date, context, chosen option, rationale, and considered alternatives. Keep entries concise; link to detailed material only when it has an ongoing owner and purpose.

## Decisions
## 2026-10-20 — Launcher selected as the next experiment

The owner chose to start with the existing launcher while waiting for cat-content photos. Preserve its PowerShell/Windows Forms implementation as a baseline; do not infer a framework rewrite or a validated market. Only the launcher script and start command were copied into the repository, with no runtime profile data. The existing desktop shortcut continues using its original installation.

The [beta plan](../launcher/BETA_PLAN.md) records the ordered features and proposed paid-demand testing. Pricing, advertising, licensing, public distribution and external activity remain undecided. Previous opportunity assessments remain in the [research decisions log](../DECISIONS.md).

## 2026-10-20 — Five-feature test-driven implementation

The owner explicitly authorized the five proposed features, in order, with failing tests before implementation and verification before advancing. Preserve Windows PowerShell/Windows Forms and use built-in .NET with a dependency-free test harness. Separate local metadata, Windows integration, UI and release operations into files to test them without signed-in account access. Keep immutable profile folder IDs and adopt the owner's legacy profile folders in place; never copy credentials into source or packages.

Use the official documented workspace deep link for project shortcuts and deliver it to the selected app/data-root pair. Distribution is an unsigned allowlisted beta, with checksums, reversible file installation and conservative removal. No advertising, payment, cloud service, signing purchase or external publication was authorized or added.
