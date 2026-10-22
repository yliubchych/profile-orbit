# Changelog

## 2026-10-22 — Console-free launcher startup (beta.5)

- UI launches now start the persistent Windows Forms process without a console and exit the initial bootstrap, preventing a lingering PowerShell/Windows Terminal window. Custom data roots and command-line diagnostics are preserved.
- Added a native synthetic regression for console absence, STA mode and custom data-root argument delivery.

## 2026-10-21 — In-app repository updates (beta.4)

- Added Updates in the main window and tray, background release checks/downloads, beta/stable selection, verified packages, and user-triggered install/restart.
- Added a trusted helper that waits for launcher exit, preserves the selected data root and running Codex profiles, rejects edited installations/downgrades, and uses existing installer rollback.
- Added both updater scripts to packaging and documented release preparation. Repository visibility was verified as public following owner authorization. Release publication and the owner's installed-copy upgrade remain separate steps.
- Full outside-sandbox regression gate: 103 passed across 25 suites, including 12 updater cases. Native helper checks passed again after the trailing-backslash quoting fix.

## 2026-10-21 — Profile-contained plugin setup candidate

- Added **Plugins...** to each profile card, opening the fixed official plugin directory directly in the selected profile's built-in browser. No Windows registration, cookie copying or new dependency is involved. Version: 0.1.0-beta.3.
- Verified direct entry into a live profile and synthetic return delivery while retaining the same original app process. GitHub later became installed/enabled in the active profile chat, and an authenticated read-only request succeeded. The completed authorization path was not observed; repeatable installation through the new entry point remains unverified.
- Added test-first regression coverage for fixed-URL validation, exact profile routing, rejection of arbitrary browser targets, and card action binding/layout.

## 2026-10-21 — Automatic-only authorization requirement

- Owner rejected manual Windows default-handler selection and required no manual user work. Disabled the experimental callback router at startup, removed its account-picker notice, and excluded callback/watchdog entry points from release packaging. Kept the inactive prototype and preservation tests for investigation.
- A unique disposable URL scheme successfully delivered to a synthetic handler; the existing `codex` scheme did not. Removed the disposable registration. A safe automatic live authorization route has not been established; the reported issue remains unresolved.

## 2026-10-20 — Browser authorization routing and Windows preservation

- Added automatic temporary callback routing with an explicit account picker, unchanged authorization-state delivery, profile process identity rechecks, and conservative Windows registration cleanup. Included the callback entry point and watchdog in the release allowlist; version is 0.1.0-beta.2.
- Added regression, subprocess, UI and disposable-registry tests, including restoration after a synthetic launcher crash. Routing/ownership keys are volatile, and custom handlers and concurrent registry edits are preserved.
- Local Windows activation probes failed and rolled back; the original empty protocol stub was retained. No protected default-app preference was changed. Real plugin authorization remains unverified; this is not a confirmed live fix of the reported return-routing issue.

## 2026-10-20 — Five-feature Windows launcher beta

- Implemented guided profile setup/editing, live state and contextual actions, profile-bound project shortcuts, allowlisted packaging/install/update/removal with diagnostics, and tray/hotkeys/single-instance behavior.
- Followed feature-by-feature failing-test, implementation and verification gates; expanded regressions for native window detection, subprocess argument/environment delivery, process races, forced-close identity checks, update rollback and owned-shortcut preservation.
- Added an unsigned beta release workflow with no new packages, paid services, analytics, ads or public deployment. Existing runtime data stays separate from source and packages. No commit was requested or made.

## 2026-10-20 — Launcher experiment selected

- Owner selected the Windows profile launcher as the next experiment while cat-content work waits for photos.
- Copied only the existing launcher script and start command into `launcher/`; no credentials, chats, runtime profiles or backup scripts were copied. Added runtime-data ignore rules.
- Added a proposed beta feature and commercial validation plan; synchronized the project wiki with the selected direction. No new launcher behavior, publication, monetization integration or paid service was added.
- Verified source hashes, PowerShell syntax, read-only installed-app detection and ignored runtime paths. Independent beta testing and willingness to pay remain unmeasured.

## 2026-10-20

