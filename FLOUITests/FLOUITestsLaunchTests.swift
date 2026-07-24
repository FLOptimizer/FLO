//  FLOUITestsLaunchTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Launch Screenshot Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Capture launch screenshots across different device configurations.
//  These run once per UI configuration (light/dark mode, device type).
//

import XCTest

final class FLOUITestsLaunchTests: XCTestCase {
    
    /// Run once for each target application UI configuration
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully load
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 5)
        
        // Capture launch screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - Version History
/*
 Version 1.0:
 - Captures launch screenshots for each UI configuration
 - Useful for App Store screenshots and visual regression
 - Waits for tab bar to ensure app is fully loaded
 */
