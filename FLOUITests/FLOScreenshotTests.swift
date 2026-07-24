//  FLOScreenshotTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed Swift 6 MainActor Issues
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Automated screenshot capture for App Store submission.
//  Designed to work with fastlane snapshot for multi-device capture.
//
//  SETUP:
//  1. Add this file to FLOUITests target
//  2. Add SnapshotHelper.swift to FLOUITests target
//  3. Run: fastlane snapshot
//

import XCTest

final class FLOScreenshotTests: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        continueAfterFailure = true
        
        app = XCUIApplication()
        app.launchArguments = [
            "UI_TESTING",
            "SCREENSHOT_MODE",
            "-AppleLanguages", "(en-US)",
            "-AppleLocale", "en_US"
        ]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helper to Launch App with Snapshot Setup
    
    @MainActor
    private func launchAppForScreenshots() {
        setupSnapshot(app, waitForAnimations: true)
        app.launch()
        
        // Wait for app to fully load
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        
        // Small delay for animations
        Thread.sleep(forTimeInterval: 1)
    }
    
    // MARK: - Main Screenshot Flow
    
    @MainActor
    func testCaptureAllAppStoreScreenshots() throws {
        launchAppForScreenshots()
        
        // Screenshot 1: Dashboard Overview
        navigateToDashboard()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("01_Dashboard_Overview")
        
        // Screenshot 2: Transactions List
        navigateToTransactions()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("02_Transactions_List")
        
        // Screenshot 3: Add Transaction
        openAddTransaction()
        Thread.sleep(forTimeInterval: 0.5)
        captureScreenshot("03_Add_Transaction")
        dismissCurrentScreen()
        
        // Screenshot 4: Invoices List
        navigateToInvoices()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("04_Invoices_List")
        
        // Screenshot 5: Create Invoice
        openCreateInvoice()
        Thread.sleep(forTimeInterval: 0.5)
        captureScreenshot("05_Create_Invoice")
        dismissCurrentScreen()
        
        // Screenshot 6: Reports/Tax Summary
        navigateToReports()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("06_Reports_Tax_Summary")
        
        // Screenshot 7: Mileage Tracking (if visible)
        if navigateToMileage() {
            Thread.sleep(forTimeInterval: 1)
            captureScreenshot("07_Mileage_Tracking")
        }
        
        // Screenshot 8: Settings/Profile
        navigateToMore()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("08_Settings_More")
    }
    
    // MARK: - Individual Screenshot Tests
    
    @MainActor
    func testScreenshot_Dashboard() throws {
        launchAppForScreenshots()
        navigateToDashboard()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Dashboard")
    }
    
    @MainActor
    func testScreenshot_Transactions() throws {
        launchAppForScreenshots()
        navigateToTransactions()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Transactions")
    }
    
    @MainActor
    func testScreenshot_Invoices() throws {
        launchAppForScreenshots()
        navigateToInvoices()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Invoices")
    }
    
    @MainActor
    func testScreenshot_Reports() throws {
        launchAppForScreenshots()
        navigateToReports()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Reports")
    }
    
    @MainActor
    func testScreenshot_More() throws {
        launchAppForScreenshots()
        navigateToMore()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("More")
    }
    
    // MARK: - Dark Mode Screenshots
    
    @MainActor
    func testCaptureAllDarkModeScreenshots() throws {
        launchAppForScreenshots()
        
        navigateToDashboard()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Dark_01_Dashboard")
        
        navigateToTransactions()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Dark_02_Transactions")
        
        navigateToInvoices()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Dark_03_Invoices")
        
        navigateToReports()
        Thread.sleep(forTimeInterval: 1)
        captureScreenshot("Dark_04_Reports")
    }
    
    // MARK: - Navigation Helpers
    
    @MainActor
    private func navigateToDashboard() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }
        
        // Try common dashboard tab names
        let dashboardNames = ["Dashboard", "Home", "Overview"]
        for name in dashboardNames {
            let tab = tabBar.buttons[name]
            if tab.exists {
                tab.tap()
                return
            }
        }
        
        // Fall back to first tab
        let buttons = tabBar.buttons.allElementsBoundByIndex
        if buttons.count > 0 {
            buttons[0].tap()
        }
    }
    
    @MainActor
    private func navigateToTransactions() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }
        
        let tab = tabBar.buttons["Transactions"]
        if tab.exists {
            tab.tap()
        } else {
            // Fall back to second tab
            let buttons = tabBar.buttons.allElementsBoundByIndex
            if buttons.count > 1 {
                buttons[1].tap()
            }
        }
    }
    
    @MainActor
    private func navigateToInvoices() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }
        
        let tab = tabBar.buttons["Invoices"]
        if tab.exists {
            tab.tap()
        } else {
            // Fall back to third tab
            let buttons = tabBar.buttons.allElementsBoundByIndex
            if buttons.count > 2 {
                buttons[2].tap()
            }
        }
    }
    
    @MainActor
    private func navigateToReports() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }
        
        let tab = tabBar.buttons["Reports"]
        if tab.exists {
            tab.tap()
        } else {
            // Fall back to fourth tab
            let buttons = tabBar.buttons.allElementsBoundByIndex
            if buttons.count > 3 {
                buttons[3].tap()
            }
        }
    }
    
    @MainActor
    private func navigateToMore() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }
        
        let moreNames = ["More", "Settings", "Menu"]
        for name in moreNames {
            let tab = tabBar.buttons[name]
            if tab.exists {
                tab.tap()
                return
            }
        }
        
        // Fall back to last tab
        let buttons = tabBar.buttons.allElementsBoundByIndex
        if let lastTab = buttons.last {
            lastTab.tap()
        }
    }
    
    @MainActor
    private func navigateToMileage() -> Bool {
        navigateToMore()
        Thread.sleep(forTimeInterval: 0.5)
        
        let mileageButton = app.buttons["Mileage Tracking"]
        let mileageCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] 'mileage'")).firstMatch
        
        if mileageButton.exists {
            mileageButton.tap()
            return true
        } else if mileageCell.exists {
            mileageCell.tap()
            return true
        }
        
        return false
    }
    
    @MainActor
    private func openAddTransaction() {
        navigateToTransactions()
        Thread.sleep(forTimeInterval: 0.5)
        
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] 'new' OR label == '+'")).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        }
    }
    
    @MainActor
    private func openCreateInvoice() {
        navigateToInvoices()
        Thread.sleep(forTimeInterval: 0.5)
        
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'create' OR label CONTAINS[c] 'new' OR label CONTAINS[c] 'add'")).firstMatch
        if createButton.waitForExistence(timeout: 3) {
            createButton.tap()
        }
    }
    
    @MainActor
    private func dismissCurrentScreen() {
        // Try cancel button first
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
            return
        }
        
        // Try back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            return
        }
        
        // Try swipe down to dismiss sheet
        app.swipeDown()
    }
    
    // MARK: - Screenshot Helper
    
    @MainActor
    private func captureScreenshot(_ name: String) {
        // Use fastlane snapshot
        snapshot(name, timeWaitingForIdle: 5)
        
        // Also save as XCTest attachment (backup)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - Version History
/*
 Version 1.1 (Current):
 - Fixed Swift 6 MainActor isolation errors
 - Moved setupSnapshot call to launchAppForScreenshots helper
 - All navigation and capture functions now properly @MainActor
 - captureScreenshot is now @MainActor
 
 Version 1.0:
 - Initial App Store screenshot automation
 - Had Swift concurrency errors
 */
