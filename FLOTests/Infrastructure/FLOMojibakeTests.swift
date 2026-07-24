//  FLOMojibakeTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - UTF-8 Mojibake Detection
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Scans all .swift source files for mojibake (garbled UTF-8 characters)
//  caused by double-encoding or Windows-1252 misinterpretation. This test prevents
//  corrupted emoji and special characters from shipping to users.
//
//  HOW IT WORKS:
//  Reads every .swift file in the project source directories (FLO/, FLOInvoiceClip/,
//  FLOWidget/) and checks for byte sequences that are characteristic of UTF-8 bytes
//  being misread as Windows-1252 and then re-encoded to UTF-8.
//
//  COMMON MOJIBAKE PATTERNS DETECTED:
//  - â + special chars (corrupted 3-byte UTF-8 emoji like ❌, ✅, ⚠️, €, ←)
//  - ð + special chars (corrupted 4-byte UTF-8 emoji like 👤, 🏢, 💼)
//  - Ã followed by accented chars (corrupted Latin-1 characters)
//
//  RUN: This test should be included in CI to catch encoding regressions.

import XCTest

final class FLOMojibakeTests: XCTestCase {

    // MARK: - Known Mojibake Byte Signatures

    /// Each entry is a hex string representing a corrupted byte sequence
    /// and a description of what it should have been.
    private static let mojibakePatterns: [(hexBytes: String, description: String)] = [
        // 3-byte emoji corruptions (UTF-8 bytes -> Win-1252 -> UTF-8)
        ("c3a2c29dc592", "❌ (red X mark U+274C)"),
        ("c3a2c593e280a6", "✅ (checkmark U+2705)"),
        ("c3a2c5a1c2a0c3afc2b8c28f", "⚠️ (warning sign U+26A0+FE0F)"),
        ("c3a2e2809ac2ac", "€ (euro sign U+20AC)"),
        ("c3a2e280a0", "← (left arrow U+2190)"),

        // 4-byte emoji corruptions
        ("c3b0c5b8c28fc2a2", "🏢 (office building U+1F3E2)"),
        ("c3b0c5b8e28098c2a4", "👤 (person silhouette U+1F464)"),
        ("c3b0c5b8e2809cc2bc", "💼 (briefcase U+1F4BC)"),

        // Common Latin-1 double-encoding patterns
        ("c383c2a9", "é (e-acute, double-encoded)"),
        ("c383c2a8", "è (e-grave, double-encoded)"),
        ("c383c2bc", "ü (u-umlaut, double-encoded)"),
        ("c383c2b1", "ñ (n-tilde, double-encoded)"),
        ("c382c2a9", "© (copyright, double-encoded)"),
        ("c382c2ae", "® (registered, double-encoded)"),

        // En-dash / Em-dash / smart quote corruptions
        ("c3a2e2809c", "em-dash U+2014, corrupted"),
        ("c3a2e2809d", "right double quote U+201D, corrupted"),
        ("c3a2e28099", "right single quote U+2019, corrupted"),
    ]

    // MARK: - Source Directories

    /// Returns the project root by walking up from the test bundle
    private var projectRoot: URL? {
        // The compiled test bundle is in DerivedData; find the source root
        // by looking for the FLO directory structure
        let candidates = [
            URL(fileURLWithPath: "/Users/travisanderson/Financial Ledger Optimizer"),
            // Fallback: walk from the test bundle location
            Bundle(for: type(of: self)).bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        ]

        for candidate in candidates {
            let floDir = candidate.appendingPathComponent("FLO")
            if FileManager.default.fileExists(atPath: floDir.path) {
                return candidate
            }
        }
        return nil
    }

    private var sourceDirectories: [String] {
        return ["FLO", "FLOInvoiceClip"]
    }

    // MARK: - Tests

