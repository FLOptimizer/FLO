//  FLODemoTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Fixed Scene 23 Credit Card button off-screen crash
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: XCUITest suite for automated demo video recording.
//  Each test method is a self-contained "scene" that demonstrates
//  a specific FLO feature. Run with record_demos.sh to capture
//  simulator video for each test.
//
//  TARGET: FLOUITests
//
//  USAGE:
//  1. Run individual tests in Xcode for development/preview
//  2. Run record_demos.sh for batch video capture with simctl
//  3. Videos saved to ~/FLO_Demo_Videos/
//
//  DEMO PERSONA:
//  Name: Alex Rivera
//  Business: Rivera Design Co — Freelance Graphic Designer
//  Location: Austin, TX
//  Bank: First National Bank (checking ****4567)
//  Income: $4,000-6,000/month from design clients
//
//  PACING GUIDE:
//  - demoWait(.brief)    = 0.5s — between rapid taps
//  - demoWait(.normal)   = 1.0s — standard pause between actions
//  - demoWait(.readable) = 2.0s — pause on results so viewer can read
//  - demoWait(.hero)     = 3.0s — hero moment (dashboard loaded, report generated)
//
//  CHANGES v2.0:
//  ✅ REWRITTEN: Scene 03 — now fills in amount, merchant, classification, saves
//  ✅ REWRITTEN: Scene 05 — now enters budget amount, shows form, saves
//  ✅ REWRITTEN: Scene 07 — now fills invoice form fields, scrolls through
//  ✅ REWRITTEN: Scene 11 — now enters trip distance, addresses, purpose
//  ✅ REWRITTEN: Scene 14 — now switches chart types and time periods
//  ✅ IMPROVED: Scene 02 — taps into a dashboard card for detail
//  ✅ IMPROVED: Scene 04 — taps transaction for detail, navigates back
//  ✅ IMPROVED: Scene 06 — taps budget for spending detail
//  ✅ IMPROVED: Scene 08 — taps invoice to show full detail view
//  ✅ IMPROVED: Scene 10 — scrolls trip list, taps a trip for detail
//  ✅ IMPROVED: Scene 13 — scrolls and taps deduction categories
//  ✅ IMPROVED: Scene 17 — taps theme options to show switching
//  ✅ NEW: Scene 21 — Receipt Scanning (SmartReceiptScanningView)
//  ✅ NEW: Scene 22 — Credit Card Management (accounts + utilization)
//  ✅ NEW: Scene 23 — Debt Payoff Calculator (fills form, calculates savings)
//  ✅ NEW: Scene 24 — Export Options (PDF/CSV export)
//  ✅ NEW: Scene 25 — Profit & Loss Report
//  ✅ NEW: Scene 26 — Year-End Tax Checklist (taps items)
//  ✅ NEW: Scene 27 — Move Money / Transfers (enters amount)
//  ✅ NEW: Scene 28 — Business Profile Setup (fills name, email)
//  ✅ NEW: Scene 29 — Tax Settings (filing status, state)
//  ✅ NEW: Scene 30 — Money Moves Insights (dashboard cards)
//  ✅ NEW: Scene 31 — Security & Passcode
//  ✅ NEW: Scene 32 — Comprehensive CPA Report (selects type)
//  ✅ NEW: Scene 33 — Edit Transaction Detail (opens edit form)
//  ✅ NEW: Scene 34 — Invoice Detail View (full scroll-through)
//  ✅ NEW: Scene 35 — Budget History (past months)
//  ✅ NEW: Scene 36 — Receipt Matching Queue
//  ✅ NEW: Scene 37 — Split Receipt
//  ✅ NEW: Scene 38 — Quick Actions (taps each shortcut)
//  ✅ UNCHANGED: Scenes 01, 09, 12, 15, 16, 18, 19, 20

import XCTest

// MARK: - Demo Pacing

/// Pacing durations tuned for video readability.
/// UI tests run too fast for viewers — these pauses make the flow followable.
enum DemoPacing: TimeInterval {
    case brief    = 0.5   // Quick transition between taps
    case normal   = 1.0   // Standard pause — viewer tracks what happened
    case readable = 2.0   // Let viewer read a result or form state
    case hero     = 3.0   // Showcase moment — dashboard, report, completion
    case intro    = 1.5   // Opening beat before first action
}

// MARK: - Demo Test Suite

