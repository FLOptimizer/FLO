//  ReceiptParser.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Fixed Category False Positives & Date Extraction
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FIXES v2.0:
//  ✅ FIXED: "76" no longer matches item codes like "793016"
//  ✅ FIXED: TJ Maxx now priority 100 (matches before Gas keywords)
//  ✅ FIXED: Date extraction prefers dates with timestamps over "Respond by" dates
//  ✅ Added more retail brand keywords
//
//  Previous fixes preserved from v1.9:
//  - Merchant: Searches entire receipt
//  - Merchant: Known brand priority
//  - Amount: OCR normalization with scoring
//

import Foundation

struct ParsedReceipt {
    var amount: Double?
    var date: Date?
    var merchantName: String?
    var suggestedCategory: String?
    var notes: String?
    /// Last 4 digits extracted from a payment method line (e.g., "VISA ****1234")
    var paymentLastFour: String?
    /// Card network detected from OCR (e.g., "visa", "mastercard")
    var paymentNetwork: String?
}

final class ReceiptParser {
    static let shared = ReceiptParser()
    
    private init() {}
    
    func parseReceipt(text: String, isBillMode: Bool = false) -> ParsedReceipt {
        #if DEBUG
        print("================================================================================")
        print("📄 RAW OCR TEXT:")
        print(text)
        print("================================================================================")
        #endif

        var parsed = ParsedReceipt()

        parsed.amount = extractAmount(from: text, isBillMode: isBillMode)
        parsed.date = extractDate(from: text)
        parsed.merchantName = extractMerchant(from: text)
        parsed.suggestedCategory = suggestCategory(from: text)

        let cardInfo = extractPaymentCardInfo(from: text)
        parsed.paymentLastFour = cardInfo.lastFour
        parsed.paymentNetwork = cardInfo.network

        let notes = extractNotes(from: text, merchantName: parsed.merchantName)
        if !notes.isEmpty {
            parsed.notes = notes
        }
        
        #if DEBUG
        print("📋 Parsed Receipt:")
        print("  Amount: \(parsed.amount?.description ?? "nil")")
        print("  Date: \(parsed.date?.description ?? "nil")")
        print("  Merchant: \(parsed.merchantName ?? "nil")")
        print("  Category: \(parsed.suggestedCategory ?? "nil")")
        if let notes = parsed.notes {
            print("  Notes: \(notes)")
        }
        if let lastFour = parsed.paymentLastFour {
            print("  Card: \(parsed.paymentNetwork ?? "unknown") ****\(lastFour)")
        }
        #endif
        
        return parsed
    }
    
    // MARK: - Amount Extraction v3.0 (loyalty/points blacklist + column-layout peek fix)
    private func extractAmount(from text: String, isBillMode: Bool = false) -> Double? {
        let lines = text.components(separatedBy: .newlines)

        // v2.1: Bill-mode pre-pass — look for bill-specific labels where the amount
        // may be on the SAME line OR the NEXT line (common on medical/utility bills).
        // Scans BOTTOM-UP because the definitive "Amount Due" summary typically
        // appears at the end of the bill, while line-item details appear higher up.
        if isBillMode {
            let billKeywords = [
                "AMOUNT DUE", "BALANCE DUE", "TOTAL DUE", "PLEASE PAY",
                "PAY THIS AMOUNT", "PAYMENT DUE", "NOW DUE", "DUE AMOUNT",
                "AMOUNT OWED", "YOU OWE", "MINIMUM DUE", "MINIMUM PAYMENT"
            ]

            // Scan from the bottom of the document upward
            for index in stride(from: lines.count - 1, through: 0, by: -1) {
                let line = lines[index]
                let upperLine = line.uppercased()

                for keyword in billKeywords {
                    guard upperLine.contains(keyword) else { continue }

                    // Skip lines that are clearly itemized detail, not summary totals
                    // e.g. "Patient Balance Note: 1 - Deductible Amount (Amount: 86.83)"
                    if upperLine.contains("NOTE") || upperLine.contains("DETAIL") ||
                       upperLine.contains("DESCRIPTION") || upperLine.contains("CHARGES:") {
                        #if DEBUG
                        print("⏭️ Bill: skipping detail line: \(line.trimmingCharacters(in: .whitespaces))")
                        #endif
                        continue
                    }

                    // Try same-line amount first
                    if let amount = extractFirstAmount(from: line), amount > 0 && amount < 100_000 {
                        #if DEBUG
                        print("💵 Bill amount (same line): $\(amount) from: \(line.trimmingCharacters(in: .whitespaces))")
                        #endif
                        return amount
                    }

                    // Try next line (OCR often splits label and value onto adjacent lines)
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1]
                        if let amount = extractFirstAmount(from: nextLine), amount > 0 && amount < 100_000 {
                            #if DEBUG
                            print("💵 Bill amount (next line): $\(amount) from label: \(line.trimmingCharacters(in: .whitespaces))")
                            #endif
                            return amount
                        }
                    }
                }
            }

