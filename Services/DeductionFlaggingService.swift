//  DeductionFlaggingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - MVP Deployment Ready
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Proactive tax deduction reminders and end-of-year summaries
//

import Foundation
import SwiftData
import UserNotifications

class DeductionFlaggingService {
    static let shared = DeductionFlaggingService()
    
    private init() {}
    
    // MARK: - Deduction Flagging
    
    /// Check for receipts that need attention
    func checkForUncategorizedReceipts(context: ModelContext) async {
        let descriptor = FetchDescriptor<ReceiptData>()
        guard let receipts = try? context.fetch(descriptor) else { return }
        
        let needsAttention = receipts.filter { receipt in
            // Receipt needs attention if:
            // 1. No category assigned
            // 2. Not yet flagged
            // 3. Over $50 (significant amount)
            // 4. More than 3 days old
            
            let daysOld = Date().timeIntervalSince(receipt.date) / (24 * 60 * 60)
            
            return receipt.suggestedCategoryName == nil &&
                   !receipt.deductionFlagged &&
                   receipt.totalAmount >= 50 &&
                   daysOld >= 3
        }
        
        for receipt in needsAttention {
            await flagReceiptForAttention(receipt: receipt, context: context)
            // Save per receipt to prevent data loss if app terminates
            try? context.save()
        }
        
        #if DEBUG
        if !needsAttention.isEmpty {
            print("🚩 Flagged \(needsAttention.count) receipts for attention")
        }
        #endif
    }
    
    /// Flag a specific receipt for user attention
    private func flagReceiptForAttention(
        receipt: ReceiptData,
        context: ModelContext
    ) async {
        receipt.deductionFlagged = true
        receipt.deductionFlaggedDate = Date()
        receipt.modifiedDate = Date()
        
        // Send notification
        await sendDeductionNotification(
            title: "Uncategorized Purchase",
            body: "Don't forget to categorize your $\(String(format: "%.2f", receipt.totalAmount)) purchase at \(receipt.merchantName) - it could be a tax write-off!",
            receiptID: receipt.id.uuidString
        )
    }
    
    // MARK: - Year-End Summary
    
    /// Generate year-end tax deduction summary
    func generateYearEndSummary(
        year: Int,
        context: ModelContext
    ) -> DeductionSummary {
        let calendar = Calendar.current
        
        // Better date boundary handling
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYearStart = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return DeductionSummary(year: year, categories: [:], totalDeductions: 0, uncategorizedCount: 0, uncategorizedAmount: 0)
        }
        
        let yearEnd = nextYearStart.addingTimeInterval(-1)
        
        // Fetch all receipts from the year
        let descriptor = FetchDescriptor<ReceiptData>()
        guard let allReceipts = try? context.fetch(descriptor) else {
            return DeductionSummary(year: year, categories: [:], totalDeductions: 0, uncategorizedCount: 0, uncategorizedAmount: 0)
        }
        
        let yearReceipts = allReceipts.filter { receipt in
            receipt.date >= yearStart && receipt.date <= yearEnd
        }
        
        // Group by category
        var categoryTotals: [String: Double] = [:]
        var uncategorizedCount = 0
        var uncategorizedAmount: Double = 0
        var totalDeductions: Double = 0
        
        for receipt in yearReceipts {
            // FIX: Use deductibleAmount (respects businessPercentage)
            let amount = receipt.deductibleAmount
            
            if let categoryName = receipt.suggestedCategoryName,
               receipt.isTaxDeductible {
                categoryTotals[categoryName, default: 0] += amount
                totalDeductions += amount
            } else if receipt.suggestedCategoryName == nil && receipt.businessPercentage > 0 {
                // FIX: Only count uncategorized if it has business portion
                uncategorizedCount += 1
                uncategorizedAmount += amount
            }
        }
        
