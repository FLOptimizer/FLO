//  SnapshotHelper.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed Swift 6 Concurrency Issues
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Based on fastlane snapshot helper
//  https://github.com/fastlane/fastlane/blob/master/snapshot/lib/assets/SnapshotHelper.swift
//
//  SETUP:
//  1. Add this file to your FLOUITests target
//  2. Use snapshot("ScreenName") in your UI tests
//  3. Run: fastlane snapshot
//

import Foundation
import XCTest

// MARK: - Global Variables

var deviceLanguage = ""
var locale = ""

// MARK: - Global Functions (MainActor)

@MainActor
func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setupSnapshot(app, waitForAnimations: waitForAnimations)
}

@MainActor
func snapshot(_ name: String, waitForLoadingIndicator: Bool = false) {
    if waitForLoadingIndicator {
        Snapshot.snapshot(name, waitForLoadingIndicator: waitForLoadingIndicator)
    } else {
        Snapshot.snapshot(name)
    }
}

@MainActor
func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval) {
    Snapshot.snapshot(name, timeWaitingForIdle: timeout)
}

// MARK: - Snapshot Error

enum SnapshotError: Error, CustomDebugStringConvertible {
    case cannotFindSimulatorHomeDirectory
    case cannotRunOnPhysicalDevice

    var debugDescription: String {
        switch self {
        case .cannotFindSimulatorHomeDirectory:
            return "Couldn't find simulator home directory"
        case .cannotRunOnPhysicalDevice:
            return "Cannot run on physical device"
        }
    }
}

// MARK: - Snapshot Class

@MainActor
open class Snapshot: NSObject {
    
    static var app: XCUIApplication?
    static var waitForAnimations = true
    static var cacheDirectory: URL?
    
    static var screenshotsDirectory: URL? {
        return cacheDirectory?.appendingPathComponent("screenshots", isDirectory: true)
    }

    // MARK: - Setup
    
    open class func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations

        do {
            let cacheDir = try getCacheDirectory()
            Snapshot.cacheDirectory = cacheDir
            setLanguage(app)
            setLocale(app)
            setLaunchArguments(app)
        } catch let error {
            NSLog("Snapshot: Error setting up snapshot: \(error)")
        }
    }

    // MARK: - Configuration
    
    class func setLanguage(_ app: XCUIApplication) {
        guard let cacheDirectory = self.cacheDirectory else {
            NSLog("Snapshot: Cache directory not set")
            return
        }

        let path = cacheDirectory.appendingPathComponent("language.txt")

        do {
            let trimCharacterSet = CharacterSet.whitespacesAndNewlines
            deviceLanguage = try String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: trimCharacterSet)
            app.launchArguments += ["-AppleLanguages", "(\(deviceLanguage))"]
        } catch {
            NSLog("Snapshot: Couldn't detect language: \(error)")
        }
    }

    class func setLocale(_ app: XCUIApplication) {
        guard let cacheDirectory = self.cacheDirectory else {
            NSLog("Snapshot: Cache directory not set")
            return
        }

        let path = cacheDirectory.appendingPathComponent("locale.txt")

        do {
            let trimCharacterSet = CharacterSet.whitespacesAndNewlines
            locale = try String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: trimCharacterSet)
        } catch {
            NSLog("Snapshot: Couldn't detect locale: \(error)")
        }

        if locale.isEmpty && !deviceLanguage.isEmpty {
            locale = Locale(identifier: deviceLanguage).identifier
        }

        if !locale.isEmpty {
            app.launchArguments += ["-AppleLocale", "\"\(locale)\""]
        }
    }

    class func setLaunchArguments(_ app: XCUIApplication) {
        guard let cacheDirectory = self.cacheDirectory else {
            NSLog("Snapshot: Cache directory not set")
            return
        }

        let path = cacheDirectory.appendingPathComponent("snapshot-launch_arguments.txt")
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]

        do {
            let launchArguments = try String(contentsOf: path, encoding: .utf8)
            let lines = launchArguments.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    app.launchArguments.append(trimmed)
                }
            }
        } catch {
            NSLog("Snapshot: Couldn't detect launch arguments: \(error)")
        }
    }

    // MARK: - Snapshot Capture
    
    open class func snapshot(_ name: String, waitForLoadingIndicator: Bool = false) {
        if waitForLoadingIndicator {
            waitForLoadingIndicatorToDisappear()
        }
        snapshot(name, timeWaitingForIdle: 20)
    }

    open class func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval) {
        guard let app = self.app else {
            NSLog("Snapshot: App not set up. Call setupSnapshot() first.")
            return
        }

        // Wait for app to idle
        if waitForAnimations {
            sleep(1)
        }

        // Take screenshot
        let screenshot = app.screenshot()
        
        // Save screenshot
        guard let screenshotsDir = screenshotsDirectory else {
            NSLog("Snapshot: Screenshots directory not available, saving as attachment only")
            return
        }

        do {
            try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true, attributes: nil)
            
            let fileURL = screenshotsDir.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: fileURL)
            NSLog("Snapshot: Saved screenshot to \(fileURL.path)")
        } catch {
            NSLog("Snapshot: Error saving screenshot: \(error)")
        }
    }

    // MARK: - Helpers
    
    class func waitForLoadingIndicatorToDisappear() {
        guard let app = self.app else { return }

        let activityIndicator = app.activityIndicators.element
        if activityIndicator.exists {
            // Wait up to 30 seconds for loading indicator to disappear
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: activityIndicator)
            _ = XCTWaiter.wait(for: [expectation], timeout: 30)
        }
    }

    class func getCacheDirectory() throws -> URL {
        guard let simulatorHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ??
              ProcessInfo.processInfo.environment["HOME"] else {
            throw SnapshotError.cannotFindSimulatorHomeDirectory
        }

        let url = URL(fileURLWithPath: simulatorHome)
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("tools.fastlane")

        return url
    }
}

// MARK: - Version History
/*
 Version 1.1 (Current):
 - Fixed Swift 6 concurrency issues
 - Added @MainActor to global functions
 - Removed ambiguous function overloads
 - Removed conflicting XCUIElement extension
 
 Version 1.0:
 - Initial snapshot helper based on fastlane
 - Had Swift concurrency errors
 */