            #if DEBUG
            print("ℹ️ No bill-specific amount label found, falling back to receipt parser")
            #endif
        }

        // Standard receipt amount extraction (used as fallback for bills too)
        var candidates: [(amount: Double, score: Int, line: String)] = []

        // v3.0: Skip keywords — lines with these words should never provide an amount.
        // Categories:
        //   · Payment metadata: AUTH, APPROVED, TRACE, INVOICE, TERMINAL, CHANGE, CASH
        //   · Tax lines (we want the post-tax Total, not the tax itself): TAX ·, TAX:
        //   · Discounts and tip lines: TIP, DISCOUNT
        //   · Running balances: BALANCE, INITIAL (e.g. "Initial Balance"), FORWARD, PREVIOUS
        //   · Loyalty / rewards — showed up as the $274.28 "Total New Points" bug on
        //     Hustonville where a loyalty statement amount outranked the real total.
        //   · Fuel station per-unit metrics ($/gal, gallons) — never transaction totals.
        let skipWords = [
            "TIP", "APPROVED", "AUTH", "DISCOUNT",
            "CHANGE", "CASH",
            "TAX ", "TAX:",
            // Loyalty / rewards statements
            "POINTS", "POINT", "REWARDS", "REWARD", "SAVINGS",
            // Running balances & statement history
            "BALANCE", "INITIAL", "FORWARD", "PREVIOUS",
            // Fuel-station per-unit lines
            "PRICE/GAL", "NET/GAL", "DISC/GAL", "QTY (GAL)", "QTY(GAL)",
            // Bookkeeping / reference numbers that can contain amount-shaped digits
            "INVOICE", "TRACE", "TERMINAL"
        ]

        for (index, line) in lines.enumerated() {
            let upperLine = line.uppercased()

            // Skip invalid lines
            if skipWords.contains(where: { upperLine.contains($0) }) {
                continue
            }
            if upperLine.contains("%") { continue }

            // Check for "SUB" on same line
            if upperLine.contains("SUB") && (upperLine.contains("TOTAL") || upperLine.contains("0TAL")) {
                #if DEBUG
                print("⏭️ Skipping subtotal line: \(line)")
                #endif
                continue
            }

            // Normalize OCR errors (0→O, 1→I, etc.)
            let normalized = upperLine
                .replacingOccurrences(of: "0", with: "O")
                .replacingOccurrences(of: "1", with: "I")
                .replacingOccurrences(of: "5", with: "S")

            // Determine keyword score for this line
            var lineScore = 0
            if normalized.contains("TOTAL CHARGE") || normalized.contains("TOTAL AMT") ||
               normalized.contains("TOTAL AMOUNT") || normalized.contains("TOTAL TENDERED") ||
               normalized.contains("AMOUNT DUE") || normalized.contains("EMV TOTAL") ||
               normalized.contains("GRAND TOTAL") || normalized.contains("BALANCE DUE") {
                lineScore = 100
            } else if normalized.contains("TOTAL") || upperLine.contains("OTAL") {
                lineScore = 50
            } else if normalized.contains("AMOUNT:") || normalized.contains("AMT:") {
                lineScore = 10
            }

            // Extract amount from this line
            if let amount = extractFirstAmount(from: line), amount < 10000 {
                var score = lineScore
                if score == 0 && normalized.contains("PURCHASE") && amount > 1.0 {
                    score = 100
                }

                candidates.append((amount, score, line))

                #if DEBUG
                if score > 0 {
                    print("💰 Candidate: $\(amount) [score: \(score)] from: \(line.trimmingCharacters(in: .whitespaces))")
                }
                #endif
            }
            // v3.0: Keyword on this line but no amount — column-layout peek ahead.
            //
            // Column-layout receipts stack all labels in one block then all amounts
            // in another (sometimes with 10+ lines of payment/auth metadata between
            // them). The old "first amount wins" rule picked the first LINE-ITEM
            // price instead of the real total. We now collect every amount in the
            // peek window and return the LAST one, which on a column-layout receipt
            // is the summary total (line items come first, total comes last).
            //
            // Breaks on another top-tier scored keyword so each keyword still owns
            // its own amount and we don't merge two sections.
            else if lineScore >= 50, index + 1 < lines.count {
                let maxPeek = min(15, lines.count - index - 1)
                var collectedInPeek: [(amount: Double, offset: Int, line: String)] = []
                for peekOffset in 1...maxPeek {
                    let peekLine = lines[index + peekOffset]
                    let peekUpper = peekLine.uppercased()

                    // Stop on subtotal/sub-total — that's its own concept.
                    if peekUpper.contains("SUBTOTAL") || peekUpper.contains("SUB TOTAL") { break }

                    // Stop on another TOP-TIER keyword — that line deserves its own
                    // peek and its own amount.
                    let peekNormalized = peekUpper
                        .replacingOccurrences(of: "0", with: "O")
                        .replacingOccurrences(of: "1", with: "I")
                        .replacingOccurrences(of: "5", with: "S")
                    if peekNormalized.contains("TOTAL CHARGE") || peekNormalized.contains("TOTAL AMT") ||
                       peekNormalized.contains("TOTAL AMOUNT") || peekNormalized.contains("TOTAL TENDERED") ||
                       peekNormalized.contains("AMOUNT DUE") || peekNormalized.contains("GRAND TOTAL") ||
                       peekNormalized.contains("BALANCE DUE") {
                        break
                    }

                    // Skip noise lines (auth codes, loyalty labels, blank lines).
                    if skipWords.contains(where: { peekUpper.contains($0) }) { continue }
                    if peekLine.trimmingCharacters(in: .whitespaces).isEmpty { continue }

                    // Collect any amount but DON'T break — column layouts have several
                    // amounts in a row, and we want the last (summary) one.
                    if let amount = extractFirstAmount(from: peekLine), amount < 10_000 {
                        collectedInPeek.append((amount, peekOffset, peekLine))
                    }
                    // A non-amount residue line (like "CARD 3385" or "Customer Name :")
                    // between label block and amount block is common on column-layout
                    // receipts — keep peeking rather than breaking.
                }

                if let last = collectedInPeek.last {
                    candidates.append((last.amount, lineScore, last.line))
                    #if DEBUG
                    let picked = collectedInPeek.count > 1
                        ? " (last of \(collectedInPeek.count) amounts in peek block)"
                        : " (adjacent +\(last.offset))"
                    print("💰 Candidate (peek): $\(last.amount) [score: \(lineScore)] keyword: \(line.trimmingCharacters(in: .whitespaces))\(picked)")
                    #endif
                }
            }
        }

        guard !candidates.isEmpty else {
            #if DEBUG
            print("❌ No amount candidates found")
            #endif
            return nil
        }

        // Return highest scored, then highest value
        let best = candidates.max { first, second in
            if first.score != second.score {
                return first.score < second.score
            }
            return first.amount < second.amount
        }

        #if DEBUG
        if let best = best {
            print("✅ Selected amount: $\(best.amount) [score: \(best.score)]")
        }
        #endif

        return best?.amount
    }

    private func extractFirstAmount(from text: String) -> Double? {
        let pattern = "\\$?\\s?(\\d{1,3}(?:,\\d{3})*\\.\\d{2})"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: text) {
                let amountString = String(text[swiftRange]).replacingOccurrences(of: ",", with: "")
                return Double(amountString)
            }
        }
        
        return nil
    }
    
    // MARK: - Date Extraction v2.0 (FIXED: Prefers transaction dates with timestamps)
    private func extractDate(from text: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
        
        let lines = text.components(separatedBy: .newlines)
        
        // v2.0: FIRST look for dates with timestamps (these are transaction dates)
        // Pattern: MM-DD-YYYY HH:MM:SS or similar
        for line in lines {
            // Look for date followed by time pattern
            if line.contains(":") && (line.contains("-") || line.contains("/")) {
                // Try MM-DD-YYYY HH:MM:SS format
                if let match = line.firstMatch(of: #/(\d{1,2})-(\d{1,2})-(\d{4})\s+\d{1,2}:\d{2}/#) {
                    let month = String(match.1)
                    let day = String(match.2)
                    let year = String(match.3)
                    
                    let dateString = "\(month)/\(day)/\(year)"
                    dateFormatter.dateFormat = "M/d/yyyy"
                    
                    if let date = dateFormatter.date(from: dateString) {
                        #if DEBUG
                        print("📅 Date extracted (with timestamp): \(dateString) -> \(date)")
                        #endif
                        return date
                    }
                }
                
                // Try MM/DD/YYYY HH:MM format
                if let match = line.firstMatch(of: #/(\d{1,2})\/(\d{1,2})\/(\d{2,4})\s+\d{1,2}:\d{2}/#) {
                    let month = String(match.1)
                    let day = String(match.2)
                    var year = String(match.3)
                    
                    if year.count == 2, let yearInt = Int(year) {
                        year = yearInt <= 50 ? String(2000 + yearInt) : String(1900 + yearInt)
                    }
                    
                    let dateString = "\(month)/\(day)/\(year)"
                    dateFormatter.dateFormat = "M/d/yyyy"
                    
                    if let date = dateFormatter.date(from: dateString) {
                        #if DEBUG
                        print("📅 Date extracted (with timestamp): \(dateString) -> \(date)")
                        #endif
                        return date
                    }
                }
            }
        }
        
        // v2.0: Look for "Date:" label followed by date
        for line in lines {
            let upperLine = line.uppercased()
            if upperLine.contains("DATE:") || upperLine.contains("DATE :") {
                if let match = line.firstMatch(of: #/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})/#) {
                    let month = String(match.1)
                    let day = String(match.2)
                    var year = String(match.3)
                    
                    if year.count == 2, let yearInt = Int(year) {
                        year = yearInt <= 50 ? String(2000 + yearInt) : String(1900 + yearInt)
                    }
                    
                    let dateString = "\(month)/\(day)/\(year)"
                    dateFormatter.dateFormat = "M/d/yyyy"
                    
                    if let date = dateFormatter.date(from: dateString) {
                        #if DEBUG
                        print("📅 Date extracted (from Date: label): \(dateString) -> \(date)")
                        #endif
                        return date
                    }
                }
            }
        }
        
        // FALLBACK: Skip lines with "respond", "expires", "by" - these are NOT transaction dates
        for line in lines {
            let lowerLine = line.lowercased()
            
            // Skip survey/expiration dates
            if lowerLine.contains("respond") || lowerLine.contains("expires") ||
               lowerLine.contains("by ") || lowerLine.contains("valid") {
                continue
            }
            
            // Pattern: MM/DD/YYYY or MM/DD/YY
            if let match = line.firstMatch(of: #/(\d{1,2})\/(\d{1,2})\/(\d{2,4})/#) {
                let month = String(match.1)
                let day = String(match.2)
                var year = String(match.3)
                
                if year.count == 2, let yearInt = Int(year) {
                    year = yearInt <= 50 ? String(2000 + yearInt) : String(1900 + yearInt)
                }
                
                let dateString = "\(month)/\(day)/\(year)"
                dateFormatter.dateFormat = "M/d/yyyy"
                
                if let date = dateFormatter.date(from: dateString) {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    let noonDate = calendar.date(from: components) ?? date
                    
                    #if DEBUG
                    print("📅 Date extracted: \(dateString) -> \(noonDate)")
                    #endif
                    return noonDate
                }
            }
            
            // Pattern: MM-DD-YYYY
            if let match = line.firstMatch(of: #/(\d{1,2})-(\d{1,2})-(\d{2,4})/#) {
                let month = String(match.1)
                let day = String(match.2)
                var year = String(match.3)
                
                if year.count == 2, let yearInt = Int(year) {
                    year = yearInt <= 50 ? String(2000 + yearInt) : String(1900 + yearInt)
                }
                
                let dateString = "\(month)/\(day)/\(year)"
                dateFormatter.dateFormat = "M/d/yyyy"
                
                if let date = dateFormatter.date(from: dateString) {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    let noonDate = calendar.date(from: components) ?? date
                    
                    #if DEBUG
                    print("📅 Date extracted: \(dateString) -> \(noonDate)")
                    #endif
                    return noonDate
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Merchant Extraction v2.1 (FIXED: Skip promotional lines)
    private func extractMerchant(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)

        let skipKeywords = [
            "VISA", "MASTERCARD", "AMEX", "DISCOVER", "DEBIT", "CREDIT",
            "RECEIPT", "TRANSACTION", "APPROVED", "DECLINED", "AUTH",
            "SUBTOTAL", "TOTAL", "TAX", "CHANGE", "CASH", "PAYMENT",
            "THANK YOU", "THANKS", "CUSTOMER COPY", "MERCHANT COPY",
            "DATE", "TIME", "EXPIRES", "CONTACTLESS"
        ]

        // v2.1: Skip promotional / marketing lines that aren't merchant names
        let promoKeywords = [
            "BUY ONE", "GET ONE", "BOGO", "FREE", "COUPON", "PROMO",
            "DISCOUNT", "SPECIAL OFFER", "LIMITED TIME", "DEAL",
            "% OFF", "SAVE ", "SAVINGS", "EARN ", "REWARD",
            "SURVEY", "VALIDATION", "VALIDATION CODE",
            "VISIT ", "WWW.", "HTTP", ".COM",
            "SCAN ME", "SCAN TO", "QR CODE"
        ]
        
        let knownBrands = [
            "ollies bargain outlet", "tj maxx", "t.j. maxx", "tjmaxx",
            "walmart", "target", "starbucks", "whole foods", "trader joe",
            "cvs", "walgreens", "kroger", "safeway", "costco", "sams club",
            "home depot", "lowes", "best buy", "apple store", "amazon",
            "wings and rings", "w&r",
            // v2.1: Added fast food and common chains
            "mcdonald", "burger king", "wendy", "chick-fil-a", "chickfila",
            "taco bell", "subway", "chipotle", "popeyes", "arby",
            "dunkin", "sonic drive", "dairy queen", "domino", "pizza hut",
            "papa john", "five guys", "panera", "chili's", "applebee",
            "olive garden", "outback", "red lobster", "cracker barrel",
            "waffle house", "ihop", "denny"
        ]
        
        // First pass: Look for exact known brands
        // v2.2: Also apply promo filter so survey/feedback URLs don't win
        for line in lines {
            let lowerLine = line.lowercased()
            let upperLine = line.uppercased()

            // Skip promotional / survey / URL lines even for known brands
            if promoKeywords.contains(where: { upperLine.contains($0) }) {
                continue
            }

            for brand in knownBrands {
                if lowerLine.contains(brand) {
                    var cleaned = line
                    cleaned = cleaned.replacingOccurrences(of: "\\s+OF\\s+[A-Z][A-Z\\s]+$",
                                                           with: "", options: .regularExpression)
                    cleaned = cleaned.replacingOccurrences(of: "\\s*[#-]\\s*\\d{3,}$",
                                                           with: "", options: .regularExpression)
                    cleaned = cleaned.trimmingCharacters(in: .whitespaces)

                    #if DEBUG
                    print("✅ Found known brand: '\(cleaned.capitalized)' (matched '\(brand)')")
                    #endif
                    return cleaned.capitalized
                }
            }
        }
        
        // Second pass: Search entire receipt for merchant name
        for line in lines {
            let upperLine = line.uppercased()

            if skipKeywords.contains(where: { upperLine.contains($0) }) {
                continue
            }

            // v2.1: Skip promotional / marketing lines
            if promoKeywords.contains(where: { upperLine.contains($0) }) {
                continue
            }
            
            if line.count < 10 {
                continue
            }
            
            // Skip if starts with number (address)
            if line.first?.isNumber == true {
                continue
            }
            
            // Skip addresses/phones
            if line.contains(#/\d{3}[)\-\s]\d{3}[)\-\s]\d{4}/#) ||
               line.contains(#/\d{1,5}\s+\w+\s+(ST|AVE|RD|DR|BLVD|LN|STREET|AVENUE|ROAD|DRIVE|SUITE|STE|BYPASS)/#) ||
               line.contains(#/\b\d{5}\b/#) {
                continue
            }
            
            if line.rangeOfCharacter(from: CharacterSet.letters) == nil {
                continue
            }
            
            var cleaned = line
            cleaned = cleaned.replacingOccurrences(of: "\\s+OF\\s+[A-Z][A-Z\\s]+$",
                                                   with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "\\s*[#-]\\s*\\d{3,}$",
                                                   with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "\\s*[-–—]\\s*[A-Z]{2,}.*$",
                                                   with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "\\s{2,}",
                                                   with: " ", options: .regularExpression)
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            
            if cleaned.count >= 3 {
                #if DEBUG
                print("✅ Found merchant name: '\(cleaned.capitalized)' (from: '\(line)')")
                #endif
                return cleaned.capitalized
            }
        }
        
        return nil
    }
    
    // MARK: - Payment Card Info Extraction

    /// Extracts last 4 digits and card network from payment method lines.
    /// Handles patterns like: "VISA ****1234", "MASTERCARD ENDING 5678",
    /// "CARD #: ****9012", "AMEX x1234", "Visa ending in 5678"
    private func extractPaymentCardInfo(from text: String) -> (lastFour: String?, network: String?) {
        let lines = text.components(separatedBy: .newlines)

        // Network keywords → CardNetwork raw values
        let networkMap: [(keyword: String, network: String)] = [
            ("VISA", "visa"),
            ("MASTERCARD", "mastercard"),
            ("MASTER CARD", "mastercard"),
            ("MC", "mastercard"),
            ("AMEX", "amex"),
            ("AMERICAN EXPRESS", "amex"),
            ("DISCOVER", "discover"),
        ]

        // Regex patterns for last 4 digits (order by specificity)
        let patterns: [String] = [
            #"\*{2,}(\d{4})"#,                      // ****1234 or **1234
            #"[Xx]{2,}(\d{4})"#,                     // XXXX1234 or xx1234
            #"(?i)ending\s+(?:in\s+)?(\d{4})"#,     // "ending 1234" or "ending in 1234"
            #"(?i)card\s*#?\s*[:=]?\s*\*+(\d{4})"#, // "CARD #: ****1234"
            #"(?i)(?:VISA|MASTERCARD|AMEX|DISCOVER|MC)\s+[Xx]*(\d{4})"#, // "VISA 1234" or "VISA x1234"
        ]

        for line in lines {
            let upperLine = line.uppercased().trimmingCharacters(in: .whitespaces)

            // Check if this line mentions a card network
            var detectedNetwork: String?
            for (keyword, network) in networkMap {
                if upperLine.contains(keyword) {
                    detectedNetwork = network
                    break
                }
            }

            // Try each pattern for last-4
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: line) {
                    let lastFour = String(line[range])
                    return (lastFour, detectedNetwork)
                }
            }

            // If we found a network on this line but no digits, still note the network
            // (digits might be on next line — but don't return without digits)
        }

        return (nil, nil)
    }

    // MARK: - Notes Extraction v2.0
    private func extractNotes(from text: String, merchantName: String?) -> String {
        var notesParts: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Address
        for line in lines.prefix(15) {
            if line.contains(#/\d{1,5}\s+\w+\s+(ST|AVE|RD|DR|BLVD|SUITE|STE|BYPASS)/#) {
                let cleaned = line.trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty && cleaned.count < 60 {
                    notesParts.append("📍 \(cleaned)")
                    break
                }
            }
        }
        
        // City/state
        for line in lines.prefix(15) {
            let upperLine = line.uppercased()
            if (upperLine.contains(", KY") || upperLine.contains("KENTUCKY")) &&
               !line.contains(#/\d{3}[)\-\s]\d{3}/#) {
                let cleaned = line.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
                if !cleaned.isEmpty && cleaned.count < 60 {
                    notesParts.append("🏙️ \(cleaned)")
                    break
                }
            }
        }
        
        // Receipt number
        for line in lines {
            if let match = line.firstMatch(of: #/[IT]rn[:\s]*(\d{4,})/#) {
                notesParts.append("🧾 Receipt: \(match.1)")
                break
            }
        }
        
        // Store number
        for line in lines {
            if let match = line.firstMatch(of: #/Str[:\s]*(\d{3,})/#) {
                notesParts.append("🏪 Store #\(match.1)")
                break
            }
            if notesParts.count >= 4 { break }
        }
        
        return notesParts.joined(separator: "\n")
    }
    
    // MARK: - Category Suggestion v2.0 (FIXED: "76" false positive, better priority)
    private func suggestCategory(from text: String) -> String? {
        let lowercaseText = text.lowercased()
        
        // v2.0: Check specific retail brands FIRST at priority 100
        // This prevents item codes from accidentally matching gas station keywords
        let categoryRules: [(category: String, keywords: [String], priority: Int)] = [
            // Priority 100 - Specific RETAIL brands (check these FIRST to prevent false positives)
            ("Shopping", ["tj maxx", "tjmaxx", "t.j. maxx", "marshalls", "homegoods",
                          "ross", "ollies", "target", "kohls", "macys", "nordstrom",
                          "jcpenney", "burlington", "bed bath"], 100),
            ("Coffee", ["starbucks", "dunkin", "peets", "philz", "blue bottle", "dutch bros"], 100),
            ("Ride Share", ["uber", "lyft"], 100),
            ("Amazon", ["amazon.com", "amzn", "amazon"], 100),
            
            // Priority 95 - Restaurant chains with unique names
            ("Dining Out", ["wings and rings", "w&r ", "applebee", "chili's", "olive garden",
                           "outback", "red lobster", "texas roadhouse", "cracker barrel"], 95),
            
            // Priority 90 - Grocery and pharmacy chains
            ("Groceries", ["whole foods", "trader joe", "kroger", "safeway", "aldi",
                          "costco wholesale", "publix", "wegmans", "food lion", "piggly wiggly"], 90),
            ("Pharmacy", ["cvs", "walgreens", "rite aid"], 90),
            
            // Priority 90 - Gas stations (FIXED: removed "76", added specific brand names)
            // These keywords are specific enough to not match random item codes
            ("Gas", [
                "shell gas", "chevron gas", "exxon", "exxonmobil", "valero", "arco gas",
                "circle k fuel", "quiktrip", "sheetz", "wawa fuel", "racetrac", "murphy usa",
                "costco gas", "sams club fuel", "union 76", "76 gas station", "phillips 66",
                "speedway gas", "marathon gas", "getty gas", "sunoco", "citgo", "bp gas"
            ], 90),
            
            // Priority 80
            ("Fast Food", ["mcdonald", "chipotle", "taco bell", "wendy", "burger king",
                          "subway", "kfc", "chick-fil-a", "popeyes", "arby", "sonic drive"], 80),
            
            // Priority 70
            ("Dining Out", ["restaurant", "cafe", "coffee", "pizza", "burger", "dining",
                           "bar ", "grab n go", "grill", "kitchen", "wings", "bistro",
                           "tavern", "pub ", "brewery"], 70),
            ("Shopping", ["bargain", "outlet", "mall ", "boutique"], 70),
            ("Healthcare", ["nails", "spa ", "salon", "pharmacy", "drug", "medical",
                           "doctor", "hospital", "clinic", "dental", "vision"], 70),
            
            // Priority 60
            ("Groceries", ["grocery", "market", "food", "walmart supercenter"], 60),
            ("Shopping", ["store", "shop ", "clothing", "apparel"], 60),
            ("Entertainment", ["theater", "cinema", "movie", "concert", "game",
                              "entertainment", "netflix", "spotify", "amc "], 60),
            ("Transportation", ["parking", "taxi"], 60),
            ("Utilities", ["electric", "power company", "gas company", "water company",
                          "internet", "cable", "phone bill", "at&t", "verizon", "spectrum"], 60)
        ]
        
        for rule in categoryRules.sorted(by: { $0.priority > $1.priority }) {
            if rule.keywords.contains(where: { lowercaseText.contains($0) }) {
                #if DEBUG
                print("🏷️ Category '\(rule.category)' matched (priority: \(rule.priority))")
                #endif
                return rule.category
            }
        }
        
        return nil
    }
}
