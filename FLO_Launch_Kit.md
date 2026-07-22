# FLO 3.0 Launch Kit — Product Hunt + Reddit
> Drafts for Travis to review, personalize, and post. Written 2026-07-22.
> Voice check before posting: these are written in your voice as a solo founder — adjust anything that doesn't sound like you. Authenticity outperforms polish on both platforms.

---

## 1. Product Hunt

### Logistics
- **Best days:** Tuesday–Thursday. Launch at 12:01 AM Pacific — the 24-hour leaderboard clock starts then; late-day launches compete with a head start against you.
- **Before launch day:** complete your PH maker profile, and line up 3–5 friends/family to genuinely try the app and comment questions on launch day (PH weights engagement, and early comments seed discussion). Do NOT solicit upvotes — PH detects and penalizes it.
- **On launch day:** reply to every single comment, fast. Maker responsiveness visibly drives ranking.
- **Ship it when build 12 is live** — the free tier with balance tracking, the trial CTAs, and the explore tour are the version worth showing.

### Listing
- **Name:** FLO — Finance Ledger Optimizer
- **Tagline (60 chars max):** `The finance app that keeps freelancers tax-ready` (48)
- **Alternate taglines:**
  - `Freelancer finances, taxes, and mileage — on autopilot` (54)
  - `Track every dollar and mile. Hand your CPA a tidy package.` (58)
- **Description (260 chars max):**
  `FLO tracks freelancer finances end-to-end: scan receipts with AI, auto-track business mileage by GPS, watch live quarterly tax estimates, and send invoices. Privacy-first — everything syncs through iCloud, no accounts, no tracking. iPhone, iPad, Mac & Watch.` (256)
- **Topics:** Finance, iOS, Mac, Productivity, Bootstrapped
- **Links:** App Store `https://apps.apple.com/us/app/finance-ledger-optimizer/id6756789373` · Site `https://floptimizer.github.io/FLO/`
- **Gallery:** reuse the 5–7 App Store screenshots (§5.3 of the handoff doc) + 1–2 macOS three-zone shots. First image decides the click — use the dashboard or the receipt scanner mid-capture, not a settings screen.

### Maker's first comment (post immediately after launch goes live)
> Hi PH! I'm Travis, a solo developer, and FLO is the finance app I built because I needed it.
>
> If you freelance or run a small business, you know the drill: income from five places, receipts in a shoebox, mileage you swear you'll log next week, and a quarterly tax deadline you find out about two days late.
>
> FLO handles that whole loop:
> • **Scan a receipt** and it reads the merchant, amount, tax, and tip — then files it as a categorized transaction (free, unlimited)
> • **Drive** and it logs your business miles by GPS — every mile is worth $0.725 off your 2026 taxes
> • **Watch your quarterly tax estimate** update live from your actual income, with reminders before each IRS deadline
> • **Invoice clients** and see cash flow update the moment they pay
>
> 3.0 is the biggest release yet — full macOS app with a three-zone layout, a visual redesign, and a much more generous free tier (balance tracking and account management are now free for everyone).
>
> Privacy matters to me: FLO has no accounts, no tracking, no ads, no data brokers. Everything syncs through your own iCloud.
>
> I'd genuinely love feedback — especially from freelancers whose tax season is still a shoebox. I'll be here all day answering questions. 🙏

---

## 2. Reddit

**The rules that matter:** Reddit converts through credibility, not promotion. Post value first; mention the app only where self-promo is allowed or when directly asked. **Check each subreddit's current self-promo rules before posting** — getting banned in r/freelance costs more than a post is worth. Never post the same text to multiple subs on the same day.

### Post A — r/SideProject or r/iosapps (self-promo welcome; build-in-public angle)
**Title:** `After 12 builds, my freelancer finance app just shipped its biggest release — a full macOS version and a redesign`
> Solo dev here. FLO started because I was freelancing and my "bookkeeping" was a shoebox of receipts and a panicked April. Three years later it's a full finance app for self-employed people: AI receipt scanning, GPS mileage tracking (every mile is $0.725 off your taxes in 2026), live quarterly tax estimates, and invoicing.
>
> 3.0 just shipped: native macOS app, complete redesign, and I moved a bunch of paid features into the free tier — I'd rather have users who love it than a paywall nobody crosses.
>
> Stack for the curious: 100% SwiftUI, SwiftData with CloudKit sync (no accounts, no backend for your data), on-device ML for receipt parsing. Privacy-first because it's my data too.
>
> Happy to answer anything about the app or about shipping an indie finance app in general. [App Store link in comments per sub rules.]

### Post B — r/freelance or r/smallbusiness (VALUE POST — no link in the post)
**Title:** `PSA: Q3 estimated taxes are due September 15 — and the "safe harbor" rule that saves you from penalties`
> Since I see this trip people up every quarter: if you're self-employed and expect to owe $1,000+ in federal tax, the IRS wants four payments a year, not one. The 2026 dates: April 15, June 15, September 15, and January 15 (2027). Note Q2 covers only two months — that surprises everyone their first year.
>
> The part most freelancers don't know: **safe harbor**. You owe zero underpayment penalties if you pay either 90% of this year's tax or 100% of last year's (110% if you made over $150k last year). If your income is lumpy, paying to last year's number is the predictable way to stay penalty-free and settle up in April.
>
> Also, log your business miles — the 2026 rate is $0.725/mile, and 10,000 business miles is a $7,250 deduction. The IRS wants a contemporaneous log (date, destination, purpose, miles), not a reconstructed guess in April.
>
> Not a tax pro, just a fellow self-employed person who learned this the expensive way. Verify with your CPA.

**Engagement rule for Post B:** mention FLO **only** if someone asks how you track this stuff ("I actually built an app for this — happy to share if mods allow"). The post earns trust; the comments convert it. If the sub allows a profile link, keep the App Store link there.

### Post C — r/Entrepreneur (story angle; check self-promo rules first)
**Title:** `I moved my app's core features from paid to free after 0 conversions — here's the reasoning`
> My finance app for freelancers had a classic freemium structure: free tier for basics, pay to unlock the good stuff. Conversions were zero. Not low — zero.
>
> The uncomfortable realization: my free tier was hiding the app's core value (you literally couldn't see your account balances without paying), so nobody stayed long enough to want the paid features. People upgrade to *extend* an app they trust — nobody upgrades to *unhobble* an app that frustrated them.
>
> So I inverted it: the complete core loop is now free (balances, accounts, receipt scanning), and the paid tiers sell scale and automation (GPS mileage, live tax estimates, bank sync). Early days, but engagement is already different.
>
> Sharing because I suspect a lot of indie apps die from over-gating, not under-pricing. Happy to go deeper on any of it.

---

## 3. Bonus: short social posts (X / Threads / Instagram caption)
1. `Every business mile you drive in 2026 is worth $0.725 off your taxes. FLO logs them automatically while you drive. [App Store link]`
2. `Freelancers: Q3 estimated taxes are due Sept 15. FLO watches your income and tells you what to send the IRS — before the deadline, not after. [link]`
3. `FLO 3.0 is live: full Mac app, redesigned everything, and balance tracking is now free for everyone. [link]`

---

## 4. Sequencing recommendation
1. Submit build 12 → wait for approval and release
2. Post B (Reddit value post) any time — it builds karma/credibility with zero risk (Sept 1–14 is the perfect window for the Q3 angle)
3. Product Hunt launch on a Tue–Thu after build 12 is live
4. Post A (r/SideProject) the same week as the PH launch — cross-momentum
5. Post C (r/Entrepreneur) a week or two later, once there's a data point to share
