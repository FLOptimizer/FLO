# FLO Build 10 (v3.0) — App Store Submission Handoff
> **Document version:** 2.1 (2026-07-20) — §3.1 description and §6.2 reviewer notes updated for the tier restructure: balance tracking + account selection now Free, reconciliation now Premium, Plaid corrected to Pro-only, Free transaction limit corrected 50→75, Premium account count corrected to 5.
> **Supersedes:** `FLO_Build10_AppStore_Handoff.md` (v1.0, generated 2026-05-27 earlier today)
> **For Cowork / agent operating App Store Connect in Chrome.**
**Generated:** 2026-05-27 (v2 revision)
**Author:** Claude session with Travis Anderson
**Project root:** `/Users/travisanderson/Financial Ledger Optimizer`
**Submission type:** iOS update (3.0) + macOS first-time submission (3.0)
**Target review window:** ASAP — ad campaign starts next month
---
## 0. What changed in v2 (read this first)
This revision incorporates verification work done in the session on 2026-05-27. The original handoff (v1) had several open questions; most are now resolved:
| Item | v1 status | v2 status |
|---|---|---|
| Support email | Placeholder `support@finchandpoppy.com` | ✅ Confirmed `flo.financeapp@gmail.com` (live on privacy.html and in ASC contact info) |
| Legal URLs live? | Open question for Travis | ✅ Terms, Privacy, EULA, Legal Disclaimer all live and current |
| Marketing URL homepage live? | Open question | ✅ `https://floptimizer.github.io/FLO/` live |
| Support URL `support.html` | Listed as the URL | ⚠️ **404s — use `contact.html` instead** |
| Demo account / biometric workaround | Open question | ✅ Already handled — Sign-In Required unchecked in ASC, notes say "Fresh install should not lock", test IAP accounts already provided |
| macOS deployment target = 15.0 | Open question | ✅ Verified in Xcode (FLO target → General → Minimum Deployments → macOS 15.0) |
| App Privacy section | Open question | ✅ Travis confirmed already verified |
| Pricing in reviewer notes | Not flagged | ⚠️ **Mismatch detected** — see §2.1 / §10 |
---
## 1. Identifiers & Versions
| Field | Value | Verified 2026-05-27 |
|---|---|---|
| App name | FLO — Finance Ledger Optimizer | — |
| Developer | Finch & Poppy Co LLC | ✅ (matches footer of floptimizer.github.io) |
| iOS bundle ID | `com.finchandpoppy.flo` | ✅ (Xcode + ASC) |
| macOS bundle ID | `com.finchandpoppy.flo` | ✅ (Xcode Signing & Capabilities, same as iOS) |
| Widget bundle ID | `com.finchandpoppy.flo.widget` | — |
| Plaid URL scheme | `flo://` | — |
| Marketing version (iOS + macOS) | **3.0** | — |
| Build number | **10** | — |
| Minimum iOS | **18.0** | ✅ (Xcode General → Minimum Deployments) |
| Minimum macOS | **15.0** | ✅ (Xcode General → Minimum Deployments) |
| Supported destinations | iPhone, iPad, Mac | ✅ (Xcode General → Supported Destinations) |
| Languages | English (en-US) | — |
| Primary category | Finance | — |
| Secondary category | Productivity | — |
App Store Connect App ID: `6756789373` (visible in URL when on FLO record).
---
## 2. ⚠️ MANDATORY APP STORE CONNECT ACTIONS — DO BEFORE SUBMISSION
### 2.1 Pricing — RESOLVED: trust StoreKit, the reviewer notes are stale
**The mismatch is resolved.** During session debug, the device's StoreKit returned the production prices live in App Store Connect:
```
✅ Loaded 4 subscription products
   • Premium Yearly: $79.99
   • Premium Monthly: $7.99
   • Pro Yearly: $99.99
   • Pro Monthly: $12.99
```
StoreKit pulls directly from ASC at runtime — it cannot lie. The higher prices ($12.99 / $129.99 / $19.99 / $199.99) in the existing ASC reviewer-notes textarea are **stale text from an earlier version of FLO that never matched the actual product configuration**. They must be updated to match reality.
**Confirmed truth as of 2026-05-27:**
| Product ID | Current live price | Action |
|---|---|---|
| `com.finchandpoppy.flo.premium.monthly` | $7.99/mo | **No change** |
| `com.finchandpoppy.flo.premium.yearly` | $79.99/yr | **DROP to $59.99/yr** ← only change |
| `com.finchandpoppy.flo.pro.monthly` | $12.99/mo | **No change** |
| `com.finchandpoppy.flo.pro.yearly` | $99.99/yr | **No change** |
The code's fallback strings in `SubscriptionTier.swift` v1.8 have been updated to match these production prices.
**How to change the one price in App Store Connect:**
1. Sign in → My Apps → FLO → Monetization → Subscriptions
2. Open `com.finchandpoppy.flo.premium.yearly`
3. Pricing → Schedule a price change → $59.99 USD → Apply to all territories (default conversion)
4. Effective date: as soon as available
5. Save
**Reviewer-notes update required:** When pasting the §6.2 block, ensure the SUBSCRIPTIONS line uses the production prices above, NOT the stale $12.99/$129.99/$19.99/$199.99 set.
### 2.2 macOS first submission setup
This is the FIRST time FLO is being submitted as a macOS app. The existing App Store record is iOS-only. You'll be adding the macOS platform under the same SKU.
**Steps in App Store Connect:**
1. My Apps → FLO → top-left platform selector → **+ Add Platform** → **macOS** (an "Add Platform" link is visible in the left rail when viewing FLO)
2. New macOS app record opens with the SAME bundle ID `com.finchandpoppy.flo` (Xcode already signs the macOS target with this — verified)
3. Fill the metadata using §3 (same copy as iOS unless specifically noted)
4. Upload macOS screenshots (§5)
5. macOS app uses **same in-app purchase products** as iOS — no new IAPs needed
6. **Pricing tier:** Free (with IAPs) — same as iOS
7. macOS app preview video is **optional** but improves conversion. Skip if not ready.
### 2.3 What's New (release notes)
Paste into Version Information → What's New in This Version for **both** iOS and macOS:
```
FLO 3.0 is our biggest release yet — a complete visual redesign and first-class macOS support.
NEW IN 3.0:
• macOS support — work on your finances from your Mac with full keyboard nav and menu bar widget
• Liquid Glass design on iOS 26 — subtle, premium glass effects across the app
• Landscape support on iPhone and iPad with adaptive three-zone navigation
• Redesigned navigation — all features now first-class, no more nested menus
• Premium yearly intro pricing — limited time
MILEAGE IMPROVEMENTS:
• One-tap classification for unreviewed trips — Business, Personal, or Commute right at the top of trip details
• Bulk classify — clear your entire Needs Review backlog from one menu
• Live count of trips needing review surfaced on the main mileage screen
• Trip rows now tappable directly from the home screen
• Fixed: deductions now update correctly when classifying trips
UNDER THE HOOD:
• Cleaner architecture for faster iteration
• Improved accessibility across the app
• Better Dynamic Type support
```
Keep under ~4,000 chars.
---
## 3. App Store Listing Copy
### 3.1 Description (4,000 char max)
Use the block below. Prices are the confirmed production values per §2.1 (with Premium yearly reflecting the intro drop to $59.99).
```
FLO is the all-in-one finance tracker for freelancers, side-hustlers, and small business owners. Track every dollar, claim every mile, and hand your CPA a tidy tax package — all from your phone or Mac.
WHAT FLO DOES
Track transactions across personal AND business accounts in one place. FLO automatically separates business income and deductions so you're tax-ready year-round.
KEY FEATURES
• Smart receipt scanner — point your camera at a receipt and FLO extracts merchant, amount, date, tax, and tip automatically. Works for receipts, bills, and invoices.
• Mileage tracking — automatic GPS-based business mileage logging with IRS rate calculation. Classify trips with one tap. Bulk-clear unreviewed trips. Built for the 2026 IRS rate of $0.725/mi.
• Tax-ready reporting — Schedule C, Form 1065, Schedule F, Schedule E line mapping. Export to Lacerte CSV or generic CSV for any tax prep software.
• Business entity support — track multiple LLCs, partnerships, or sole proprietorships. K-1 partner allocations, basis tracking, MACRS depreciation, multi-year carryforwards.
• Cash flow forecasting — three-month forecast with danger zone alerts.
• Plaid bank sync — connect 12,000+ banks (Pro)
• Cloud sync with iCloud across iPhone, iPad, Mac, and Apple Watch
• Invoicing — create, send, and track invoices. Cash flow updates the moment a client pays.
• Debt payoff calculator — snowball vs avalanche scenarios
• Budgets — category budgets with personalized insights
• Apple Watch app + home screen widgets
FREE TIER
• Up to 75 transactions per month
• 2 accounts with full balance tracking
• Smart receipt scanner included
• Manual mileage entry
• Basic budgets and reports
PREMIUM ($7.99/mo or $59.99/yr — limited launch pricing)
• Unlimited transactions and receipts
• Up to 5 accounts with reconciliation tools
• Automatic GPS mileage tracking
• CSV bank statement import
• Quarterly tax estimates
• Personalized financial insights
PRO ($12.99/mo or $99.99/yr)
• Everything in Premium
• Plaid bank sync — 12,000+ banks
• Unlimited accounts and invoices
• Multi-entity tax preparation (LLCs, partnerships, Schedule C/F/E)
• Partner basis tracking and K-1 allocations
• MACRS depreciation schedules
• Tax carryforward register
• Year-end closing workflow
• Filing checklist with deadlines per entity
• Estimated tax dashboard with safe harbor calculations
• NAICS code suggestions
• Multi-year tax comparison
• CPA handoff PDF + JSON export
• Filing preparer checklist
• Profit & loss reports
PRIVACY FIRST
FLO never sells your data. All financial data syncs through iCloud — Apple's encrypted infrastructure. No tracking, no ads, no data brokers.
7-DAY FREE TRIAL on Premium. Cancel anytime in Settings > Subscriptions.
Terms: https://floptimizer.github.io/FLO/terms.html
Privacy: https://floptimizer.github.io/FLO/privacy.html
EULA: https://floptimizer.github.io/FLO/eula.html
Built by Finch & Poppy Co LLC.
```
### 3.2 Promotional Text (170 char max)
```
FLO 3.0 — now on Mac. Liquid Glass redesign, landscape support, one-tap mileage classification, and limited launch pricing on Premium.
```
### 3.3 Keywords (100 char max, comma-separated) — REVISED 2026-07-22 for build 12
```
expense tracker,1099,self employed,mileage,tax,receipt scanner,invoice,budget,quarterly,cpa,llc
```
> (95 chars.) Rationale: Apple already indexes the app NAME and SUBTITLE as keywords, so the old field wasted ~30 chars repeating "finance", "freelancer", and "small business". Those chars now buy the high-intent searches: "expense tracker", "1099", "self employed", and "quarterly" (which combines with "tax" — Apple cross-combines keyword terms). Dropped "plaid" (negligible consumer search volume) and "bookkeeping" (weak fit). Applies with the next version submission; keywords cannot be changed without a new version.
### 3.4 Support URL — ⚠️ CHANGED FROM V1
```
https://floptimizer.github.io/FLO/contact.html
```
> v1 listed `support.html` but **that page 404s on GitHub Pages** (verified 2026-05-27 via curl-equivalent navigation). Use `contact.html` which loads correctly and contains contact info routing to `flo.financeapp@gmail.com`. If a dedicated support page is preferred long-term, add a `support.html` to the `floptimizer/FLO` repo, then change this URL back.
### 3.5 Marketing URL (optional) — ✅ Confirmed live
```
https://floptimizer.github.io/FLO/
```
Loads cleanly. Footer shows "© 2026 Finch & Poppy Co LLC. All rights reserved." Hero copy matches FLO 2.0/3.0 messaging.
### 3.6 Privacy Policy URL — ✅ Confirmed live
```
https://floptimizer.github.io/FLO/privacy.html
```
Lists `flo.financeapp@gmail.com` as the CCPA contact. Substantively current.
### 3.7 Other live URLs (for reviewer notes / description / footer cross-checks)
- Terms: `https://floptimizer.github.io/FLO/terms.html` ✅ live (12,925 chars, mentions `flo.financeapp@gmail.com`)
- EULA: `https://floptimizer.github.io/FLO/eula.html` ✅ live (15,906 chars, mentions `flo.financeapp@gmail.com`)
- Legal Disclaimer: `https://floptimizer.github.io/FLO/legal.html` ✅ live (11,326 chars)
---
## 4. Privacy / App Privacy Section — ✅ Travis verified, no changes
For macOS first submission, mirror the existing iOS App Privacy settings.
Data types collected (no changes from v1):
| Data type | Used for | Linked to user? | Tracking? |
|---|---|---|---|
| Financial info (transactions) | App functionality | No | No |
| User content (receipt images, trip data, notes) | App functionality | No | No |
| Identifiers (user ID via iCloud) | App functionality | Yes (anonymous) | No |
| Location (precise, while in use + background) | App functionality (mileage tracking) | No | No |
| Diagnostics (crash logs, performance metrics) | App functionality, analytics | No | No |
No tracking SDKs. No third-party analytics. iCloud-only sync.
---
## 5. Screenshots Required
### 5.1 iOS — REQUIRED sizes
| Display | Pixel size | Required |
|---|---|---|
| 6.9" (iPhone 16 Pro Max) | 1320 × 2868 | **REQUIRED** |
| 6.7" (iPhone 15 Pro Max) | 1290 × 2796 | Recommended |
| 6.5" (iPhone 11 Pro Max) | 1242 × 2688 | Optional fallback |
| 13" iPad Pro M4 | 2064 × 2752 | **REQUIRED if iPad supported** |
If you supply 6.9", it auto-scales to other iPhone sizes.
### 5.2 macOS — REQUIRED
| Size | Pixel size |
|---|---|
| Standard | 1280 × 800 (minimum) or 2880 × 1800 (Retina recommended) |
| Aspect ratio | 16:10 |
Apple requires 1–10 screenshots per platform.
### 5.3 Suggested screenshot sequence (5–7 each platform)
Capture from Build 10 on simulator. In Xcode Simulator: **File → New Screen** for the device frame, then **File → Save Screen** (Cmd+S) on the simulator window for the screenshot.
1. **Dashboard** — hero metrics, net cash flow card with new Liquid Glass treatment
2. **Mileage** — main screen showing "Recent Trips · 3 NEED REVIEW" badge + orange-flagged unreviewed row
3. **Trip Detail with Classify Banner** — open an unreviewed trip showing the three-button banner
4. **Tax** — Business Tax Summary with form-line breakdown (Pro feature, looks impressive)
5. **Smart Receipt Scanner** — receipt being captured with extracted fields
6. **Subscription / Paywall** — show LIMITED-TIME LAUNCH PRICING badge on Premium yearly
7. **macOS sidebar layout** — three-zone landscape showing breadth of features
Each screenshot should include a benefit-driven caption overlay (e.g., "Track every business mile automatically" not just "Mileage").
### 5.4 Custom Product Pages (added 2026-07-22) — pair each ad angle with a matching page
ASC → FLO → App Store tab → Custom Product Pages → (+). Each page gets its own URL; use that URL as the ad destination so the first screenshots match the ad promise. CPPs customize ONLY promotional text, screenshots, and preview videos — description/keywords stay from the default page. No review resubmission needed; CPPs go through a lightweight review on their own.

