//  TransferService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed SwiftData Predicate Issue
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Core service for transfer operations with true double-entry accounting.
//
//  CHANGES v1.1:
//  ✅ FIXED: SwiftData predicate error - capture TaxAuthority.rawValue before closure
//
//  FEATURES:
//  ✅ Double-entry: Updates both fromAccount and toAccount balances atomically
//  ✅ Transfer type auto-detection based on account finance types
//  ✅ CSV import matching: Links withdrawals to deposits by amount, date, last4
//  ✅ Recurring transfer generation
//  ✅ YTD equity calculations (draws, contributions)
//  ✅ Transaction linking for bank-imported transfers
//

import Foundation
import SwiftData

// MARK: - Transfer Service

@MainActor
final class TransferService {
    
    // MARK: - Singleton
    
    static let shared = TransferService()
    private init() {}
    
    // MARK: - Create Transfer (Double-Entry)
    
    /// Creates a transfer with true double-entry behavior.
    /// Updates both account balances atomically.
    ///
    /// - Parameters:
    ///   - context: The SwiftData model context
    ///   - amount: Amount to transfer (must be positive)
    ///   - fromAccount: Source account
    ///   - toAccount: Destination account
    ///   - date: Transfer date (defaults to now)
    ///   - notes: Optional notes
    ///   - reference: Optional reference number
    ///   - transferType: Override auto-detection (nil = auto-detect)
    ///   - taxQuarter: For tax payments
    ///   - taxYear: For tax payments
    ///   - taxAuthority: For tax payments
    ///   - recurringTransfer: Link to recurring if generated
    ///
    /// - Returns: The created Transfer, or nil if validation fails
    @discardableResult
    func createTransfer(
        context: ModelContext,
        amount: Double,
        fromAccount: Account,
        toAccount: Account,
        date: Date = Date(),
        notes: String? = nil,
        reference: String? = nil,
        transferType: TransferType? = nil,
        taxQuarter: Int? = nil,
        taxYear: Int? = nil,
        taxAuthority: TaxAuthority? = nil,
        recurringTransfer: RecurringTransfer? = nil
    ) -> Transfer? {
        
        // Validation
        guard amount > 0 else {
            print("❌ TransferService: Amount must be positive")
            return nil
        }
        
        guard fromAccount.id != toAccount.id else {
            print("❌ TransferService: Cannot transfer to the same account")
            return nil
        }
        
        // Auto-detect transfer type if not provided
        let detectedType = transferType ?? detectTransferType(
            from: fromAccount,
            to: toAccount
        )
        
        // Create the transfer record
        let transfer = Transfer(
            date: date,
            amount: amount,
            transferType: detectedType,
            status: .completed,
            fromAccount: fromAccount,
            toAccount: toAccount,
            notes: notes,
            reference: reference,
            taxQuarter: taxQuarter,
            taxYear: taxYear,
            taxAuthority: taxAuthority,
            recurringTransfer: recurringTransfer
        )
        
        // Double-entry: Update account balances
        updateAccountBalances(
            fromAccount: fromAccount,
            toAccount: toAccount,
            amount: amount,
            isCreating: true
        )
        
        // Insert the transfer
        context.insert(transfer)
        
        // Save immediately to ensure atomicity
        do {
            try context.save()
            print("✅ TransferService: Created \(detectedType.displayName) for \(transfer.formattedAmount)")
            return transfer
        } catch {
            print("❌ TransferService: Failed to save transfer: \(error)")
            // Rollback balance changes
            updateAccountBalances(
                fromAccount: fromAccount,
                toAccount: toAccount,
                amount: amount,
                isCreating: false  // Reverse
            )
            return nil
        }
    }
    
    // MARK: - Update Transfer
    