- Started Phase 1 opportunity research from the user-provided product mission.
- Added initial candidate comparison, source notes, a provisional research lead, and a no-cost validation plan.
- A small first review scan found praise for simplicity but did not establish an unmet need; a competing bundle already includes a vendor payment tracker. Validation remains open.
- Completed a 25-review scan across seven wedding-planner listings and compared eight products' public feature claims. No wedding payment-timing gap met the continuation threshold; the candidate is deprioritized and no product is selected.
- No product code, publishing, purchases, or paid commitments.
- Completed a 25-comment viewer-feedback screen across five lore communities and compared six established channel formats. There is visible interest, but broad and franchise-specific formats are already well served; source transparency remains a hypothesis rather than a validated gap. No product selected.
- Checked current YouTube monetization rules and its announced February 2027 higher ad-revenue entry threshold for new creators; noted copyright/reused-content risks for franchise-based videos.
- Recorded a no-cost assistant-value demonstration as the next proof step. The user may consider a paid AI plan after seeing value; no subscription was purchased, and this does not authorize a purchase.
- Checked local media capabilities: basic Windows text-to-speech is present with one en-US female voice, and Microsoft Clipchamp is installed. There is no Russian system voice or FFmpeg; current tools do not expose control of Clipchamp. Voice quality is untested; no audio or video was generated.
- Aligned wiki maintenance with the referenced Workflow PBX + AI wiki: added a canonical open-questions page and provenance/status guidance. No product or implementation decision changed.
- Completed a 25-comment buyer-review sample across seven YouTube/creator planner listings and compared paid/free template and software features for a lore/video-essay research-to-script product. No repeated need for source-claim or canon tracking appeared; no product selected.
- Initially verified market-level English reach and purchasing power using W3Techs web-content language shares, World Bank 2024 GNI per capita PPP, and Etsy's 2025 buyer/GMS disclosures; the 2025 World Bank data refresh is recorded below. Recorded English as the first sample's working language. Topic-level demand and conversion remain unvalidated; no paid plan or editing service was purchased.
- Prepared a short English Tolkien lore script package with a claim/source ledger and edit map as a capability demonstration only. The user has not selected video creation as the business model; no voiceover, finished video, or publication was produced. Next compare remaining business models before any product choice.
- Completed a 26-comment review sample across five paid worldbuilding/story-bible templates and compared their features with free and paid substitutes. The listings show purchase activity, but no repeated underserved need; the candidate is not selected. No code, spending, account creation, or publication.
- Compared four monetization routes using current official marketplace fees, platform thresholds, AI-content policies, and payout requirements. This supports treating video as a possible acquisition channel and a reusable file as the product format with the closest structural fit, but no channel/product was chosen and no sale timeline or earnings forecast is supported.
- Screened handmade/candle pricing and batch-costing tools against maker discussions, four paid Etsy offers, and a free calculator; the broad workflow is already covered and no product-level buyer demand was established.
- Ran an exploratory artist commission queue/status scan across public discussions, Etsy listings/review peeks, and Ko-fi, VGen, and Jotform feature pages. A privacy-safe public queue is one unvalidated signal; no product selected. The next gate is a 25-comment sample across seven direct listings and a full paid/free feature comparison.
- Completed the 25-comment artist/commission review sample across nine paid Etsy listings and compared paid templates with Ko-fi, VGen, Jotform, and free manual workflows. No repeated underserved need met the threshold; VGen already provides an anonymized, automatically synced public queue for VGen-only jobs. No artist tracker selected.
- Updated the English-market purchasing-power comparison to the World Bank's latest available 2025 GNI-per-capita PPP values. English is supported as a broad reach and purchasing-power choice, while demand for any specific product remains unvalidated. Video is not selected as the best product or business model.
- Followed up on the artist-queue hypothesis by comparing current SievePage, WipDesk, Studio Queues, and ArtDash features and pricing. Free/low-cost tools already cover public queues, private client links, form intake, or cross-platform manual entry; no new differentiator was validated. Updated the roadmap and open questions so they no longer list the completed sample as pending.
- Rechecked English-market purchasing power against the latest 2025 World Bank figures, added household consumption per capita as a direct spending proxy, and corrected older GNI-per-capita values. The data support prioritizing high-income English-primary markets at a macro level, not assuming uniform affluence or demand across all English speakers.
- Completed a 27-comment UGC brand-deal tracker review sample across 11 Etsy listings and compared five low-cost templates with four creator-focused SaaS tools. Buyers praise organization, but no repeated feature gap appears and free plans already cover much of the job. No product selected; video remains an optional channel, not a chosen business model.
- Ran a $0 pre-screen of private-tutor prepaid-balance reconciliation, home-bakery order/pickup planning, nonprofit grant reporting, and craft-fair inventory. Public discussions show real admin work, but current free tools and paid templates cover the broad tasks; no specific candidate advanced to a full review sample. No product selected.
- Reviewed project documentation for consistency and local link integrity. Clarified that research-stage decisions live in the root decision log and corrected the description of the current workspace contents; no product or technology decision changed.
- Completed a $0 pre-screen of mobile-detailer pricing, job costs, and consumables. Operator discussions confirm the broad job matters, but free profit calculators and dedicated low-cost worksheets already cover it; evidence for a separate inventory/reorder gap is weak. No product selected; continue scouting outside screened categories.
- Completed a 25-comment Etsy buyer-review sample across 10 bookkeeper onboarding listings and compared paid templates, a free client handbook, and client-document workflow software. Buyers praise usability and customization; no repeated underserved need met the five-independent-comment threshold. No product selected; video remains an optional channel rather than the chosen product.
- Screened Etsy-seller expense tracking against four public seller discussions, official Etsy/Xero and Etsy/QuickBooks connections, a free Schedule C file, and paid spreadsheet offers. The exact recent request for simpler tax categories appeared once, while core tracking is well covered; no full review sample or product selection.
- Screened short-term-rental cleaner handoff against host discussions, Turno's current checklist/photo-documentation workflow and pricing, and Etsy's downloadable offers. The recurring quality-control job is real, but Turno already supports photo-required checklist items and is free for one property; no full review sample or product selection. See Experiment 16.
- Screened freelancer scope-change control against independent reports of unpaid work, direct Etsy toolkits/spreadsheets, free proposal templates, and a free browser demo. Exact tools already cover the proposed forms, fee calculations, logs, approval records, and client scripts; no unique gap emerged, and founder-led feedback posts were excluded as buyer evidence. No review sample or product selection. See Experiment 17.
- Completed a 25-comment sample across five TPT emergency-sub-plan listings and compared paid plans with free full-day and mini-lesson resources. Buyers value ready-to-use plans, but no complaint repeated often enough to identify a product gap; no product selected. See Experiment 18 and [RESEARCH.md](RESEARCH.md). Video remains unselected.
- Pre-screened tabletop RPG session preparation against independent DM discussions, Sly Flourish's free worksheets and Notion template, a paid $10 Game Master workspace, and low-cost Etsy/itch.io planners. The time burden varies; core templates and campaign continuity are already served. No full review sample or product selection.
- Screened indie-author event stock, consignment tracking, and bookstore discovery against author discussions, free worksheets/directories, and current paid tools. Existing free coverage is substantial and the paid inventory listing had no item reviews at capture; no product selected or author/store contacted. Video remains unselected.
- Completed a 25-comment sample across seven reseller inventory/profit spreadsheet listings and compared paid templates with free spreadsheets, a free photo-led app, crosslisting software, and bundle-sale allocation. Buyers praise ease and organization, but no repeated unmet feature appeared; no product selected.
- Pre-screened family caregiver coordination against current family discussions, Caring Village's free and paid plans, a free caregiver binder, and current Etsy planners. The broad coordination job is covered, no specific static-product gap emerged, and sensitive health-data boundaries increase scope risk. No product selected or caregiver contacted.
- Pre-screened volunteer-club dues tracking and treasurer handover against independent treasurer discussions, free dues spreadsheets, membership software, and paid club kits. Existing offers cover core tracking, and no narrow gap repeated; the one founder-led forum thread was excluded. No product selected, files purchased, or clubs contacted. See Experiment 23.