**CPP 1 — "Mileage" (pair with mileage-angle ads: "every mile is worth $0.725")**
- Reference name: `mileage-2026`
- Promotional text (170 max): `Every business mile is worth $0.725 in 2026. FLO tracks them automatically with GPS, classifies trips in one tap, and hands you an IRS-ready log.`
- Screenshots (captions overlaid): 1) Mileage main screen — "Tracks your miles while you drive" 2) Trip detail w/ classify banner — "Business or personal? One tap." 3) Deduction total view — "Watch your deduction grow" 4) Dashboard — "Your whole business in one place" 5) Paywall w/ trial badge — "Try free for 7 days"

**CPP 2 — "Receipts" (pair with receipt/expense-angle ads; strongest FREE hook)**
- Reference name: `receipt-scanner`
- Promotional text: `Point your camera at a receipt — FLO reads the merchant, amount, tax, and tip, then files it as a transaction. Free, unlimited, no account required.`
- Screenshots: 1) Scanner mid-capture — "Snap a receipt, done" 2) Extracted fields — "Merchant, amount, tax & tip — read automatically" 3) Transaction list — "Filed and categorized" 4) Business/personal split — "Separate business from personal" 5) Dashboard — "Tax-ready all year"

**CPP 3 — "Quarterly taxes" (pair with tax-angle ads; strongest PAID converter)**
- Reference name: `quarterly-taxes`
- Promotional text: `Never guess a quarterly payment again. FLO estimates your taxes in real time from actual income, reminds you before each IRS deadline, and maps to Schedule C.`
- Screenshots: 1) Tax estimate card — "Know what you owe, live" 2) Quarterly deadlines view — "Reminded before every deadline" 3) Business tax summary — "Schedule C, mapped for your CPA" 4) Receipt scan — "Every deduction captured" 5) Paywall w/ trial — "Try Premium free for 7 days"