    /// Updates an existing transfer, adjusting account balances as needed.
    func updateTransfer(
        context: ModelContext,
        transfer: Transfer,
        newAmount: Double? = nil,
        newFromAccount: Account? = nil,
        newToAccount: Account? = nil,
        newDate: Date? = nil,
        newNotes: String? = nil,
        newReference: String? = nil,
        newTransferType: TransferType? = nil
    ) -> Bool {
        
        let oldAmount = transfer.amount
        let oldFromAccount = transfer.fromAccount
        let oldToAccount = transfer.toAccount
        
        // Reverse old balance changes if accounts or amount changed
        let accountsChanged = (newFromAccount != nil && newFromAccount?.id != oldFromAccount?.id) ||
                              (newToAccount != nil && newToAccount?.id != oldToAccount?.id)
        let amountChanged = newAmount != nil && newAmount != oldAmount
        
        if (accountsChanged || amountChanged), let oldFrom = oldFromAccount, let oldTo = oldToAccount {
            // Reverse the old transfer
            updateAccountBalances(
                fromAccount: oldFrom,
                toAccount: oldTo,
                amount: oldAmount,
                isCreating: false
            )
        }
        
        // Apply new values
        if let amount = newAmount {
            transfer.amount = abs(amount)
        }
        if let from = newFromAccount {
            transfer.fromAccount = from
        }
        if let to = newToAccount {
            transfer.toAccount = to
        }
        if let date = newDate {
            transfer.date = date
        }
        if let notes = newNotes {
            transfer.notes = notes
        }
        if let reference = newReference {
            transfer.reference = reference
        }
        if let type = newTransferType {
            transfer.transferType = type
        }
        
        transfer.updatedAt = Date()
        
        // Apply new balance changes
        if (accountsChanged || amountChanged), let newFrom = transfer.fromAccount, let newTo = transfer.toAccount {
            updateAccountBalances(
                fromAccount: newFrom,
                toAccount: newTo,
                amount: transfer.amount,
                isCreating: true
            )
        }
        
        // Save
        do {
            try context.save()
            print("✅ TransferService: Updated transfer")
            return true
        } catch {
            print("❌ TransferService: Failed to update transfer: \(error)")
            return false
        }
    }
    
    // MARK: - Delete Transfer
    
    /// Deletes a transfer and reverses account balance changes.
    func deleteTransfer(context: ModelContext, transfer: Transfer) -> Bool {
        
        // Reverse balance changes
        if let fromAccount = transfer.fromAccount, let toAccount = transfer.toAccount {
            updateAccountBalances(
                fromAccount: fromAccount,
                toAccount: toAccount,
                amount: transfer.amount,
                isCreating: false  // Reverse
            )
        }
        
        // Delete the transfer
        context.delete(transfer)
        
        do {
            try context.save()
            print("✅ TransferService: Deleted transfer")
            return true
        } catch {
            print("❌ TransferService: Failed to delete transfer: \(error)")
            return false
        }
    }
    
    // MARK: - Balance Updates (Double-Entry Core)
    
    /// Updates account balances for a transfer.
    /// For creation: decreases fromAccount, increases toAccount
    /// For deletion: reverses the above
    private func updateAccountBalances(
        fromAccount: Account,
        toAccount: Account,
        amount: Double,
        isCreating: Bool
    ) {
        if isCreating {
            // Money leaves fromAccount
            fromAccount.currentBalance -= amount
            
            // Money enters toAccount
            // Special handling for credit cards (negative balance = debt)
            if toAccount.accountType == .creditCard {
                // Paying a credit card reduces the debt (makes it less negative)
                toAccount.currentBalance += amount
            } else {
                toAccount.currentBalance += amount
            }
            
            print("   💰 Balance update: \(fromAccount.name) -\(amount), \(toAccount.name) +\(amount)")
        } else {
            // Reverse: money returns to fromAccount
            fromAccount.currentBalance += amount
            
            if toAccount.accountType == .creditCard {
                toAccount.currentBalance -= amount
            } else {
                toAccount.currentBalance -= amount
            }
            
            print("   💰 Balance reversal: \(fromAccount.name) +\(amount), \(toAccount.name) -\(amount)")
        }
    }
    
    // MARK: - Transfer Type Detection
    
    /// Auto-detects the appropriate transfer type based on account types and finance types.
    func detectTransferType(from: Account, to: Account) -> TransferType {
        
        // Credit card or loan payment
        if to.accountType == .creditCard || to.accountType == .loan {
            return .debtPayment
        }
        
        // Cross finance type detection
        if from.financeType == .business && to.financeType == .personal {
            return .ownersDraw
        }
        
        if from.financeType == .personal && to.financeType == .business {
            return .capitalContribution
        }
        
        // Same finance type = internal
        return .internal
    }
    
    // MARK: - CSV Import Matching
    
