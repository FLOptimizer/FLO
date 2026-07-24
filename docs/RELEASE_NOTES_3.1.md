# FLO 3.1 (build 12) — Release Notes

## App Store "What's New" (draft)

**Meet the FLO Assistant, plus Events**

- **FLO Assistant** — Ask about your money in plain English. The assistant can pull up your real numbers, categorize transactions, jump you to the right screen, and send a proactive weekly digest of your finances.
- **Events** — Group expenses by trip, holiday, or occasion. See what the beach week or the holidays actually cost, across every category and account.
- **Invoice links open in the app** — Tapping an invoice link now lands clients directly in FLO when it's installed.
- **Smoother account picking** — Choosing an account on transactions, budgets, and receipts now uses a clean menu picker everywhere.
- **Fixes** — Depreciation schedules now match IRS Pub 946 exactly (Section 179, bonus depreciation, and 27.5-year rental property). Bank connections are no longer flagged as broken during temporary provider hiccups.

## Internal changelog (since build 11, commit 3a01c81)

| Area | Change | Commits |
|---|---|---|
| Assistant | Tiers 1–3: real tool calling, persistent session, streaming; guardrailed actions (navigate, categorize, create events); proactive weekly digest | 88fce2d, 10efe38, 7976a11 |
| Assistant | Stale-year fixes: 2025 hardcodes, 2026 mileage rate | cf1f0b7 |
| Events | Time-bounded expense grouping (trips, holidays, occasions); fix for entry appearing in orphaned legacy MoreView | aadf5c5, 4f5b78f |
| Invoicing | applinks entitlement + universal-link handling in the full app | d77c2bc |
| Accounts | Menu picker replaces horizontal account chips across all forms | c454c47 |
| Plaid | Transient backend failures no longer flag banks as broken | 3384363 |
| Tax engine | Fixed §179 double-count, empty 100%-bonus schedule, bonus double-count in accumulated/remaining, missing half-year on 27.5-yr residential | 77d91ea |
| Infrastructure | Test suite (992 tests) + FLODesignSystem brought into the repo; FLOTests runnable via xcodebuild | 0a299e7, 7591972 |

## Version notes

- Marketing version bumped 3.0 → 3.1 (build 11 released as 3.0; App Store Connect requires a new version string for the next release). Build number stays 12.
- Bumped targets: FLO app, FLOWidgetExtension, FLOInvoiceClip (the three that tracked 3.0). Watch targets remain 1.0/1, unchanged from the shipped build 11 configuration.