        return DeductionSummary(
            year: year,
            categories: categoryTotals,
            totalDeductions: totalDeductions,
            uncategorizedCount: uncategorizedCount,
            uncategorizedAmount: uncategorizedAmount
        )
    }
    
    /// Send year-end reminder notification
    func sendYearEndReminder(context: ModelContext) async {
        let currentYear = Calendar.current.component(.year, from: Date())
        let summary = generateYearEndSummary(year: currentYear, context: context)
        
        if summary.uncategorizedCount > 0 {
            await sendDeductionNotification(
                title: "Year-End Tax Reminder",
                body: "You have \(summary.uncategorizedCount) uncategorized receipts worth $\(String(format: "%.2f", summary.uncategorizedAmount)). Review them to maximize your deductions!",
                receiptID: nil
            )
        }
        
        #if DEBUG
        print("📊 Year-end summary: $\(String(format: "%.2f", summary.totalDeductions)) in deductions, \(summary.uncategorizedCount) uncategorized")
        #endif
    }
    
    // MARK: - Deduction Opportunities
    
    /// Identify potential missed deductions
    func identifyMissedDeductions(context: ModelContext) -> [DeductionOpportunity] {
        var opportunities: [DeductionOpportunity] = []
        
        // Check for receipts marked as personal that might be business
        let descriptor = FetchDescriptor<ReceiptData>()
        guard let receipts = try? context.fetch(descriptor) else { return [] }
        
        let potentialDeductions = receipts.filter { receipt in
            // Non-deductible receipts that match typical business categories
            !receipt.isTaxDeductible &&
            receipt.businessPercentage == 0 &&
            isLikelyBusinessExpense(merchant: receipt.merchantName, amount: receipt.totalAmount)
        }
        
        for receipt in potentialDeductions {
            let opportunity = DeductionOpportunity(
                receipt: receipt,
                reason: "This purchase at \(receipt.merchantName) might be a business expense",
                potentialDeduction: receipt.totalAmount,
                confidence: 0.6
            )
            opportunities.append(opportunity)
        }
        
        // Check for patterns (e.g., regular Starbucks purchases during work hours)
        opportunities.append(contentsOf: findPatternBasedOpportunities(receipts: receipts))
        
        #if DEBUG
        print("💡 Found \(opportunities.count) deduction opportunities")
        #endif
        
        return opportunities
    }
    
    private func isLikelyBusinessExpense(merchant: String, amount: Double) -> Bool {
        let businessKeywords = [
            "office", "supply", "depot", "staples",
            "amazon", "best buy", "apple",
            "fedex", "ups", "usps",
            "zoom", "microsoft", "adobe",
            "linkedin", "facebook", "google"
        ]
        
        let lowerMerchant = merchant.lowercased()
        
        for keyword in businessKeywords {
            if lowerMerchant.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    private func findPatternBasedOpportunities(receipts: [ReceiptData]) -> [DeductionOpportunity] {
        var opportunities: [DeductionOpportunity] = []
        
        // Group receipts by merchant
        let merchantGroups = Dictionary(grouping: receipts) { $0.merchantName }
        
        for (merchant, merchantReceipts) in merchantGroups {
            // If user has 5+ receipts at same merchant, some marked business and some personal
            // suggest reviewing the personal ones
            let businessReceipts = merchantReceipts.filter { $0.businessPercentage > 0 }
            let personalReceipts = merchantReceipts.filter { $0.businessPercentage == 0 }
            
            if businessReceipts.count >= 3 && personalReceipts.count >= 2 {
                // Pattern detected: user usually uses this merchant for business
                for receipt in personalReceipts {
                    let opportunity = DeductionOpportunity(
                        receipt: receipt,
                        reason: "You typically use \(merchant) for business expenses",
                        potentialDeduction: receipt.totalAmount,
                        confidence: 0.7
                    )
                    opportunities.append(opportunity)
                }
            }
        }
        
        return opportunities
    }
    
    // MARK: - Notifications
    
    private func sendDeductionNotification(
        title: String,
        body: String,
        receiptID: String?
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "DEDUCTION_REMINDER"
        
        if let receiptID = receiptID {
            content.userInfo = ["receiptID": receiptID]
        }
        
        let request = UNNotificationRequest(
            identifier: receiptID ?? UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("📬 Sent deduction notification: \(title)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to send notification: \(error)")
            #endif
        }
    }
    
    // MARK: - Scheduled Tasks
    
    /// Run weekly check for uncategorized receipts
    func scheduleWeeklyCheck() async {
        let identifier = "weekly-receipt-review"
        
        // FIX: Remove existing to prevent duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Schedule notification for every Sunday at 6 PM
        let content = UNMutableNotificationContent()
        content.title = "Weekly Receipt Review"
        content.body = "Take a few minutes to review your receipts this week"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REVIEW"
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 18     // 6 PM
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("✅ Scheduled weekly receipt review")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule weekly check: \(error)")
            #endif
        }
    }
    
    /// Schedule year-end reminder (December 15th)
    func scheduleYearEndReminder() async {
        let identifier = "year-end-reminder"
        
        // FIX: Remove existing to prevent duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Year-End Tax Reminder"
        content.body = "Review your receipts before year-end to maximize tax deductions"
        content.sound = .default
        content.categoryIdentifier = "YEAR_END"
        
        var dateComponents = DateComponents()
        dateComponents.month = 12
        dateComponents.day = 15
        dateComponents.hour = 10
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("✅ Scheduled year-end reminder")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule year-end reminder: \(error)")
            #endif
        }
    }
}

// MARK: - ReceiptData Extension

extension ReceiptData {
    /// Computed property for deductible amount (respects business percentage)
    var deductibleAmount: Double {
        totalAmount * (Double(businessPercentage) / 100.0)
    }
}

// MARK: - Supporting Types

struct DeductionSummary {
    let year: Int
    let categories: [String: Double]  // Category name → Total amount
    let totalDeductions: Double
    let uncategorizedCount: Int
    let uncategorizedAmount: Double
    
    var topCategories: [(name: String, amount: Double)] {
        categories.map { (name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
    var potentialSavings: Double {
        // Assume 30% effective tax rate for rough estimate
        totalDeductions * 0.30
    }
}

struct DeductionOpportunity {
    let receipt: ReceiptData
    let reason: String
    let potentialDeduction: Double
    let confidence: Double  // 0.0 to 1.0
    
    var estimatedSavings: Double {
        potentialDeduction * 0.30  // Rough 30% tax rate
    }
}