    /// Matches potential transfer pairs from CSV import.
    /// Looks for withdrawals and deposits that match by amount, date, and optionally last4.
    ///
    /// - Parameters:
    ///   - transactions: Parsed CSV transactions
    ///   - dateToleranceDays: How many days apart to consider a match (default: 3)
    ///
    /// - Returns: Array of matched pairs (withdrawal index, deposit index, confidence)
    func matchTransferPairs(
        transactions: [CSVParsedTransaction],
        dateToleranceDays: Int = 3
    ) -> [(withdrawalIndex: Int, depositIndex: Int, confidence: Double)] {
        
        var matches: [(Int, Int, Double)] = []
        var usedIndices = Set<Int>()
        
        // Find all expenses (potential withdrawals)
        let withdrawals = transactions.enumerated().filter { !$0.element.isIncome }
        
        // Find all income (potential deposits)
        let deposits = transactions.enumerated().filter { $0.element.isIncome }
        
        for (wIndex, withdrawal) in withdrawals {
            guard !usedIndices.contains(wIndex) else { continue }
            
            let withdrawalAmount = abs(withdrawal.amount)
            let withdrawalDate = withdrawal.date
            let withdrawalLast4 = extractLast4(from: withdrawal.description + " " + withdrawal.merchantName)
            
            var bestMatch: (index: Int, confidence: Double)? = nil
            
            for (dIndex, deposit) in deposits {
                guard !usedIndices.contains(dIndex) else { continue }
                
                let depositAmount = abs(deposit.amount)
                let depositDate = deposit.date
                let depositLast4 = extractLast4(from: deposit.description + " " + deposit.merchantName)
                
                // Amount must match exactly
                guard abs(withdrawalAmount - depositAmount) < 0.01 else { continue }
                
                // Date must be within tolerance
                let daysDiff = abs(Calendar.current.dateComponents([.day], from: withdrawalDate, to: depositDate).day ?? 999)
                guard daysDiff <= dateToleranceDays else { continue }
                
                // Calculate confidence
                var confidence: Double = 0.5  // Base confidence for amount match
                
                // Same day = higher confidence
                if daysDiff == 0 {
                    confidence += 0.2
                } else if daysDiff == 1 {
                    confidence += 0.1
                }
                
                // Last 4 digits match = highest confidence
                if let w4 = withdrawalLast4, let d4 = depositLast4, w4 == d4 {
                    confidence += 0.3
                }
                
                // Check for transfer keywords
                let transferKeywords = ["transfer", "xfer", "ach", "wire", "zelle", "venmo", "paypal"]
                let wText = (withdrawal.merchantName + " " + withdrawal.description).lowercased()
                let dText = (deposit.merchantName + " " + deposit.description).lowercased()
                
                if transferKeywords.contains(where: { wText.contains($0) || dText.contains($0) }) {
                    confidence += 0.1
                }
                
                // Keep best match
                if bestMatch == nil || confidence > bestMatch!.confidence {
                    bestMatch = (dIndex, min(confidence, 1.0))
                }
            }
            
            if let match = bestMatch, match.confidence >= 0.5 {
                matches.append((wIndex, match.index, match.confidence))
                usedIndices.insert(wIndex)
                usedIndices.insert(match.index)
            }
        }
        
        return matches
    }
    