final class FLODemoTests: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = true  // Don't stop video on minor assertion failures
        
        app = XCUIApplication()
        // Base demo arguments — individual tests add more as needed
        app.launchArguments = [
            "UI_TESTING",
            "DEMO_MODE",
            "DEMO_SKIP_AUTH",
            "DEMO_CLEAN_STATE"
        ]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helpers
    
    /// Pace the demo with a descriptive wait
    private func demoWait(_ pacing: DemoPacing, label: String = "") {
        if !label.isEmpty {
            print("🎬 [\(pacing)] \(label)")
        }
        Thread.sleep(forTimeInterval: pacing.rawValue)
    }
    
    /// Wait for element to appear, then return it
    @discardableResult
    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5, label: String = "") -> XCUIElement {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists && !label.isEmpty {
            print("🎬 ⚠️ Element not found: \(label)")
        }
        return element
    }
    
    /// Navigate to a specific tab by index (0-based)
    private func navigateToTab(_ index: Int) {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }
        let buttons = tabBar.buttons.allElementsBoundByIndex
        guard index < buttons.count else { return }
        buttons[index].tap()
        demoWait(.normal, label: "Tab \(index) selected")
    }
    
    /// Navigate to Dashboard tab (index 0)
    private func navigateToDashboard() { navigateToTab(0) }
    
    /// Navigate to Transactions tab (index 1)
    private func navigateToTransactions() { navigateToTab(1) }
    
    /// Navigate to Budgets tab (index 2)
    private func navigateToBudgets() { navigateToTab(2) }
    
    /// Navigate to Invoices tab (index 3)
    private func navigateToInvoices() { navigateToTab(3) }
    
    /// Navigate to More tab (index 4)
    private func navigateToMore() { navigateToTab(4) }
    
    /// Dismiss any presented sheet
    private func dismissSheet() {
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 1) {
            cancelButton.tap()
            demoWait(.brief)
            return
        }
        let closeButton = app.buttons["Close"]
        if closeButton.waitForExistence(timeout: 0.5) {
            closeButton.tap()
            demoWait(.brief)
            return
        }
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 0.5) {
            doneButton.tap()
            demoWait(.brief)
            return
        }
        app.swipeDown(velocity: .fast)
        demoWait(.brief)
    }
    
    /// Type text into a text field with visible character-by-character entry
    private func demoType(_ element: XCUIElement, text: String) {
        // Guard against invalid frame dimensions (negative or non-finite)
        let frame = element.frame
        guard frame.width > 0, frame.height > 0,
              frame.width.isFinite, frame.height.isFinite,
              element.isHittable else {
            // Fallback: use coordinate-based tap to avoid crash
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
            demoWait(.brief)
            element.typeText(text)
            demoWait(.brief)
            return
        }
        element.tap()
        demoWait(.brief)
        element.typeText(text)
        demoWait(.brief)
    }
    
    /// Scroll down to show more content
    private func scrollDown(times: Int = 1) {
        for _ in 0..<times {
            // Ensure app window has valid frame before scrolling
            guard app.exists, app.frame.width > 0, app.frame.height > 0 else {
                print("⚠️ Skipping scroll - app frame not valid")
                return
            }
            app.swipeUp(velocity: .slow)
            demoWait(.brief)
        }
    }
    
    /// Scroll up to show top content
    private func scrollUp(times: Int = 1) {
        for _ in 0..<times {
            // Ensure app window has valid frame before scrolling
            guard app.exists, app.frame.width > 0, app.frame.height > 0 else {
                print("⚠️ Skipping scroll - app frame not valid")
                return
            }
            app.swipeDown(velocity: .slow)
            demoWait(.brief)
        }
    }
    
    /// Launch app with specific additional arguments
    private func launchApp(additionalArgs: [String] = []) {
        var args = app.launchArguments
        args.append(contentsOf: additionalArgs)
        app.launchArguments = args
        app.launch()
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        demoWait(.intro, label: "App launched")
    }
    
    /// Launch app expecting onboarding (no tab bar yet)
    private func launchAppForOnboarding() {
        app.launchArguments.append("DEMO_SHOW_ONBOARDING")
        app.launchArguments.removeAll { $0 == "DEMO_SKIP_ONBOARDING" }
        app.launch()
        demoWait(.intro, label: "App launched for onboarding")
    }
    
    /// Launch app with dashboard ready (skip onboarding)
    private func launchAppForDashboard(tier: String = "DEMO_PRO_TIER") {
        launchApp(additionalArgs: ["DEMO_SKIP_ONBOARDING", tier])
    }
    
    /// Navigate back using navigation bar back button
    private func navigateBack() {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()
            demoWait(.normal)
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 01: Onboarding Flow
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: First launch experience — swipe through all 4 onboarding pages
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_01_OnboardingFlow() throws {
        print("🎬 ═══ SCENE 01: Onboarding Flow ═══")
        launchAppForOnboarding()
        
        let welcomeText = app.staticTexts["Welcome to FLO"]
        waitFor(welcomeText, label: "Welcome page")
        demoWait(.hero, label: "Welcome screen — hero moment")
        
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()
            demoWait(.readable, label: "FLO in Action page")
        }
        
        demoWait(.readable, label: "Viewing feature carousel")
        
        if nextButton.waitForExistence(timeout: 2) {
            nextButton.tap()
            demoWait(.readable, label: "Built for You page")
        }
        
        demoWait(.readable, label: "Viewing value proposition")
        
        if nextButton.waitForExistence(timeout: 2) {
            nextButton.tap()
            demoWait(.readable, label: "Get Started page")
        }
        
        let letsGoButton = app.buttons["Let's Go!"]
        if letsGoButton.waitForExistence(timeout: 3) {
            demoWait(.normal, label: "About to tap Let's Go")
            letsGoButton.tap()
        }
        
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 5)
        demoWait(.hero, label: "Dashboard revealed — onboarding complete")
        
        print("🎬 ═══ SCENE 01 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 02: Dashboard Tour  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_02_DashboardTour() throws {
        print("🎬 ═══ SCENE 02: Dashboard Tour ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.hero, label: "Dashboard loaded — showcase moment")
        
        scrollDown()
        demoWait(.readable, label: "Viewing balance cards")
        
        scrollDown()
        demoWait(.readable, label: "Viewing recent transactions")
        
        // Tap a recent transaction to show interactivity
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.readable, label: "Transaction detail from dashboard")
            navigateBack()
            demoWait(.normal)
        }
        
        scrollDown()
        demoWait(.readable, label: "Viewing budget overview card")
        
        scrollDown()
        demoWait(.readable, label: "Viewing tax estimate / insights")
        
        scrollUp(times: 4)
        demoWait(.hero, label: "Back at dashboard top")
        
        print("🎬 ═══ SCENE 02 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 03: Adding a Transaction  [REWRITTEN v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_03_AddTransaction() throws {
        print("🎬 ═══ SCENE 03: Adding a Transaction ═══")
        launchAppForDashboard()
        
        navigateToTransactions()
        demoWait(.readable, label: "Transaction list loaded")
        
        let addButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] 'new' OR label == '+'")
        ).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            demoWait(.normal, label: "Add Transaction sheet appeared")
        }
        
        // Enter amount using accessibility label
        let amountField = app.textFields["Transaction amount"]
        if amountField.waitForExistence(timeout: 3) {
            demoType(amountField, text: "127.50")
            demoWait(.readable, label: "Amount entered: $127.50")
        } else {
            let firstField = app.textFields.firstMatch
            if firstField.waitForExistence(timeout: 2) {
                demoType(firstField, text: "127.50")
                demoWait(.readable, label: "Amount entered via fallback")
            }
        }
        
        // Tap Business classification
        let businessSegment = app.buttons["Business"]
        if businessSegment.waitForExistence(timeout: 2) {
            businessSegment.tap()
            demoWait(.normal, label: "Set to Business expense — tax deductible!")
        }
        
        // Wait a bit before scrolling to ensure sheet is fully presented
        demoWait(.brief)
        scrollDown()
        demoWait(.normal)
        
        // Enter merchant name
        let merchantField = app.textFields["Merchant name"]
        if merchantField.waitForExistence(timeout: 3) {
            demoType(merchantField, text: "Adobe Creative Cloud")
            demoWait(.readable, label: "Merchant: Adobe Creative Cloud")
        } else {
            let fallback = app.textFields["Merchant Name"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "Adobe Creative Cloud")
                demoWait(.readable, label: "Merchant entered via fallback")
            }
        }
        
        demoWait(.readable, label: "Form filled — ready to save")
        
        let saveButton = app.buttons["Save"]
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
            demoWait(.normal, label: "Transaction saved!")
        }
        
        demoWait(.hero, label: "Transaction list updated with new entry")
        
        print("🎬 ═══ SCENE 03 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 04: Transaction List  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_04_TransactionList() throws {
        print("🎬 ═══ SCENE 04: Transaction List ═══")
        launchAppForDashboard()
        
        navigateToTransactions()
        demoWait(.hero, label: "Transaction list loaded")
        
        scrollDown()
        demoWait(.readable, label: "Browsing transactions")
        
        scrollDown()
        demoWait(.readable, label: "More transactions")
        
        scrollUp(times: 2)
        demoWait(.normal, label: "Back at top")
        
        // Tap a transaction to show detail view
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            demoWait(.hero, label: "Transaction detail view — full info")
            
            scrollDown()
            demoWait(.readable, label: "Category, account, notes, receipt")
            
            scrollUp()
            navigateBack()
        }
        
        demoWait(.hero, label: "Transaction list — scene complete")
        
        print("🎬 ═══ SCENE 04 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 05: Creating a Budget  [REWRITTEN v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_05_CreateBudget() throws {
        print("🎬 ═══ SCENE 05: Creating a Budget ═══")
        launchAppForDashboard()
        
        navigateToBudgets()
        demoWait(.readable, label: "Budgets list loaded")
        
        scrollDown()
        demoWait(.readable, label: "Existing budgets with progress bars")
        scrollUp()
        
        let addButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] 'new' OR label CONTAINS[c] 'create' OR label == '+'")
        ).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            demoWait(.readable, label: "Create Budget form appeared")
        }
        
        // Enter budget amount
        let amountField = app.textFields["Budget amount in dollars"]
        if amountField.waitForExistence(timeout: 3) {
            demoType(amountField, text: "500")
            demoWait(.readable, label: "Budget amount: $500/month")
        } else {
            let fallback = app.textFields["0.00"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "500")
                demoWait(.readable, label: "Budget amount entered via fallback")
            }
        }
        
        // Tap Business segment (use identifier to avoid matching background filter)
        let formSegments = app.collectionViews.segmentedControls.buttons["Business"]
        let fallbackBusiness = app.buttons.matching(identifier: "briefcase.fill").firstMatch
        if formSegments.waitForExistence(timeout: 2) {
            formSegments.tap()
            demoWait(.normal, label: "Set to Business classification")
        } else if fallbackBusiness.waitForExistence(timeout: 2) {
            fallbackBusiness.tap()
            demoWait(.normal, label: "Set to Business classification")
        }
        
        scrollDown()
        demoWait(.readable, label: "Category and account selection")
        
        scrollUp()
        demoWait(.readable, label: "Budget form complete — monthly limit set")
        
        dismissSheet()
        demoWait(.hero, label: "Back to budget list")
        
        print("🎬 ═══ SCENE 05 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 06: Budget Overview  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_06_BudgetOverview() throws {
        print("🎬 ═══ SCENE 06: Budget Overview ═══")
        launchAppForDashboard()
        
        navigateToBudgets()
        demoWait(.hero, label: "Budgets with progress bars")
        
        scrollDown()
        demoWait(.readable, label: "Budget spending progress — visual tracking")
        
        scrollDown()
        demoWait(.readable, label: "More budget categories")
        
        scrollUp(times: 2)
        demoWait(.normal)
        
        // Tap a budget to see spending detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.hero, label: "Budget detail — spending breakdown")
            
            scrollDown()
            demoWait(.readable, label: "Transactions counted against this budget")
            
            scrollUp()
            navigateBack()
        }
        
        demoWait(.hero, label: "Budget overview — scene complete")
        
        print("🎬 ═══ SCENE 06 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 07: Creating an Invoice  [REWRITTEN v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_07_CreateInvoice() throws {
        print("🎬 ═══ SCENE 07: Creating an Invoice ═══")
        launchAppForDashboard()
        
        navigateToInvoices()
        demoWait(.readable, label: "Invoice list loaded")
        
        let addButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] 'new' OR label CONTAINS[c] 'create' OR label == '+'")
        ).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            demoWait(.readable, label: "Create Invoice form appeared")
        }
        
        // Fill in invoice number
        let textFields = app.textFields.allElementsBoundByIndex
        if textFields.count > 0 {
            let firstField = textFields[0]
            firstField.tap()
            demoWait(.brief)
            firstField.typeText("INV-2026-015")
            demoWait(.readable, label: "Invoice number entered")
        }
        
        scrollDown()
        demoWait(.readable, label: "Invoice line items — add services and products")
        
        scrollDown()
        demoWait(.readable, label: "Subtotal, tax, and total")
        
        scrollDown()
        demoWait(.readable, label: "Payment terms and due date")
        
        scrollUp(times: 3)
        demoWait(.readable, label: "Complete invoice form")
        
        dismissSheet()
        demoWait(.normal)
        
        // Tap an existing invoice to show detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.hero, label: "Invoice detail — professional PDF-ready format")
            
            scrollDown()
            demoWait(.readable, label: "Line items and totals")
            
            scrollDown()
            demoWait(.readable, label: "Payment status and actions")
            
            navigateBack()
        }
        
        print("🎬 ═══ SCENE 07 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 08: Invoice Tracking  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_08_InvoiceTracking() throws {
        print("🎬 ═══ SCENE 08: Invoice Status Tracking ═══")
        launchAppForDashboard()
        
        navigateToInvoices()
        demoWait(.hero, label: "Invoice list with status indicators")
        
        scrollDown()
        demoWait(.readable, label: "Draft, Sent, Paid, Overdue statuses")
        
        scrollUp()
        demoWait(.normal)
        
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.hero, label: "Invoice detail — amounts, dates, payment history")
            
            scrollDown()
            demoWait(.readable, label: "Actions — mark as sent, record payment")
            
            scrollUp()
            navigateBack()
        }
        
        demoWait(.hero, label: "Invoice tracking — scene complete")
        
        print("🎬 ═══ SCENE 08 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 09: Accounts Overview
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_09_AccountsOverview() throws {
        print("🎬 ═══ SCENE 09: Accounts Overview ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal, label: "More tab loaded")
        
        let accountsRow = app.staticTexts["Accounts"]
        if accountsRow.waitForExistence(timeout: 3) {
            accountsRow.tap()
            demoWait(.readable, label: "Accounts list loaded")
        }
        
        demoWait(.hero, label: "Viewing bank accounts — checking, savings, credit")
        
        scrollDown()
        demoWait(.readable, label: "Credit cards with balances and utilization")
        
        scrollUp()
        demoWait(.hero, label: "Accounts overview — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 09 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 10: Mileage Tracking  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_10_MileageTracking() throws {
        print("🎬 ═══ SCENE 10: Mileage Tracking ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal, label: "More tab loaded")
        
        let mileageRow = app.staticTexts["Mileage Tracking"]
        if mileageRow.waitForExistence(timeout: 3) {
            mileageRow.tap()
            demoWait(.readable, label: "Mileage tracking view loaded")
        }
        
        demoWait(.hero, label: "Mileage tracking — deduction summary at top")
        
        scrollDown()
        demoWait(.readable, label: "Recent trips with IRS-rate deductions")
        
        // Tap a trip for detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.hero, label: "Trip detail — start, end, miles, deduction")
            
            scrollDown()
            demoWait(.readable, label: "Trip purpose and classification")
            
            navigateBack()
        }
        
        demoWait(.hero, label: "Mileage tracking — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 10 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 11: Manual Trip Entry  [REWRITTEN v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_11_ManualTripEntry() throws {
        print("🎬 ═══ SCENE 11: Manual Trip Entry ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        let mileageRow = app.staticTexts["Mileage Tracking"]
        if mileageRow.waitForExistence(timeout: 3) {
            mileageRow.tap()
            demoWait(.normal, label: "Mileage view loaded")
        }
        
        let manualButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'manual' OR label CONTAINS[c] 'add' OR label == '+'")
        ).firstMatch
        if manualButton.waitForExistence(timeout: 3) {
            manualButton.tap()
            demoWait(.readable, label: "Manual trip entry form")
        }
        
        // Enter starting address
        let startField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'start' OR label CONTAINS[c] 'Starting'")
        ).firstMatch
        if startField.waitForExistence(timeout: 3) {
            demoType(startField, text: "123 Main St, Austin TX")
            demoWait(.readable, label: "Starting address entered")
        }
        
        // Enter destination
        let endField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'destination' OR label CONTAINS[c] 'Destination'")
        ).firstMatch
        if endField.waitForExistence(timeout: 3) {
            demoType(endField, text: "456 Client Ave, Austin TX")
            demoWait(.readable, label: "Destination entered")
        }
        
        scrollDown()
        demoWait(.normal)
        
        // Enter distance
        let distanceField = app.textFields["Trip distance"]
        if distanceField.waitForExistence(timeout: 3) {
            demoType(distanceField, text: "12.5")
            demoWait(.readable, label: "Distance: 12.5 miles — deduction auto-calculated!")
        } else {
            let fallback = app.textFields["Distance"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "12.5")
                demoWait(.readable, label: "Distance entered via fallback")
            }
        }
        
        scrollDown()
        demoWait(.readable, label: "Estimated deduction and trip purpose")
        
        scrollDown()
        demoWait(.readable, label: "Business classification and notes")
        
        dismissSheet()
        demoWait(.hero, label: "Manual trip entry — scene complete")
        
        print("🎬 ═══ SCENE 11 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 12: Recurring Transactions
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_12_RecurringTransactions() throws {
        print("🎬 ═══ SCENE 12: Recurring Transactions ═══")
        launchAppForDashboard()
        
        navigateToBudgets()
        demoWait(.normal, label: "Budgets tab loaded")
        
        let recurringTab = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'recurring' OR label CONTAINS[c] 'Recurring'")
        ).firstMatch
        if recurringTab.waitForExistence(timeout: 3) {
            recurringTab.tap()
            demoWait(.readable, label: "Recurring transactions list")
        }
        
        demoWait(.hero, label: "Recurring bills and income")
        
        scrollDown()
        demoWait(.readable, label: "Subscriptions, rent, and recurring income")
        
        scrollUp()
        demoWait(.hero, label: "Recurring transactions — scene complete")
        
        print("🎬 ═══ SCENE 12 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 13: Tax Deductions  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_13_TaxDeductions() throws {
        print("🎬 ═══ SCENE 13: Tax Deductions ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown()
        
        let deductionsRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'deduction' OR label CONTAINS[c] 'Deduction'")
        ).firstMatch
        if deductionsRow.waitForExistence(timeout: 3) {
            deductionsRow.tap()
            demoWait(.readable, label: "Tax deductions view loaded")
        }
        
        demoWait(.hero, label: "Deduction opportunities — money you can save")
        
        scrollDown()
        demoWait(.readable, label: "Deduction categories with amounts")
        
        // Tap a deduction for details
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.readable, label: "Deduction detail — qualifying transactions")
            navigateBack()
        }
        
        scrollDown()
        demoWait(.readable, label: "More deduction opportunities")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Tax deductions — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 13 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 14: Reports & Analytics  [REWRITTEN v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_14_ReportsAnalytics() throws {
        print("🎬 ═══ SCENE 14: Reports & Analytics ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        let reportsRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'report' OR label CONTAINS[c] 'Report'")
        ).firstMatch
        if reportsRow.waitForExistence(timeout: 3) {
            reportsRow.tap()
            demoWait(.readable, label: "Reports view loaded")
        }
        
        demoWait(.hero, label: "Category Breakdown — pie chart")
        
        scrollDown()
        demoWait(.readable, label: "Income, expenses, and net cash flow")
        
        scrollDown()
        demoWait(.readable, label: "Category breakdown with color legend")
        
        scrollUp(times: 2)
        demoWait(.normal)
        
        // Switch time periods
        let yearSegment = app.buttons["Year"]
        if yearSegment.waitForExistence(timeout: 2) {
            yearSegment.tap()
            demoWait(.readable, label: "Switched to Year view — annual totals")
        }
        
        let quarterSegment = app.buttons["Quarter"]
        if quarterSegment.waitForExistence(timeout: 2) {
            quarterSegment.tap()
            demoWait(.readable, label: "Switched to Quarter view")
        }
        
        let monthSegment = app.buttons["Month"]
        if monthSegment.waitForExistence(timeout: 2) {
            monthSegment.tap()
            demoWait(.readable, label: "Back to monthly view")
        }
        
        // Switch chart type via toolbar menu
        let chartTypeButton = app.buttons["Chart type"]
        if chartTypeButton.waitForExistence(timeout: 2) {
            chartTypeButton.tap()
            demoWait(.normal, label: "Chart type menu opened")
            
            let monthlyTrend = app.buttons["Monthly Trend"]
            if monthlyTrend.waitForExistence(timeout: 2) {
                monthlyTrend.tap()
                demoWait(.hero, label: "Monthly Trend — bar chart view")
            }
        }
        
        scrollDown()
        demoWait(.readable, label: "6-month trend with income vs expense bars")
        
        scrollUp()
        demoWait(.hero, label: "Reports — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 14 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 15: Client Management
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_15_ClientManagement() throws {
        print("🎬 ═══ SCENE 15: Client Management ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        let clientsRow = app.staticTexts["Clients"]
        if clientsRow.waitForExistence(timeout: 3) {
            clientsRow.tap()
            demoWait(.readable, label: "Clients list loaded")
        }
        
        demoWait(.hero, label: "Client list with contact info")
        
        scrollDown()
        demoWait(.readable, label: "More clients")
        
        scrollUp()
        
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.hero, label: "Client detail — invoices, payments, contact")
            
            scrollDown()
            demoWait(.readable, label: "Client payment history")
            
            navigateBack()
        }
        
        demoWait(.hero, label: "Client management — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 15 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 16: Category Management
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_16_CategoryManagement() throws {
        print("🎬 ═══ SCENE 16: Category Management ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown(times: 2)
        
        let categoriesRow = app.staticTexts["Categories"]
        if categoriesRow.waitForExistence(timeout: 3) {
            categoriesRow.tap()
            demoWait(.readable, label: "Categories view loaded")
        }
        
        demoWait(.hero, label: "Category list with icons")
        
        scrollDown()
        demoWait(.readable, label: "Business categories")
        
        scrollDown()
        demoWait(.readable, label: "Personal categories")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Categories — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 16 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 17: Color Themes  [IMPROVED v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_17_ColorThemes() throws {
        print("🎬 ═══ SCENE 17: Color Themes ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown(times: 2)
        
        let appearanceRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'appearance' OR label CONTAINS[c] 'Appearance' OR label CONTAINS[c] 'theme' OR label CONTAINS[c] 'Theme'")
        ).firstMatch
        if appearanceRow.waitForExistence(timeout: 3) {
            appearanceRow.tap()
            demoWait(.readable, label: "Appearance settings loaded")
        }
        
        demoWait(.hero, label: "Theme customization options")
        
        // Tap different themes to show color switching (re-query after each tap)
        if app.cells.allElementsBoundByIndex.count > 1 {
            app.cells.element(boundBy: 1).tap()
            demoWait(.readable, label: "Theme option 2 — colors changed!")
        }
        if app.cells.allElementsBoundByIndex.count > 2 {
            app.cells.element(boundBy: 2).tap()
            demoWait(.readable, label: "Theme option 3 selected")
        } else if app.cells.allElementsBoundByIndex.count > 1 {
            // Fewer cells visible after navigation — tap what's available
            app.cells.element(boundBy: 1).tap()
            demoWait(.readable, label: "Theme option selected")
        }
        if app.cells.allElementsBoundByIndex.count > 0 {
            app.cells.element(boundBy: 0).tap()
            demoWait(.readable, label: "Back to default theme")
        }
        
        demoWait(.hero, label: "Appearance — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 17 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 18: Settings & More Menu
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_18_SettingsMenu() throws {
        print("🎬 ═══ SCENE 18: Settings & More Menu ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.hero, label: "More menu — profile section")
        
        scrollDown()
        demoWait(.readable, label: "Financial Tools section")
        
        scrollDown()
        demoWait(.readable, label: "Tax & Reports section")
        
        scrollDown()
        demoWait(.readable, label: "Business Tools section")
        
        scrollDown()
        demoWait(.readable, label: "Preferences section")
        
        scrollDown()
        demoWait(.readable, label: "Data & Backup section")
        
        scrollDown()
        demoWait(.readable, label: "About section")
        
        scrollUp(times: 6)
        demoWait(.hero, label: "Settings menu — scene complete")
        
        print("🎬 ═══ SCENE 18 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 19: Quick Tab Tour
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_19_QuickTabTour() throws {
        print("🎬 ═══ SCENE 19: Quick Tab Tour ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.readable, label: "Tab 1: Dashboard")
        
        navigateToTransactions()
        demoWait(.readable, label: "Tab 2: Transactions")
        
        navigateToBudgets()
        demoWait(.readable, label: "Tab 3: Budgets")
        
        navigateToInvoices()
        demoWait(.readable, label: "Tab 4: Invoices")
        
        navigateToMore()
        demoWait(.readable, label: "Tab 5: More")
        
        navigateToDashboard()
        demoWait(.hero, label: "Back to Dashboard — tour complete")
        
        print("🎬 ═══ SCENE 19 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 20: Subscription Tiers
    // ═══════════════════════════════════════════════════════════════
    
    @MainActor
    func testDemo_20_SubscriptionTiers() throws {
        print("🎬 ═══ SCENE 20: Subscription Tiers ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown(times: 3)
        
        let subscriptionRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'subscription' OR label CONTAINS[c] 'Subscription' OR label CONTAINS[c] 'upgrade' OR label CONTAINS[c] 'Upgrade'")
        ).firstMatch
        if subscriptionRow.waitForExistence(timeout: 3) {
            subscriptionRow.tap()
            demoWait(.readable, label: "Subscription view loaded")
        }
        
        demoWait(.hero, label: "Subscription tier comparison")
        
        scrollDown()
        demoWait(.readable, label: "Feature comparison details")
        
        scrollDown()
        demoWait(.readable, label: "Pricing and CTA")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Subscription tiers — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 20 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 21: Receipt Scanning  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Smart Receipt Scanner — show scanner UI and capture options
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_21_ReceiptScanning() throws {
        print("🎬 ═══ SCENE 21: Receipt Scanning ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.normal)
        
        // Look for receipt/scan quick action on dashboard
        let scanButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'receipt' OR label CONTAINS[c] 'scan' OR label CONTAINS[c] 'Receipt'")
        ).firstMatch
        
        if scanButton.waitForExistence(timeout: 3) {
            scanButton.tap()
            demoWait(.readable, label: "Smart Receipt Scanner opened")
        }
        
        demoWait(.hero, label: "Receipt scanner — camera and photo library options")
        
        // Scroll to show capture options
        scrollDown()
        demoWait(.readable, label: "Capture options — camera, photo library")
        
        scrollUp()
        demoWait(.readable, label: "Scanner ready for receipts")
        
        dismissSheet()
        demoWait(.hero, label: "Receipt scanning — scene complete")
        
        print("🎬 ═══ SCENE 21 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 22: Credit Card Management  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Credit card summary with utilization tracking
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_22_CreditCardManagement() throws {
        print("🎬 ═══ SCENE 22: Credit Card Management ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.normal)
        
        // Scroll dashboard to find credit card summary card
        scrollDown()
        demoWait(.readable, label: "Scrolling to credit card section")
        
        scrollDown()
        demoWait(.readable, label: "Credit card utilization summary")
        
        scrollDown()
        demoWait(.readable, label: "Individual card balances and limits")
        
        // Navigate to Accounts to see full credit card details
        navigateToMore()
        demoWait(.normal)
        
        let accountsRow = app.staticTexts["Accounts"]
        if accountsRow.waitForExistence(timeout: 3) {
            accountsRow.tap()
            demoWait(.readable, label: "Accounts list — credit cards section")
        }
        
        scrollDown()
        demoWait(.hero, label: "Credit card accounts with balances and utilization")
        
        scrollUp()
        navigateBack()
        
        demoWait(.hero, label: "Credit card management — scene complete")
        
        print("🎬 ═══ SCENE 22 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 23: Debt Payoff Calculator  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Debt payoff calculator — enter loan details, calculate savings
    /// Duration target: ~40 seconds
    @MainActor
    func testDemo_23_DebtPayoffCalculator() throws {
        print("🎬 ═══ SCENE 23: Debt Payoff Calculator ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        // Tap Debt Payoff Calculator
        let debtCalcRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'debt' OR label CONTAINS[c] 'Debt'")
        ).firstMatch
        if debtCalcRow.waitForExistence(timeout: 3) {
            debtCalcRow.tap()
            demoWait(.readable, label: "Debt Payoff Calculator opened")
        }
        
        demoWait(.hero, label: "Calculator with debt type selector")
        
        // Try tapping "Credit Card" debt type (may be off-screen on smaller devices)
        // This is optional for the demo — scroll to reveal and attempt tap
        // Wait a bit before scrolling to ensure view is fully presented
        demoWait(.brief)
        scrollDown()
        sleep(1)
        scrollUp()
        demoWait(.normal, label: "Viewing debt type options")
        
        // Enter current balance
        let balanceField = app.textFields["Current balance in dollars"]
        if balanceField.waitForExistence(timeout: 3) {
            demoType(balanceField, text: "5000")
            demoWait(.readable, label: "Balance: $5,000")
        } else {
            let fallback = app.textFields["250,000"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "5000")
                demoWait(.readable, label: "Balance entered via fallback")
            }
        }
        
        // Enter interest rate
        let rateField = app.textFields["Annual interest rate, percent"]
        if rateField.waitForExistence(timeout: 3) {
            demoType(rateField, text: "22.9")
            demoWait(.readable, label: "APR: 22.9%")
        } else {
            let fallback = app.textFields["6.5"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "22.9")
                demoWait(.readable, label: "Rate entered via fallback")
            }
        }
        
        scrollDown()
        demoWait(.normal)
        
        // Enter monthly payment
        let paymentField = app.textFields["Monthly principal and interest payment in dollars"]
        if paymentField.waitForExistence(timeout: 3) {
            demoType(paymentField, text: "200")
            demoWait(.readable, label: "Monthly payment: $200")
        } else {
            let fallback = app.textFields["1,704"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "200")
                demoWait(.readable, label: "Payment entered via fallback")
            }
        }
        
        // Tap Calculate Payoff
        let calcButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'calculate' OR label CONTAINS[c] 'Calculate'")
        ).firstMatch
        if calcButton.waitForExistence(timeout: 3) {
            calcButton.tap()
            demoWait(.hero, label: "Calculating payoff — results appearing!")
        }
        
        // Scroll to see results
        scrollDown()
        demoWait(.readable, label: "Strategy comparison — Minimum vs 1/6 Trick")
        
        scrollDown()
        demoWait(.readable, label: "Time saved and interest saved")
        
        scrollDown()
        demoWait(.readable, label: "Payoff timeline comparison chart")
        
        scrollUp(times: 3)
        demoWait(.hero, label: "Debt payoff calculator — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 23 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 24: Export Options  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Export data — show PDF and CSV export options
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_24_ExportOptions() throws {
        print("🎬 ═══ SCENE 24: Export Options ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        // Scroll to Data & Backup section
        scrollDown(times: 3)
        
        let exportRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'export' OR label CONTAINS[c] 'Export'")
        ).firstMatch
        if exportRow.waitForExistence(timeout: 3) {
            exportRow.tap()
            demoWait(.readable, label: "Export options view loaded")
        }
        
        demoWait(.hero, label: "Export data — PDF and CSV formats")
        
        // Scroll to show export type cards
        scrollDown()
        demoWait(.readable, label: "Transaction export with date range filters")
        
        scrollDown()
        demoWait(.readable, label: "Invoice export and finance type filters")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Export options — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 24 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 25: Profit & Loss Report  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Profit & Loss statement — professional financial report
    /// Duration target: ~25 seconds
    @MainActor
    func testDemo_25_ProfitLossReport() throws {
        print("🎬 ═══ SCENE 25: Profit & Loss Report ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        // Scroll to Tax & Reports section
        scrollDown()
        
        let profitLossRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'profit' OR label CONTAINS[c] 'Profit'")
        ).firstMatch
        if profitLossRow.waitForExistence(timeout: 3) {
            profitLossRow.tap()
            demoWait(.readable, label: "Profit & Loss report loaded")
        }
        
        demoWait(.hero, label: "P&L statement — revenue, expenses, net profit")
        
        scrollDown()
        demoWait(.readable, label: "Revenue breakdown by category")
        
        scrollDown()
        demoWait(.readable, label: "Expense breakdown with totals")
        
        scrollDown()
        demoWait(.readable, label: "Net profit summary")
        
        scrollUp(times: 3)
        demoWait(.hero, label: "Profit & Loss — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 25 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 26: Year-End Tax Checklist  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Year-end tax planning checklist — checklist items by priority
    /// Duration target: ~25 seconds
    @MainActor
    func testDemo_26_YearEndTaxChecklist() throws {
        print("🎬 ═══ SCENE 26: Year-End Tax Checklist ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown()
        
        let yearEndRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'year-end' OR label CONTAINS[c] 'Year-End' OR label CONTAINS[c] 'checklist' OR label CONTAINS[c] 'Checklist'")
        ).firstMatch
        if yearEndRow.waitForExistence(timeout: 3) {
            yearEndRow.tap()
            demoWait(.readable, label: "Year-End Tax Planning loaded")
        }
        
        demoWait(.hero, label: "Tax checklist — high priority items")
        
        scrollDown()
        demoWait(.readable, label: "Medium priority checklist items")
        
        // Tap a checklist item for detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.tap()
            demoWait(.readable, label: "Checklist item detail — instructions and tips")
            navigateBack()
        }
        
        scrollDown()
        demoWait(.readable, label: "Low priority items — plan ahead")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Year-end checklist — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 26 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 27: Move Money / Transfers  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Transfer between accounts — select from/to, enter amount
    /// Duration target: ~25 seconds
    @MainActor
    func testDemo_27_MoveMoneyTransfers() throws {
        print("🎬 ═══ SCENE 27: Move Money / Transfers ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.normal)
        
        // Look for Move quick action on dashboard
        let moveButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'move' OR label CONTAINS[c] 'Move' OR label CONTAINS[c] 'transfer' OR label CONTAINS[c] 'Transfer'")
        ).firstMatch
        
        if moveButton.waitForExistence(timeout: 3) {
            moveButton.tap()
            demoWait(.readable, label: "Move Money form opened")
        }
        
        demoWait(.hero, label: "Transfer form — From and To account pickers")
        
        // Enter transfer amount
        let amountField = app.textFields["Transfer amount in dollars"]
        if amountField.waitForExistence(timeout: 3) {
            demoType(amountField, text: "500")
            demoWait(.readable, label: "Transfer amount: $500")
        } else {
            let fallback = app.textFields["0.00"]
            if fallback.waitForExistence(timeout: 2) {
                demoType(fallback, text: "500")
                demoWait(.readable, label: "Amount entered via fallback")
            }
        }
        
        // Scroll to show summary and transfer type
        scrollDown()
        demoWait(.readable, label: "Transfer type auto-detected and summary")
        
        scrollUp()
        demoWait(.readable, label: "Move Money form complete")
        
        dismissSheet()
        demoWait(.hero, label: "Move Money — scene complete")
        
        print("🎬 ═══ SCENE 27 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 28: Business Profile Setup  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Business profile — company name, email, address for invoices
    /// Duration target: ~30 seconds
    @MainActor
    func testDemo_28_BusinessProfileSetup() throws {
        print("🎬 ═══ SCENE 28: Business Profile Setup ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        let businessRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'business profile' OR label CONTAINS[c] 'Business Profile'")
        ).firstMatch
        if businessRow.waitForExistence(timeout: 3) {
            businessRow.tap()
            demoWait(.readable, label: "Business Profile settings loaded")
        }
        
        demoWait(.hero, label: "Business profile — your brand identity")
        
        // Enter business name
        let nameField = app.textFields["Your Business Name"]
        if nameField.waitForExistence(timeout: 3) {
            demoType(nameField, text: "Rivera Design Co")
            demoWait(.readable, label: "Business name: Rivera Design Co")
        }
        
        // Scroll to email
        scrollDown()
        demoWait(.normal)
        
        let emailField = app.textFields["business@example.com"]
        if emailField.waitForExistence(timeout: 3) {
            demoType(emailField, text: "alex@riveradesign.co")
            demoWait(.readable, label: "Email entered")
        }
        
        // Scroll to address section
        scrollDown()
        demoWait(.readable, label: "Optional info — contact, phone, website, tax ID")
        
        scrollDown()
        demoWait(.readable, label: "Business address for invoices")
        
        scrollUp(times: 3)
        demoWait(.hero, label: "Business profile — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 28 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 29: Tax Settings  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Tax configuration — filing status, state, estimated taxes
    /// Duration target: ~25 seconds
    @MainActor
    func testDemo_29_TaxSettings() throws {
        print("🎬 ═══ SCENE 29: Tax Settings ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown(times: 2)
        
        let taxRow = app.buttons["Tax Settings"].firstMatch
        if taxRow.waitForExistence(timeout: 3) {
            taxRow.tap()
            demoWait(.readable, label: "Tax Settings loaded")
        } else {
            // Fallback: try staticTexts with firstMatch
            let taxText = app.staticTexts["Tax Settings"].firstMatch
            if taxText.waitForExistence(timeout: 2) {
                taxText.tap()
                demoWait(.readable, label: "Tax Settings loaded")
            }
        }
        
        demoWait(.hero, label: "Tax settings — filing status and state")
        
        // Scroll to show all settings
        scrollDown()
        demoWait(.readable, label: "State tax configuration")
        
        scrollDown()
        demoWait(.readable, label: "Estimated tax payments and reminders")
        
        scrollDown()
        demoWait(.readable, label: "Custom rates and overrides")
        
        scrollUp(times: 3)
        demoWait(.hero, label: "Tax settings — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 29 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 30: Money Moves Insights  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Smart financial insights on dashboard — tips and alerts
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_30_MoneyMovesInsights() throws {
        print("🎬 ═══ SCENE 30: Money Moves Insights ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.hero, label: "Dashboard loaded")
        
        // Scroll to find insights card
        scrollDown()
        demoWait(.readable, label: "Scrolling to insights section")
        
        scrollDown()
        demoWait(.readable, label: "Money Moves insights — spending patterns")
        
        scrollDown()
        demoWait(.readable, label: "Tips and tax saving suggestions")
        
        scrollDown()
        demoWait(.hero, label: "Smart insights — personalized financial advice")
        
        scrollUp(times: 4)
        demoWait(.hero, label: "Money Moves insights — scene complete")
        
        print("🎬 ═══ SCENE 30 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 31: Security & Passcode  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Security settings — biometric auth, passcode options
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_31_SecurityPasscode() throws {
        print("🎬 ═══ SCENE 31: Security & Passcode ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        scrollDown(times: 2)
        
        let securityRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'security' OR label CONTAINS[c] 'Security'")
        ).firstMatch
        if securityRow.waitForExistence(timeout: 3) {
            securityRow.tap()
            demoWait(.readable, label: "Security settings loaded")
        }
        
        demoWait(.hero, label: "Security — Face ID / Touch ID and Passcode")
        
        scrollDown()
        demoWait(.readable, label: "Biometric authentication options")
        
        scrollDown()
        demoWait(.readable, label: "Passcode setup and auto-lock")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Security settings — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 31 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 32: Comprehensive CPA Report  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Generate CPA-ready report — select type, period, generate
    /// Duration target: ~30 seconds
    @MainActor
    func testDemo_32_ComprehensiveReport() throws {
        print("🎬 ═══ SCENE 32: Comprehensive CPA Report ═══")
        launchAppForDashboard()
        
        navigateToMore()
        demoWait(.normal)
        
        // Navigate to Reports first
        let reportsRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'report' OR label CONTAINS[c] 'Report'")
        ).firstMatch
        if reportsRow.waitForExistence(timeout: 3) {
            reportsRow.tap()
            demoWait(.normal, label: "Reports view loaded")
        }
        
        // Tap CPA report button in toolbar
        let cpaButton = app.buttons["Generate CPA report"]
        if cpaButton.waitForExistence(timeout: 3) {
            cpaButton.tap()
            demoWait(.readable, label: "Comprehensive Report generator opened")
        }
        
        demoWait(.hero, label: "CPA Report — Annual, Quarterly, Custom options")
        
        // Try tapping "Quarterly Report" type
        let quarterlyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'quarterly' OR label CONTAINS[c] 'Quarterly'")
        ).firstMatch
        if quarterlyButton.waitForExistence(timeout: 2) {
            quarterlyButton.tap()
            demoWait(.readable, label: "Selected Quarterly Report type")
        }
        
        // Scroll to show report options
        scrollDown()
        demoWait(.readable, label: "Period selection and included sections")
        
        scrollDown()
        demoWait(.readable, label: "Generate button and preview")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Comprehensive report — scene complete")
        
        dismissSheet()
        navigateBack()
        
        print("🎬 ═══ SCENE 32 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 33: Edit Transaction Detail  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Edit an existing transaction — show edit form with pre-filled data
    /// Duration target: ~25 seconds
    @MainActor
    func testDemo_33_EditTransactionDetail() throws {
        print("🎬 ═══ SCENE 33: Edit Transaction Detail ═══")
        launchAppForDashboard()
        
        navigateToTransactions()
        demoWait(.readable, label: "Transaction list loaded")
        
        // Tap first transaction
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            demoWait(.readable, label: "Transaction detail view")
        }
        
        // Look for Edit button
        let editButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'edit' OR label CONTAINS[c] 'Edit'")
        ).firstMatch
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
            demoWait(.readable, label: "Edit Transaction form — pre-filled fields")
        }
        
        demoWait(.hero, label: "Edit form with existing amount, merchant, category")
        
        // Scroll through pre-filled edit form
        scrollDown()
        demoWait(.readable, label: "Category, account, and classification")
        
        scrollDown()
        demoWait(.readable, label: "Date, notes, and receipt attachment")
        
        scrollUp(times: 2)
        demoWait(.readable, label: "Edit form complete")
        
        // Dismiss without saving
        dismissSheet()
        demoWait(.normal)
        
        navigateBack()
        demoWait(.hero, label: "Edit transaction — scene complete")
        
        print("🎬 ═══ SCENE 33 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 34: Invoice Detail View  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Full invoice detail — line items, totals, actions, payment history
    /// Duration target: ~30 seconds
    @MainActor
    func testDemo_34_InvoiceDetailView() throws {
        print("🎬 ═══ SCENE 34: Invoice Detail View ═══")
        launchAppForDashboard()
        
        navigateToInvoices()
        demoWait(.readable, label: "Invoice list loaded")
        
        // Tap first invoice
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            demoWait(.hero, label: "Invoice detail — invoice number and client")
        }
        
        // Slow scroll through the entire invoice
        scrollDown()
        demoWait(.readable, label: "Client info and dates")
        
        scrollDown()
        demoWait(.readable, label: "Line items with descriptions and amounts")
        
        scrollDown()
        demoWait(.readable, label: "Subtotal, tax, and grand total")
        
        scrollDown()
        demoWait(.readable, label: "Payment status and action buttons")
        
        // Look for action buttons
        let markSentButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'sent' OR label CONTAINS[c] 'mark' OR label CONTAINS[c] 'Mark'")
        ).firstMatch
        if markSentButton.waitForExistence(timeout: 2) {
            demoWait(.readable, label: "Action available: Mark as Sent, Record Payment")
        }
        
        scrollUp(times: 4)
        demoWait(.hero, label: "Invoice detail — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 34 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 35: Budget History  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Budget history — view past month budgets and trends
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_35_BudgetHistory() throws {
        print("🎬 ═══ SCENE 35: Budget History ═══")
        launchAppForDashboard()
        
        navigateToBudgets()
        demoWait(.normal, label: "Budgets loaded")
        
        // Look for History button
        let historyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'history' OR label CONTAINS[c] 'History'")
        ).firstMatch
        if historyButton.waitForExistence(timeout: 3) {
            historyButton.tap()
            demoWait(.readable, label: "Budget History view loaded")
        }
        
        demoWait(.hero, label: "Budget history — past months comparison")
        
        scrollDown()
        demoWait(.readable, label: "Monthly budget performance")
        
        scrollDown()
        demoWait(.readable, label: "Spending trends over time")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Budget history — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 35 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 36: Receipt Matching Queue  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Match scanned receipts to transactions
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_36_ReceiptMatchingQueue() throws {
        print("🎬 ═══ SCENE 36: Receipt Matching Queue ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.normal)
        
        // Scroll dashboard looking for receipt management card
        scrollDown()
        demoWait(.normal)
        scrollDown()
        demoWait(.normal)
        scrollDown()
        demoWait(.normal)
        
        // Try to find receipt matching via More menu
        navigateToMore()
        demoWait(.normal)
        
        // Look for anything receipt-related
        let receiptRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'receipt' OR label CONTAINS[c] 'Receipt' OR label CONTAINS[c] 'match' OR label CONTAINS[c] 'Match'")
        ).firstMatch
        if receiptRow.waitForExistence(timeout: 3) {
            receiptRow.tap()
            demoWait(.readable, label: "Receipt matching queue loaded")
        }
        
        demoWait(.hero, label: "Receipts waiting to be matched to transactions")
        
        scrollDown()
        demoWait(.readable, label: "Unmatched receipts with suggested matches")
        
        scrollUp()
        demoWait(.hero, label: "Receipt matching — scene complete")
        
        navigateBack()
        
        print("🎬 ═══ SCENE 36 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 37: Split Receipt  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Split a receipt between business and personal
    /// Duration target: ~20 seconds
    @MainActor
    func testDemo_37_SplitReceipt() throws {
        print("🎬 ═══ SCENE 37: Split Receipt ═══")
        launchAppForDashboard()
        
        // Navigate to receipt scanner which has split option
        let scanButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'receipt' OR label CONTAINS[c] 'scan' OR label CONTAINS[c] 'Receipt'")
        ).firstMatch
        
        if scanButton.waitForExistence(timeout: 3) {
            scanButton.tap()
            demoWait(.readable, label: "Receipt scanner opened")
        }
        
        demoWait(.hero, label: "Receipt scanner — split option for mixed purchases")
        
        // Scroll to show split option if visible
        scrollDown()
        demoWait(.readable, label: "Split receipt between business and personal")
        
        scrollDown()
        demoWait(.readable, label: "Allocate portions by percentage or amount")
        
        scrollUp(times: 2)
        demoWait(.hero, label: "Split receipt — scene complete")
        
        dismissSheet()
        
        print("🎬 ═══ SCENE 37 COMPLETE ═══")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SCENE 38: Quick Actions  [NEW v2.0]
    // ═══════════════════════════════════════════════════════════════
    
    /// Demo: Dashboard quick actions — one-tap shortcuts
    /// Duration target: ~25 seconds
    @MainActor
    func testDemo_38_QuickActions() throws {
        print("🎬 ═══ SCENE 38: Quick Actions ═══")
        launchAppForDashboard()
        
        navigateToDashboard()
        demoWait(.hero, label: "Dashboard with Quick Actions card")
        
        // Quick Actions should be near the top of dashboard
        demoWait(.readable, label: "Quick Actions: Expense, Invoice, Move, Trip, Receipt")
        
        // Tap Expense quick action
        let expenseButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'expense' OR label == 'Expense'")
        ).firstMatch
        if expenseButton.waitForExistence(timeout: 3) {
            expenseButton.tap()
            demoWait(.readable, label: "Quick add expense — one tap!")
            dismissSheet()
            demoWait(.normal)
        }
        
        // Tap Trip quick action
        let tripButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'trip' OR label == 'Trip'")
        ).firstMatch
        if tripButton.waitForExistence(timeout: 3) {
            tripButton.tap()
            demoWait(.readable, label: "Quick start mileage trip — one tap!")
            dismissSheet()
            demoWait(.normal)
        }
        
        // Tap Invoice quick action
        let invoiceButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'invoice' OR label == 'Invoice'")
        ).firstMatch
        if invoiceButton.waitForExistence(timeout: 3) {
            invoiceButton.tap()
            demoWait(.readable, label: "Quick create invoice — one tap!")
            dismissSheet()
            demoWait(.normal)
        }
        
        demoWait(.hero, label: "Quick Actions — everything at your fingertips")
        
        print("🎬 ═══ SCENE 38 COMPLETE ═══")
    }
}

// MARK: - Version History
/*
 Version 2.0 (Current):
 - REWRITTEN: Scenes 03, 05, 07, 11, 14 with real form interactions
 - IMPROVED: Scenes 02, 04, 06, 08, 10, 13, 17 with deeper navigation
 - NEW: 18 extended scenes (21-38) covering all remaining features
 - Added navigateBack() helper method
 - All scenes now show features WORKING, not just existing
 - Accessibility labels used for reliable element targeting
 - Fallback patterns for elements that may have different labels
 
 Version 1.0:
 - Initial demo video test suite
 - 20 scenes covering all major FLO features
 - DemoPacing system for consistent video timing
 
 SCENE INDEX (38 Total):
 ─── CORE FEATURES (01-20) ───
 01 - Onboarding Flow
 02 - Dashboard Tour              [IMPROVED v2.0]
 03 - Adding a Transaction        [REWRITTEN v2.0]
 04 - Transaction List            [IMPROVED v2.0]
 05 - Creating a Budget           [REWRITTEN v2.0]
 06 - Budget Overview             [IMPROVED v2.0]
 07 - Creating an Invoice         [REWRITTEN v2.0]
 08 - Invoice Status Tracking     [IMPROVED v2.0]
 09 - Accounts Overview
 10 - Mileage Tracking            [IMPROVED v2.0]
 11 - Manual Trip Entry           [REWRITTEN v2.0]
 12 - Recurring Transactions
 13 - Tax Deductions              [IMPROVED v2.0]
 14 - Reports & Analytics         [REWRITTEN v2.0]
 15 - Client Management
 16 - Category Management
 17 - Color Themes                [IMPROVED v2.0]
 18 - Settings & More Menu
 19 - Quick Tab Tour
 20 - Subscription Tiers
 
 ─── EXTENDED FEATURES (21-38) ─── [ALL NEW v2.0]
 21 - Receipt Scanning
 22 - Credit Card Management
 23 - Debt Payoff Calculator      [INTERACTIVE — fills form, calculates]
 24 - Export Options
 25 - Profit & Loss Report
 26 - Year-End Tax Checklist
 27 - Move Money / Transfers      [INTERACTIVE — enters amount]
 28 - Business Profile Setup      [INTERACTIVE — fills name, email]
 29 - Tax Settings
 30 - Money Moves Insights
 31 - Security & Passcode
 32 - Comprehensive CPA Report
 33 - Edit Transaction Detail
 34 - Invoice Detail View
 35 - Budget History
 36 - Receipt Matching Queue
 37 - Split Receipt
 38 - Quick Actions               [INTERACTIVE — taps each action]
 */