Suggested pairing: run each ad creative to its CPP URL and compare page-view→install conversion per page in ASC Analytics after ~2 weeks; kill the weakest angle, reallocate budget to the strongest.
---
## 6. App Review Information — ✅ Already configured for v2.1, needs update for v3.0
### 6.1 Current state in ASC (verified 2026-05-27)
- **Sign-In Required:** ☐ **Unchecked** — no demo account needed (biometric is off by default on fresh install)
- **Contact:** Travis Anderson · 9512820972 · flo.financeapp@gmail.com ✅
- **Notes textarea:** 3,247 chars, currently tailored to v2.1
- **Test accounts (already in notes for IAP review):**
  - `flotest.one@yahoo.com` / `TestPass12345`
  - `flotest.two@yahoo.com` / `TestPass123456`
### 6.2 Updated reviewer notes ready to paste for v3.0
Replace the "WHAT'S NEW IN v2.1" section in the existing notes with the v3.0 block below. **Also update the SUBSCRIPTIONS line of the carry-forward "KEY FEATURES TO TEST" section if it lists prices — use the confirmed production prices ($7.99 monthly / $59.99 yearly Premium · $12.99 monthly / $99.99 yearly Pro), NOT the stale $12.99/$129.99/$19.99/$199.99 set.**
```
WHAT'S NEW IN v3.0:
macOS support (FIRST macOS submission): Native SwiftUI multiplatform. Menu bar widget, full keyboard navigation, three-zone NavigationSplitView in landscape.
Liquid Glass design (iOS 26 / macOS 26): Native .glassEffect() on supported OS, ultraThinMaterial fallback on older OS.
Landscape support: iPhone portrait → TabView; iPhone landscape → 50pt icon sidebar; iPad/Mac → full sidebar with section grouping.
Mileage UX overhaul: Recent Trips header shows live "N NEED REVIEW" count. One-tap Business/Personal/Commute classify banner on trip detail. Bulk classify from Review All Trips. Trip rows now directly tappable from home. Fixed: deduction recalculates when toggling Business on a needsReview trip.
Smart Receipt Scanner moved to Free tier: Previously Premium-gated. Free tier receipt storage limit removed.
Tier restructure (2026-07-20): Balance tracking and account selection are now Free for all users. Account reconciliation moved from Pro to Premium. Plaid bank sync remains Pro-only.
Premium yearly intro pricing: $59.99/yr (down from $79.99) with "LIMITED-TIME LAUNCH PRICING" pill on Premium card.
REVIEWER NOTE — biometric lock:
Fresh install does NOT lock by default. Biometric/passcode is opt-in via Settings > Security. No demo credentials required to launch the app.
```
### 6.3 Update the existing URLs block in the notes
The current notes end with:
```
Privacy: https://floptimizer.github.io/FLO/privacy.html
Terms: https://floptimizer.github.io/FLO/terms.html
EULA: https://floptimizer.github.io/FLO/eula.html
```
All three verified live ✅ — no change needed.
---
## 7. In-App Purchases — Status
Four IAPs already exist in App Store Connect (`Loaded 4 subscription products` confirmed in StoreKit logs):
| Product ID | Tier | Period | Current price | Status for Build 10 |
|---|---|---|---|---|
| `com.finchandpoppy.flo.premium.monthly` | Premium | Monthly | $7.99 | ✅ No change |
| `com.finchandpoppy.flo.premium.yearly` | Premium | Yearly | $79.99 → **$59.99** | ⚠️ **Drop price, see §2.1** |
| `com.finchandpoppy.flo.pro.monthly` | Pro | Monthly | $12.99 | ✅ No change |
| `com.finchandpoppy.flo.pro.yearly` | Pro | Yearly | $99.99 | ✅ No change |
7-day free trial on Premium tier — verify introductory offer is configured on both monthly and yearly Premium products.
---
## 8. Build 10 Change Summary
### 8.1 Major user-facing changes
| Area | Change |
|---|---|
| Visual redesign (Phase A + B) | FLODesignSystem Swift Package extracted. 11 first-class sidebar tabs replacing 5-tab + More. Adaptive layout: portrait TabView, landscape/macOS NavigationSplitView with three zones. |
| macOS launch | First macOS submission. Menu bar widget showing today's income/spending/invoices. Keyboard nav. Native SwiftUI multiplatform. |
| Landscape support | iPhone landscape collapses sidebar to 50pt icon strip. iPad and macOS show full sidebar with section grouping. |
| Liquid Glass (Phase C, key surfaces) | iOS 26 / macOS 26 native `.glassEffect()` via the `floGlassCard` modifier. Older OS keeps current ultraThinMaterial treatment. |
| Tier loosening | Smart Receipt Scanner moved to Free tier. Free tier receipt storage limit removed. |
| Mileage UX overhaul | Recent Trips section header shows live "N NEED REVIEW" count in orange. Trip rows now have NEEDS REVIEW pills, disclosure chevrons, and are directly tappable. Classify banner on detail view for one-tap classification. Bulk-classify menu in Review All Trips with confirmation dialogs. Fixed bug where toggling Business on a needsReview trip didn't update deduction. |
| Pricing | Premium yearly intro launch drop $79.99 → $59.99. "LIMITED-TIME LAUNCH PRICING" pill on Premium card. Code fallback strings synced to production. |
### 8.2 Files touched this session
- `FLO/Views/Mileage/MileageTripDetailView.swift` v3.4 (bug fix, classify banner, picker warning fix)
- `FLO/Views/Mileage/MileageTripListView.swift` v3.2 (bulk classify menu + confirmations)
- `FLO/Views/Mileage/MileageTrackingMainView.swift` v3.4 (Recent Trips UX overhaul)
- `FLO/Views/Settings/SubscriptionView.swift` v3.7 (launch pricing pill + dynamic toggle copy)
- `FLO/Models/SubscriptionTier.swift` v1.8 (fallback prices synced to production)
- `FLO/App/ContentView.swift` v5.1 (landscape iPhone icon sidebar)
- `FLO/Views/Navigation/SidebarView.swift` (icon-only mode)
- `FLODesignSystem/.../GlassCard.swift` (Liquid Glass conditional)
- `FLO/FLO.xcodeproj/project.pbxproj` (version bump 2.1→3.0, build 9→10)
---
## 9. Known issues to monitor (NOT launch blockers)
| Issue | Severity | Action |
|---|---|---|
| Cold start 3,152ms (target: 1,000ms) | Yellow | Performance debt. Schedule for Build 10.1 or Build 11. Not a regression. |
| Dashboard first render 1,338ms (target: 200ms) | Yellow | Cold-cache only. Subsequent renders are 36ms. Schedule lazy-loading pass for Build 11. |
| Peak memory 180MB (warning at 150MB) | Yellow | MapKit hold during trip detail. Acceptable on modern devices. Monitor. |
| `default.csv` console warnings | Green | MapKit internal noise — not FLO code. Apple framework bug. Ignore. Confirmed via [Apple Developer Forums](https://developer.apple.com/forums/thread/771614). |
| `NSKeyedUnarchiveFromData` deprecation | Green | Pre-existing. Apple won't remove until future iOS. Schedule for Build 11. |
---
## 10. Submission checklist — UPDATED with v2 verifications
Go through in order. ✅ items are confirmed done. ⚠️ items need Travis/Cowork action.
### Phase A — Pre-flight
- ✅ Sign in to App Store Connect (verified working)
- ✅ FLO record exists under `com.finchandpoppy.flo` (App ID 6756789373)
- ✅ Current iOS version 2.1 / build 9 confirmed ("Ready for Distribution" status)
- ✅ Live prices confirmed via StoreKit logs ($7.99 / $79.99 / $12.99 / $99.99) — §2.1
- ⚠️ **Drop price on `com.finchandpoppy.flo.premium.yearly` from $79.99 → $59.99**
- ⚠️ Confirm 7-day intro offer is active on both Premium products
- ✅ Privacy URL live: `https://floptimizer.github.io/FLO/privacy.html`
- ✅ Terms URL live: `https://floptimizer.github.io/FLO/terms.html`
- ✅ EULA URL live: `https://floptimizer.github.io/FLO/eula.html`
- ✅ Marketing URL live: `https://floptimizer.github.io/FLO/`
- ⚠️ Use `contact.html` not `support.html` for Support URL (§3.4)
### Phase B — iOS version 3.0
- ⚠️ My Apps → FLO → + Version or Platform → New iOS Version → enter `3.0`
- ⚠️ **What's New:** paste from §2.3
- ⚠️ **Description:** paste from §3.1 (production prices baked in)
- ⚠️ **Promotional Text:** paste from §3.2
- ⚠️ **Keywords:** confirm matches §3.3
- ⚠️ **Support URL:** `https://floptimizer.github.io/FLO/contact.html` (§3.4 — CHANGED)
- ⚠️ **Marketing URL:** `https://floptimizer.github.io/FLO/` (§3.5)
- ⚠️ **Privacy Policy URL:** `https://floptimizer.github.io/FLO/privacy.html` (§3.6)
- ⚠️ **Screenshots:** capture 5–7 6.9" iPhone screenshots + 13" iPad Pro screenshots from Build 10 simulator (§5.3)
- ⚠️ **App Review Information:**
  - ✅ Sign-In Required: leave unchecked (already correct)
  - ✅ Contact: leave as-is (Travis Anderson · flo.financeapp@gmail.com)
  - ⚠️ Notes: replace v2.1 block with v3.0 block from §6.2; update any stale price text to production values
- ⚠️ **Build:** wait for Build 10 to finish processing (Xcode → Organizer → Distribute App → upload), select it
- ⚠️ **Age rating:** confirm 4+
- ⚠️ **Pricing & Availability:** Free with IAPs (no change)
- ⚠️ Save
### Phase C — macOS version 3.0 (FIRST macOS submission)
- ⚠️ My Apps → FLO → platform selector → **+ Add Platform** → macOS
- ✅ Bundle ID will resolve to `com.finchandpoppy.flo` (verified in Xcode — macOS target signs with same bundle ID)
- ⚠️ Subtitle: "Finance for freelancers & small business"
- ⚠️ Description / Promo / Keywords / URLs: same as iOS (§3.1–§3.6)
- ⚠️ What's New: same as iOS (§2.3)
- ⚠️ macOS Screenshots: 5–7 at 2880 × 1800 (§5.2)
- ⚠️ App Review Information: mirror iOS (§6.2), add line that macOS uses landscape three-zone sidebar
- ⚠️ Build: upload macOS build (Xcode archive → distribute → Mac App Store), select it
- ⚠️ Pricing & Availability: Free with IAPs (uses same products as iOS)
- ⚠️ Save
### Phase D — Submit for review
- ⚠️ iOS 3.0 → Submit for Review
- ⚠️ macOS 3.0 → Submit for Review
- ⚠️ Email Travis once both are in "Waiting for Review" status
- Average review time: 24–48 hours
### Phase E — Post-approval
- ⚠️ When approved, release manually (don't auto-release)
- ⚠️ Confirm Premium yearly price shows as $59.99 on the live App Store
- ⚠️ Monitor Customer Reviews for the first week
---
## 11. Things Cowork should NOT do
- ❌ Do not change any product IDs
- ❌ Do not modify the iOS app's existing privacy disclosures unless data collection actually changed
- ❌ Do not enable iCloud sharing or any new entitlements without checking with Travis
- ❌ Do not raise prices on existing products — only the Premium yearly DROP is approved
- ❌ Do not delete or archive old versions in App Store Connect
- ❌ Do not respond to App Review communication without Travis's input
- ❌ Do not auto-release when approved — Travis releases manually
---
## 12. Open questions for Travis — all resolved
1. ~~Support email~~ → ✅ `flo.financeapp@gmail.com`
2. ~~Live URLs~~ → ✅ All four legal pages verified live and current
3. ~~Marketing URL homepage~~ → ✅ Live
4. ~~Demo account for review~~ → ✅ Not needed (biometric off by default; ASC notes already cover it; test accounts already in notes for IAP)
5. Screenshots → ⏳ Travis to capture from Build 10 simulator (§5.3) — only remaining manual task before submit
6. ~~App Privacy refresh~~ → ✅ Travis confirmed no changes
7. ~~macOS deployment target = 15.0~~ → ✅ Verified in Xcode
8. ~~Pricing mismatch~~ → ✅ Resolved per §2.1 — StoreKit logs are authoritative, production prices are $7.99/$79.99/$12.99/$99.99 with the Premium yearly drop to $59.99 being the only ASC change
---
## 13. Deferred to Build 11
- Full Liquid Glass pass across every card surface
- Cold-start performance optimization pass
- Dashboard first-render lazy loading
- Memory optimization for MapKit retention
- Resolving the `NSKeyedUnarchiveFromData` deprecation
- Default iPad-portrait layout (currently falls back to phone TabView)
---
## 14. Emergency rollback plan
Pre-approval: Reject Binary → fix → re-upload Build 11 → re-submit.
Post-approval: Remove from Sale → push 3.0.1 hotfix as expedited review (sparingly — Apple grants ~1/year).
---
**End of handoff v2.** Submit Build 10 once screenshots are captured. The §2.1 pricing question is RESOLVED — proceed with the Premium yearly drop from $79.99 to $59.99 as the only ASC price change.