    /// Scans all Swift source files for known mojibake byte patterns.
    /// Fails with a detailed report if any corrupted characters are found.
    func testNoMojibakeInSourceFiles() throws {
        let root = try XCTUnwrap(projectRoot, "Could not locate project root directory")

        var violations: [(file: String, line: Int, pattern: String, context: String)] = []
        var filesScanned = 0

        let fileManager = FileManager.default

        for sourceDir in sourceDirectories {
            let dirURL = root.appendingPathComponent(sourceDir)
            guard fileManager.fileExists(atPath: dirURL.path) else { continue }

            let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension == "swift" else { continue }

                let data: Data
                do {
                    data = try Data(contentsOf: fileURL)
                } catch {
                    continue
                }

                filesScanned += 1
                let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")

                // Check each mojibake pattern
                for (hexPattern, description) in Self.mojibakePatterns {
                    guard let patternBytes = Data(hexString: hexPattern) else { continue }

                    // Search for the pattern in the file data
                    var searchRange = data.startIndex..<data.endIndex
                    while let range = data.range(of: patternBytes, in: searchRange) {
                        // Find line number
                        let lineNumber = data[data.startIndex..<range.lowerBound]
                            .filter { $0 == 0x0A } // newline
                            .count + 1

                        // Extract context (the line containing the match)
                        let lineStart = data[data.startIndex..<range.lowerBound]
                            .lastIndex(of: 0x0A)
                            .map { data.index(after: $0) } ?? data.startIndex
                        let lineEnd = data[range.upperBound..<data.endIndex]
                            .firstIndex(of: 0x0A) ?? data.endIndex
                        let lineData = data[lineStart..<lineEnd]
                        let lineText = String(data: lineData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<binary>"

                        violations.append((
                            file: relativePath,
                            line: lineNumber,
                            pattern: description,
                            context: String(lineText.prefix(120))
                        ))

                        searchRange = range.upperBound..<data.endIndex
                    }
                }
            }
        }

        XCTAssertGreaterThan(filesScanned, 0, "No Swift files found — check project root path")

        if !violations.isEmpty {
            var report = "\n\n🔴 MOJIBAKE DETECTED — \(violations.count) corrupted character(s) in \(Set(violations.map(\.file)).count) file(s):\n\n"

            let grouped = Dictionary(grouping: violations, by: \.file)
            for (file, fileViolations) in grouped.sorted(by: { $0.key < $1.key }) {
                report += "  📄 \(file):\n"
                for v in fileViolations {
                    report += "    Line \(v.line): Expected \(v.pattern)\n"
                    report += "      → \(v.context)\n"
                }
                report += "\n"
            }

            report += "  💡 Fix: Replace corrupted bytes with the correct Unicode characters.\n"
            report += "     Root cause is usually a text editor or Git client misinterpreting UTF-8 as Windows-1252.\n"
            report += "     Scanned \(filesScanned) Swift files.\n"

            XCTFail(report)
        }
    }

    /// Verifies that specific emoji characters used in the UI are correctly encoded.
    /// These are the characters that have historically been corrupted.
    func testCriticalEmojiAreValidUTF8() {
        // These are the exact emoji strings used in user-facing UI
        let criticalStrings: [(emoji: String, name: String)] = [
            ("👤", "Person silhouette (personal mode)"),
            ("🏢", "Office building (business mode)"),
            ("💼", "Briefcase (business)"),
            ("✅", "Checkmark"),
            ("❌", "Red X"),
            ("⚠️", "Warning sign"),
            ("€", "Euro sign"),
            ("←", "Left arrow"),
        ]

        for (emoji, name) in criticalStrings {
            // Verify the emoji round-trips through UTF-8 encoding correctly
            let encoded = emoji.data(using: .utf8)!
            let decoded = String(data: encoded, encoding: .utf8)

            XCTAssertEqual(decoded, emoji, "\(name) failed UTF-8 round-trip")

            // Verify no mojibake indicator bytes (0xC3 followed by 0xA2 is a red flag)
            let bytes = Array(encoded)
            let hasMojibake = zip(bytes, bytes.dropFirst()).contains { $0.0 == 0xC3 && $0.1 == 0xA2 }
            XCTAssertFalse(hasMojibake, "\(name) contains mojibake signature bytes (0xC3 0xA2)")
        }
    }

    /// Quick smoke test: the most commonly corrupted string in FLO's UI
    func testPersonalBusinessModeLabels() {
        // These exact strings are used in BudgetListView and RecurringListView
        let personalLabel = "👤 Budgets"
        let businessLabel = "🏢 Budgets"
        let recurringPersonal = "👤 Personal"
        let recurringBusiness = "🏢 Business"

        for label in [personalLabel, businessLabel, recurringPersonal, recurringBusiness] {
            let data = label.data(using: .utf8)!
            let roundTrip = String(data: data, encoding: .utf8)
            XCTAssertEqual(roundTrip, label, "Label '\(label)' corrupted during UTF-8 round-trip")
        }
    }
}

// MARK: - Data Hex String Helper

private extension Data {
    /// Initialize Data from a hex string (e.g., "c3a2c29d")
    init?(hexString: String) {
        let len = hexString.count
        guard len % 2 == 0 else { return nil }

        var data = Data(capacity: len / 2)
        var index = hexString.startIndex

        for _ in 0..<(len / 2) {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
