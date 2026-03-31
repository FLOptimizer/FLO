# FLO v2.0 Build 8 - Release Notes

## App Store Release Notes

### What's New in FLO 2.0

**Smart Recurring Detection**
FLO now automatically analyzes your transaction history to detect recurring bills and income patterns. Get notified when we find a pattern you haven't tracked yet, and add it as a recurring transaction with one tap.

**Cash Flow Forecasting**
See where your money is heading with our new cash flow projection engine. View projected balances for 1, 3, 6, or 12 months, spot low-balance danger zones before they happen, and stay on top of upcoming bills.

**Household Sharing**
Share your financial data with family members. Create a household, invite members with role-based permissions, and collaborate on budgeting and expense tracking together.

**iCloud Sync**
Your financial data now syncs across all your Apple devices via iCloud. Start on your iPhone, continue on your iPad — everything stays in sync automatically.

**App Clip Invoice Generator**
Generate and share professional invoices instantly without installing the full app. Perfect for quick invoicing on the go.

**Bug Fixes & Improvements**
- Fixed transaction list not refreshing after delete
- Improved Plaid bank connection stability
- Enhanced accessibility across all new features
- Performance optimizations for app startup

---

## Internal Build Notes

### Build 8 Features Completed
1. Transactions tab memory fix (loadTransactions in performDelete)
2. Auto-Recurring Detection engine + UI (RecurringDetectionService, RecurringDetectionView, DetectedPatternsSection)
3. Cash Flow Forecasting (CashFlowForecastService, CashFlowForecastView, dashboard card)
4. Household Sharing foundation (Household model, HouseholdService, HouseholdSettingsView)
5. iCloud Sync (CloudSyncService activation)
6. App Clip Invoice Generator (FLOInvoiceClip - requires Xcode target setup)
7. Accessibility audit on 3 new feature views
8. Unit tests for 3 new services (30 test files total)

### Build Configuration
- Marketing Version: 2.0
- Build Number: 8
- Minimum iOS: 18.5
- Bundle ID: com.finchandpoppy.flo

### TestFlight Checklist
- [ ] Verify all features on physical device
- [ ] Test iCloud sync between devices
- [ ] Verify Plaid connection works in TestFlight environment
- [ ] Test recurring detection with real transaction data
- [ ] Verify cash flow forecast generates correctly
- [ ] Test household creation and member management
- [ ] Run VoiceOver walkthrough on new features
- [ ] Check Dynamic Type at large sizes
- [ ] Archive and upload to App Store Connect
- [ ] Add App Clip target in Xcode (File > New > Target > App Clip)

### App Clip Setup Instructions
The App Clip source files are in `/FLOInvoiceClip/`. To add the target:
1. Open FLO.xcodeproj in Xcode
2. File > New > Target > App Clip
3. Name: FLOInvoiceClip
4. Bundle ID: com.finchandpoppy.flo.Clip
5. Add the 3 Swift files from /FLOInvoiceClip/ to the new target
6. Add shared files to the App Clip target membership:
   - Models: Invoice.swift, InvoiceTypes.swift, InvoicePayment.swift, Client.swift, Account.swift, Transaction.swift, Category.swift, RecurringTransaction.swift, BusinessProfile.swift
   - Services: InvoiceService.swift, HapticService.swift
   - Extensions: AccessibilityHelpers.swift
   - Helpers: Color+Extensions (for Color.brandPrimary), FLOAnimation
7. Set the App Clip entitlements file
8. Configure Associated Domains in App Store Connect