    /// Extracts last 4 digits of an account number from text
    private func extractLast4(from text: String) -> String? {
        // Look for patterns like "...1234", "x1234", "****1234", "ending in 1234"
        let patterns = [
            "\\d{4}$",                    // Ends with 4 digits
            "x(\\d{4})",                  // x1234
            "\\*(\\d{4})",                // *1234
            "ending in (\\d{4})",         // ending in 1234
            "\\.\\.\\.(\\d{4})"           // ...1234
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    // Get the last group (the 4 digits)
                    let groupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
                    if let swiftRange = Range(groupRange, in: text) {
                        let result = String(text[swiftRange])
                        if result.count == 4, result.allSatisfy({ $0.isNumber }) {
                            return result
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Recurring Transfer Generation
    
    /// Generates any due transfers from recurring schedules.
    func generateDueRecurringTransfers(context: ModelContext) -> [Transfer] {
        var generated: [Transfer] = []
        
        // Fetch all active recurring transfers
        let descriptor = FetchDescriptor<RecurringTransfer>(
            predicate: #Predicate { $0.isActive }
        )
        
        guard let recurring = try? context.fetch(descriptor) else {
            print("⚠️ TransferService: Could not fetch recurring transfers")
            return []
        }
        
        for schedule in recurring {
            guard schedule.isDueToday else { continue }
            guard let fromAccount = schedule.fromAccount,
                  let toAccount = schedule.toAccount else {
                print("⚠️ TransferService: Recurring \(schedule.name) missing accounts")
                continue
            }
            
            // Determine tax fields for tax payments
            var taxQuarter: Int? = nil
            var taxYear: Int? = nil
            
            if schedule.transferType == .taxPayment {
                let calendar = Calendar.current
                taxQuarter = TaxSettings.quarterNumber(for: Date())
                taxYear = calendar.component(.year, from: Date())
            }
            
            // Create the transfer
            if let transfer = createTransfer(
                context: context,
                amount: schedule.amount,
                fromAccount: fromAccount,
                toAccount: toAccount,
                date: Date(),
                notes: schedule.notes,
                transferType: schedule.transferType,
                taxQuarter: taxQuarter,
                taxYear: taxYear,
                taxAuthority: schedule.taxAuthority,
                recurringTransfer: schedule
            ) {
                // Update recurring state
                schedule.lastGeneratedDate = Date()
                schedule.generatedCount += 1
                schedule.updatedAt = Date()
                
                generated.append(transfer)
                print("✅ Generated recurring: \(schedule.name)")
            }
        }
        
        return generated
    }
    
    // MARK: - YTD Equity Calculations
    
    /// Calculates year-to-date owner's draws.
    func calculateYTDDraws(context: ModelContext, year: Int? = nil) -> Double {
        let targetYear = year ?? Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        
        let startOfYear = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: targetYear, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        
        let descriptor = FetchDescriptor<Transfer>(
            predicate: #Predicate<Transfer> { transfer in
                transfer.transferTypeRaw == "ownersDraw" &&
                transfer.date >= startOfYear &&
                transfer.date <= endOfYear
            }
        )
        
        guard let transfers = try? context.fetch(descriptor) else { return 0 }
        return transfers.reduce(0) { $0 + $1.amount }
    }
    
    /// Calculates year-to-date capital contributions.
    func calculateYTDContributions(context: ModelContext, year: Int? = nil) -> Double {
        let targetYear = year ?? Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        
        let startOfYear = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: targetYear, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        
        let descriptor = FetchDescriptor<Transfer>(
            predicate: #Predicate<Transfer> { transfer in
                transfer.transferTypeRaw == "capitalContribution" &&
                transfer.date >= startOfYear &&
                transfer.date <= endOfYear
            }
        )
        
        guard let transfers = try? context.fetch(descriptor) else { return 0 }
        return transfers.reduce(0) { $0 + $1.amount }
    }
    
    /// Calculates year-to-date tax payments by authority.
    func calculateYTDTaxPayments(
        context: ModelContext,
        authority: TaxAuthority? = nil,
        year: Int? = nil
    ) -> Double {
        let targetYear = year ?? Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        
        let startOfYear = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: targetYear, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        
        var descriptor: FetchDescriptor<Transfer>
        
        if let auth = authority {
            let authorityRaw = auth.rawValue  // Capture string before predicate
            descriptor = FetchDescriptor<Transfer>(
                predicate: #Predicate<Transfer> { transfer in
                    transfer.transferTypeRaw == "taxPayment" &&
                    transfer.taxAuthorityRaw == authorityRaw &&
                    transfer.date >= startOfYear &&
                    transfer.date <= endOfYear
                }
            )
        } else {
            descriptor = FetchDescriptor<Transfer>(
                predicate: #Predicate<Transfer> { transfer in
                    transfer.transferTypeRaw == "taxPayment" &&
                    transfer.date >= startOfYear &&
                    transfer.date <= endOfYear
                }
            )
        }
        
        guard let transfers = try? context.fetch(descriptor) else { return 0 }
        return transfers.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Transfer Summary

/// Summary data for Move Money view header
struct TransferSummary {
    let businessBalance: Double
    let personalBalance: Double
    let ytdDraws: Double
    let ytdContributions: Double
    let ytdTaxPayments: Double
    let pendingCount: Int
}

extension TransferService {
    
    /// Generates a summary for the Move Money view header.
    func generateSummary(context: ModelContext, accounts: [Account]) -> TransferSummary {
        let businessAccounts = accounts.filter { $0.financeType == .business && $0.isActive }
        let personalAccounts = accounts.filter { $0.financeType == .personal && $0.isActive }
        
        let businessBalance = businessAccounts.reduce(0) { $0 + $1.currentBalance }
        let personalBalance = personalAccounts.reduce(0) { $0 + $1.currentBalance }
        
        // Count pending transfers
        let pendingDescriptor = FetchDescriptor<Transfer>(
            predicate: #Predicate<Transfer> { $0.statusRaw == "pending" }
        )
        let pendingCount = (try? context.fetchCount(pendingDescriptor)) ?? 0
        
        return TransferSummary(
            businessBalance: businessBalance,
            personalBalance: personalBalance,
            ytdDraws: calculateYTDDraws(context: context),
            ytdContributions: calculateYTDContributions(context: context),
            ytdTaxPayments: calculateYTDTaxPayments(context: context),
            pendingCount: pendingCount
        )
    }
}
