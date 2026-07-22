# FLO Visual Redesign Brainstorm
**Date:** March 17, 2026
**Purpose:** Evaluate FLO's current visual design, benchmark against leading finance apps, and explore a landscape-first approach informed by Apple's Liquid Glass design language.

---

## Where FLO Stands Today

FLO is a **production-grade SwiftUI app** (iOS 18+, v3.12) with a solid feature set — dashboard, transactions, budgets, invoices, mileage tracking, receipt OCR, tax optimization, Apple Watch, widgets, and more. The foundation is strong. But the visual layer hasn't kept pace with the feature set.

**Current UI characteristics:**

- **Portrait-only**, locked via Info.plist (`UIInterfaceOrientationPortrait`)
- **5-tab navigation** (Dashboard, Transactions, Budgets, Invoices, More) — functional but conventional
- **6 color schemes** (Ocean Teal default, Nature Growth, Warm Prosperity, Ocean Blue, Sunset Amber, Modern Minimal) — nice variety, but the schemes themselves feel flat and utilitarian
- **Card-based layout** with `.floCard()` and `.floGlassCard()` modifiers — the glass card exists but isn't pushed far enough
- **Spring animations** via AnimationService — well-structured but subtle; users may not notice them
- **Dark mode support** exists but isn't a first-class visual experience
- **No landscape support** at all — a missed opportunity for data-rich views

**The gap:** FLO *functions* like a premium finance app but *looks* like a utility. The visual language doesn't communicate the sophistication of what's underneath.

---

## What the Best Finance Apps Are Doing Right

### Robinhood — Bold Minimalism
Robinhood's redesign centers on **black, white, and neutrals** with a single electric accent color ("Robin Neon" yellow-green). Large tap targets, bold headers, generous whitespace. The key insight: **color is used psychologically** — greens for gains, reds for losses, but the UI itself stays neutral so the data pops.

**Takeaway for FLO:** Consider a more restrained base palette where the data itself provides the color.

### Copilot Money — "Flashy but Functional"
Often called the best-looking budgeting app. Smooth animations, contemporary card layouts, and a UI that feels more like a lifestyle app than a finance tool. Takes design cues from Robinhood's playbook but adds more visual flair.

**Takeaway for FLO:** Elevate the dashboard from "information display" to "experience." Users should *want* to open the app.

### Monarch Money — Intuitive Clarity
Clean design with seamless cross-platform feel. Every piece of the product shows attention to detail. Clear visual representation of income, expenses, and savings without clutter.

**Takeaway for FLO:** Simplify information density. FLO's dashboard currently has 10+ card types — that's a lot to parse. Prioritize and layer.

### Revolut / N26 — European Sophistication
Sleek, dark-first interfaces with bold typography and subtle depth. N26's distinctive approach to financial visibility makes complex banking feel approachable.

**Takeaway for FLO:** Dark mode shouldn't be an afterthought — it should be the *showcase* mode.

---

## Apple Liquid Glass — What It Means for FLO

Liquid Glass (introduced WWDC 2025, now standard in iOS 26) isn't just a visual effect — it's a design philosophy built around **translucency, depth, and dynamic responsiveness**.

### Core Principles

1. **Optical realism** — Elements refract and reflect content behind them. Light shifts with device motion.
2. **Material variants** — "Regular" (adaptive, morphs with interaction) and "Clear" (permanently transparent with dimming).
3. **Layered depth** — Thicker glass = deeper shadows and more pronounced lensing. Soft shadows establish visual hierarchy.
4. **Dynamic response** — Elements materialize gracefully, flex with interaction, energize with light.

### Why This Matters for FLO

FLO already has `.floGlassCard()` — but it's a static frosted effect. Liquid Glass is *alive*. With iOS 26's native APIs, FLO can adopt these materials at the system level, which means:

