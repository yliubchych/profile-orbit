# Launcher beta and commercial validation

## Confirmed direction

On 2026-10-20 the owner chose the launcher as the next product experiment while waiting for cat-content photos. This prioritizes an experiment; it does not establish demand, a final price, or approval to publish, buy services, run ads or collect payments.

## Proposed selling proposition

Open the right AI account and project without repeated login, duplicate windows or interruption of background work. Initial audience hypothesis: Windows developers and consultants using separate work and personal accounts. This audience and willingness to pay remain unvalidated.

## Implemented beta features

The owner authorized all five additions in sequence with a test-first gate for each. All five are now implemented in the repository. See [user guide](README.md), [test record](tests/TDD.md) and [remaining limitations](../docs/KNOWN_ISSUES.md). This is implementation evidence, not proof of commercial demand.

## Original ordered scope (now implemented)

1. Guided setup: add, rename and color profiles without editing PowerShell. Preserve stable folder identifiers when renaming. The current fixed PBX/Personal baseline is not generic onboarding.
2. Live Open / Background / Stopped status with Focus / Reopen / Launch actions. Query process/window state; never imply a task is finished based on a window closing. Check duplicate-launch races and multiple launcher windows.
3. Project shortcuts associated with a profile. Verify a supported project-opening route before implementing it; do not promise account-policy or filesystem isolation.
4. Release essentials: explicit allowlist packaging, installation/removal that preserves profile data, readable errors, redacted diagnostics, and compatibility checks. Investigate code signing and update maintenance costs before committing to them.
5. Tray access, hotkeys and single-instance launcher behavior after the core flows are stable.

Multiple AI providers, cloud sync, credential transfer, team administration, advertisements and payments remain outside this beta. No signing certificate or paid service was purchased.

## Validation proposal

- Recruit 10–15 users who already need separate Windows accounts/profiles; recruitment has not started.
- Measure successful setup, repeated weekly use, reopen/duplicate-window failures and support minutes per user. Collect no prompts, credentials or chat content.
- Ask what existing workaround users would replace. Test a clearly stated $19–29 license offer only after the owner selects the offer and authorizes external activity.
- Treat actual purchases or explicit paid commitments as stronger evidence than downloads, compliments or hypothetical interest.
- Proposed continuation signal: at least five paid commitments plus successful repeated use without recurring manual repair. This is an experiment threshold, not a market benchmark.

## Evidence and uncertainty

The owner has used the launcher locally and confirmed the corrected background reopening behavior. The current chat documented earlier hidden-window and duplicate-window failures. No independent beta installations, sales, retention, conversion or support-cost measurements exist.

Free direct alternatives include [Multi Codex](https://github.com/am-will/multi-codex-app) and [ai-profiles](https://github.com/bartekczyz/ai-profiles). Another Windows/macOS offer is [Codex Multi Launcher](https://github.com/JqyModi/codex-multi-launcher). Reviewed in this chat on 2026-10-20; competitors' functionality is self-described, not independently tested.

Before a commercial release, choose independent branding, review the compatibility mechanism and applicable third-party terms, and verify payout/distribution eligibility. Do not describe this utility as affiliated with OpenAI or as a way to bypass usage limits. Product name, license, pricing, distribution and monetization remain undecided.
