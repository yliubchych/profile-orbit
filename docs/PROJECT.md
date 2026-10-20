# Project overview

## Purpose and users
- Project mandate: research, validate, and prepare a small digital product with the goal of modest repeat-sale or recurring income, within the owner's stated low-cost and low-maintenance constraints.
- Current experiment: a Windows launcher for separate work and personal Codex profiles, selected by the owner on 2026-10-20 while cat-content work waits for photos.
- Target-user hypothesis: Windows developers and consultants using multiple accounts; independent demand remains unvalidated.
- Intended outcome: open or focus the correct profile without repeated sign-in, duplicate windows, or stopping background work.

## Scope
- Implemented Windows beta: guided named/color profiles, live Open/Background/Stopped state with smart actions, profile-bound project shortcuts, conservative install/update/remove and redacted diagnostics, tray access, global hotkeys and one launcher instance per data root. See [launcher README](../launcher/README.md).
- Business and release limits: [beta plan](../launcher/BETA_PLAN.md). Pricing, advertising, independent beta distribution, final branding and licensing remain open.

## Status
Windows beta implemented using the existing PowerShell/Windows Forms stack. The owner requested test-driven implementation of all five features in order; the verification trail is in [TDD.md](../launcher/tests/TDD.md). No independent beta results or sales are recorded, and account data is excluded from source and release packaging.

Update this page only when product intent or status is confirmed by the project owner or authoritative project material.