- **Cards that breathe** — financial summary cards with true depth, reacting to scroll position and touch
- **Tab bar transformation** — Apple's redesigned tab bars use Liquid Glass; FLO's 5-tab nav gets this for free if built with system components
- **Layered dashboards** — foreground cards with actual optical depth over background content, creating a sense of looking *through* financial data
- **Motion-aware highlights** — subtle light shifts as the user tilts their device, reinforcing that FLO feels premium

### The Caution

The industry consensus for 2026 is clear: "glassmorphism for the sake of glassmorphism" is being rejected. Glass should be **intentional** — used to create hierarchy, guide focus, and communicate trust. Not decoration.

---

## The Landscape Opportunity

This is where FLO could genuinely differentiate.

### The Problem with Portrait-Only

FLO's dashboard crams 10+ card types into a portrait scroll. Financial data — especially tables, charts, and multi-account views — naturally wants horizontal space. Portrait mode forces:

- Truncated account names
- Compressed chart axes
- Stacked information that requires endless scrolling
- No ability to compare data side-by-side

### What Landscape Unlocks

#### 1. Split-View Dashboard
**Left panel:** Navigation + account selector
**Right panel:** Active content (charts, transaction lists, budget progress)

Think of it like a mini iPad experience on iPhone. The user rotates to "work mode" — a deliberate action that signals "I want to dig into my finances."

#### 2. Full-Width Data Visualization
- **Line charts** showing 12-month trends without compression
- **Cash flow forecasts** with proper time-axis resolution
- **Budget progress bars** showing all categories simultaneously instead of scrolling through them
- **Income vs. expense comparison** side-by-side

#### 3. Transaction Table View
Landscape could enable a proper **spreadsheet-like transaction view** — date, payee, category, amount, and balance all visible in one row. This is something no major budgeting app does well on mobile.

#### 4. Invoice Preview
Invoices are inherently landscape documents. A landscape preview mode would let users see their invoice exactly as clients will see it.

#### 5. Report Viewing
FLO generates comprehensive PDF reports. Landscape mode is the natural orientation for reviewing financial reports on a phone.

### The UX Model: Orientation as Mode Switch

Rather than just "supporting" landscape, make it **intentional**:

- **Portrait** = Quick glance, daily check-in, transaction entry, receipt scanning
- **Landscape** = Deep analysis, data exploration, report review, invoice management

This creates a natural **two-tier experience** without adding navigation complexity. The physical act of rotating the phone becomes the mode switch.

---

## Design Direction Proposals

### Direction A: "Liquid Finance"
Fully embrace Liquid Glass. Translucent cards over dynamic gradient backgrounds. Light, airy, premium. The dashboard feels like looking through layers of financial data.

- **Pros:** Aligns perfectly with iOS 26 direction, feels native and premium, future-proof
- **Cons:** Requires careful contrast management, may feel too "light" for users who want data density
- **Inspiration:** Apple's own apps in iOS 26, visionOS aesthetic

### Direction B: "Dark Canvas"
Dark-first design with Liquid Glass accents. Think Robinhood meets Revolut — a rich dark background where financial data glows. Glass effects used selectively on cards and overlays.

- **Pros:** 82% of users already prefer dark mode, data and charts pop against dark backgrounds, feels sophisticated
- **Cons:** Needs careful handling of Liquid Glass in dark contexts, accessibility requires extra attention
- **Inspiration:** Robinhood, Revolut, trading platforms

### Direction C: "Adaptive Depth"
Context-aware design that shifts based on what the user is doing. Light and airy for quick check-ins (portrait), deeper and data-focused for analysis (landscape). Glass materials intensify as you go deeper into financial detail.

- **Pros:** Best of both worlds, the landscape mode switch becomes a visual transformation, matches user intent
- **Cons:** Most complex to implement, two visual states to maintain
- **Inspiration:** iPadOS adaptive layouts, visionOS depth model

### Recommended: Direction C with Direction B as the default palette

This gives FLO a **dark, premium base** (matching what top finance apps are doing) with an **adaptive depth system** that makes the portrait-to-landscape rotation feel like a deliberate upgrade to "power mode." Liquid Glass is used intentionally — on cards, overlays, and navigation — not everywhere.

---

## Specific Visual Improvements to Consider

### Dashboard Overhaul
- **Reduce default card count** — Show 4-5 priority cards; others accessible via scroll or "More Insights"
- **Hero metric** — One large, animated number at the top (net worth, monthly cash flow, or budget remaining) that the user can customize
- **Micro-interactions on data changes** — When a new transaction comes in, the relevant numbers animate to their new values
- **Contextual color** — Cards subtly tint based on financial health (green glow when under budget, amber when approaching limits)

### Typography & Spacing
- **Larger, bolder headers** — Current `.floLargeTitle()` could go bigger
- **More whitespace between cards** — Let the content breathe
- **Monospaced numbers** for financial figures — improves scanability of tables and lists
- **Variable font weights** — Use thin weights for labels, bold for amounts

### Chart & Data Visualization
- **Animated chart rendering** — Charts draw themselves on first appearance
- **Interactive touch points** — Tap/hold on chart points for detailed tooltips
- **Gradient fills under line charts** — Subtle depth that reinforces the Liquid Glass aesthetic
- **Sparklines** in compact views — Mini trend lines next to account balances

### Color System Evolution
- **Reduce the 6 schemes to 3 refined options** — Light, Dark, and Auto (matches system)
- **Accent color customization** — Let users pick their own accent color (like Apple does)
- **Semantic color refinement** — Income green and expense red are standard, but add gradient variants for visual interest
- **Ambient color** — Subtle background gradients that shift based on financial health or time of day

### Animation Upgrades
- **Card entrance animations** — Staggered reveal when opening dashboard
- **Number counting animations** — Balances count up/down to their current value
- **Parallax depth on scroll** — Background elements move slower than foreground cards
- **Celebration moments** — FLO already has `IncomeCelebration`; extend this concept to milestones (paid off a debt, hit a savings goal, stayed under budget for a month)

### Landscape-Specific UI
- **Sidebar navigation** replacing bottom tabs
- **Master-detail layout** for transactions and invoices
- **Full-width chart mode** with interactive controls
- **Multi-column budget view** showing all categories at once
- **Side-by-side account comparison**

---

## Competitive Gap Analysis

| Feature | FLO Today | Robinhood | Copilot | Monarch | Opportunity |
|---|---|---|---|---|---|
| Dark mode quality | Basic swap | Premium | Premium | Good | High |
| Glassmorphism / Liquid Glass | Static `.floGlassCard()` | None | Subtle | None | High — first mover |
| Landscape support | None | Charts only | None | None | Very High — unique differentiator |
| Data visualization | Basic charts | Excellent | Very Good | Good | High |
| Micro-interactions | Spring animations exist | Polished | Polished | Moderate | Medium |
| Card layout sophistication | Functional | Refined | Refined | Clean | Medium |
| Typography hierarchy | Adequate | Bold | Modern | Clean | Medium |
| Onboarding visual quality | Standard forms | Excellent | Good | Good | Medium |
| Celebration / delight moments | Income only | Trading wins | Subtle | Minimal | Medium |
| Color customization | 6 fixed schemes | None | Minimal | Minimal | Medium — simplify and refine |

---

## Next Steps (When Ready to Execute)

1. **Create visual mockups** — Build a few SwiftUI prototype views to test Direction C (Dark Canvas + Adaptive Depth) before committing
2. **Audit the dashboard** — Prioritize which cards should be default vs. hidden, and design the "hero metric" component
3. **Landscape prototype** — Start with one screen (Dashboard or Transactions) to prove the split-view concept
4. **iOS 26 Liquid Glass adoption** — Audit which existing components can adopt system materials vs. custom implementations
5. **Dark mode refinement pass** — Treat dark mode as the primary visual target, not an afterthought
6. **User testing** — If possible, get feedback on the landscape concept from existing users before building it out

---

*This document is a living brainstorm — add notes, cross things out, circle what excites you. No code changes until the direction is locked.*
