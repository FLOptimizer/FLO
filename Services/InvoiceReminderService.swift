//  InvoiceReminderService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - Updated for InvoiceService v4.0 compatibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v1.5:
//  - Updated to use getInvoicesNeedingRemindersLegacy() for InvoiceService v4.0
//  - Service for automatic invoice reminders and notifications
//

import Foundation
import UserNotifications
import SwiftData

// MARK: - Notification Names for Invoice Actions

extension Notification.Name {
    static let invoiceActionMarkPaid = Notification.Name("invoiceActionMarkPaid")
    static let invoiceActionSendReminder = Notification.Name("invoiceActionSendReminder")
    static let invoiceActionViewInvoice = Notification.Name("invoiceActionViewInvoice")
}

@MainActor
@Observable
class InvoiceReminderService {
    static let shared = InvoiceReminderService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Notification Setup
    
    /// Request notification permissions with user-friendly explanation
        func requestNotificationPermissions() async -> Bool {
            // Use helper to show explanation before system prompt
            return await withCheckedContinuation { continuation in
                NotificationPermissionHelper.requestWithExplanation(context: .invoiceAlerts) { granted in
                    if granted {
                        print("✅ Invoice reminder notifications authorized")
                        self.configureNotificationCategories()
                    } else {
                        print("⚠️ Invoice reminder notifications denied")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    
    /// Configure notification categories and actions
    func configureNotificationCategories() {
        // Invoice Overdue Category
        let markAsPaidAction = UNNotificationAction(
            identifier: "MARK_PAID",
            title: "Mark as Paid",
            options: [.foreground]
        )
        
        let sendReminderAction = UNNotificationAction(
            identifier: "SEND_REMINDER",
            title: "Send Reminder",
            options: []
        )
        
        let viewInvoiceAction = UNNotificationAction(
            identifier: "VIEW_INVOICE",
            title: "View Invoice",
            options: [.foreground]
        )
        
        let overdueCategory = UNNotificationCategory(
            identifier: "INVOICE_OVERDUE",
            actions: [markAsPaidAction, sendReminderAction, viewInvoiceAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Invoice Due Soon Category
        let dueSoonCategory = UNNotificationCategory(
            identifier: "INVOICE_DUE_SOON",
            actions: [viewInvoiceAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([overdueCategory, dueSoonCategory])
        
        print("Invoice notification categories configured")
    }
    
    // MARK: - Reminder Scheduling
    
    /// Schedule all pending reminders for invoices
    /// Updated for InvoiceService v4.0 - uses legacy non-throwing method
    func scheduleAllReminders(context: ModelContext) async {
        // Clear existing invoice reminders
        await clearAllScheduledReminders()
        
        // Use legacy method for backward compatibility with InvoiceService v4.0
        let invoices = InvoiceService.shared.getInvoicesNeedingRemindersLegacy(context: context)
        
        for invoice in invoices {
            await scheduleReminder(for: invoice)
        }
        
        print("Scheduled \(invoices.count) invoice reminders")
    }
    
    // MARK: - Helper Methods
    
    /// Calculate next 9 AM from now (today or tomorrow)
    private func triggerForNext9AM() -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current
        let now = Date()
        let components = DateComponents(hour: 9, minute: 0)
        
        guard let next9AM = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else {
            // Rare fallback: tomorrow 9 AM
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let fallback = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fallback)
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }
        
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next9AM)
        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    }
    
    /// Schedule reminder for a specific invoice
    func scheduleReminder(for invoice: Invoice, immediately: Bool = false) async {
        guard let client = invoice.client else { return }
        
        // Don't send reminders if client has them disabled
        guard client.allowReminders else {
            print("Skipping reminder for \(client.name) - reminders disabled")
            return
        }
        
        let content = UNMutableNotificationContent()
        let reminderType = getReminderType(for: invoice)
        
        // Customize message based on days overdue
        content.title = reminderType.notificationTitle
        content.body = createReminderMessage(for: invoice, type: reminderType)
        content.sound = .default
        content.categoryIdentifier = "INVOICE_OVERDUE"
        
        // Add invoice data to userInfo
        content.userInfo = [
            "invoiceId": invoice.id.uuidString,
            "invoiceNumber": invoice.invoiceNumber,
            "clientName": client.name,
            "amount": invoice.totalAmount,
            "daysOverdue": invoice.daysOverdue
        ]
        
        // Set badge number
        content.badge = NSNumber(value: await getPendingInvoiceCount())
        
        // Trigger
        let trigger: UNNotificationTrigger
        if immediately {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        } else {
            // Schedule for next 9 AM (today or tomorrow)
            trigger = triggerForNext9AM()
        }
        
        // Create request
        let identifier = "invoice-reminder-\(invoice.id.uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        do {
            try await notificationCenter.add(request)
            print("Scheduled reminder for invoice \(invoice.invoiceNumber)")
        } catch {
            print("Error scheduling reminder: \(error)")
        }
    }
    
    /// Schedule reminder for invoice due soon (before due date)
    func scheduleDueSoonReminder(for invoice: Invoice, daysBefore: Int = 3) async {
        guard let client = invoice.client else { return }
        guard client.allowReminders else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Invoice Due Soon"
        content.body = "Invoice \(invoice.invoiceNumber) for \(client.name) is due in \(daysBefore) days. Amount: \(invoice.totalAmount.formatted(.currency(code: "USD")))"
        content.sound = .default
        content.categoryIdentifier = "INVOICE_DUE_SOON"
        
        content.userInfo = [
            "invoiceId": invoice.id.uuidString,
            "invoiceNumber": invoice.invoiceNumber,
            "clientName": client.name
        ]
        
        // Calculate trigger date (due date minus daysBefore at 9 AM)
        let calendar = Calendar.current
        let triggerDate = calendar.date(
            byAdding: .day,
            value: -daysBefore,
            to: invoice.dueDate
        )
        
        guard let date = triggerDate else { return }
        
        // Set to 9 AM
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "invoice-due-soon-\(invoice.id.uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("Scheduled due-soon reminder for invoice \(invoice.invoiceNumber)")
        } catch {
            print("Error scheduling due-soon reminder: \(error)")
        }
    }
    
    /// Cancel reminder for a specific invoice
    func cancelReminder(for invoice: Invoice) {
        let identifiers = [
            "invoice-reminder-\(invoice.id.uuidString)",
            "invoice-due-soon-\(invoice.id.uuidString)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled reminders for invoice \(invoice.invoiceNumber)")
    }
    
    /// Clear all scheduled invoice reminders
    func clearAllScheduledReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let invoiceIdentifiers = pending
            .filter { $0.identifier.hasPrefix("invoice-") }
            .map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: invoiceIdentifiers)
        print("Cleared \(invoiceIdentifiers.count) scheduled invoice reminders")
    }
    
    // MARK: - Notification Handling
    
    /// Handle notification action
    func handleNotificationAction(_ actionIdentifier: String, for notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        guard let invoiceIdString = userInfo["invoiceId"] as? String,
              let invoiceId = UUID(uuidString: invoiceIdString) else {
            print("Invalid invoice ID in notification")
            return
        }
        
        switch actionIdentifier {
        case "MARK_PAID":
            print("Mark as paid tapped for invoice: \(invoiceId)")
            // This will be handled by the app when it opens
            
        case "SEND_REMINDER":
            print("Send reminder tapped for invoice: \(invoiceId)")
            // Trigger email reminder
            
        case "VIEW_INVOICE":
            print("View invoice tapped: \(invoiceId)")
            // Navigate to invoice detail
            
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determine reminder type based on days overdue
    private func getReminderType(for invoice: Invoice) -> ReminderType {
        let days = invoice.daysOverdue
        
        if days <= 3 {
            return .gentle
        } else if days <= 7 {
            return .standard
        } else if days <= 14 {
            return .firm
        } else {
            return .final
        }
    }
    
    /// Create reminder message based on type and invoice details
    private func createReminderMessage(for invoice: Invoice, type: ReminderType) -> String {
        guard let client = invoice.client else {
            return "Invoice \(invoice.invoiceNumber) is overdue"
        }
        
        let amount = invoice.totalAmount.formatted(.currency(code: "USD"))
        let daysOverdue = invoice.daysOverdue
        
        switch type {
        case .gentle:
            return "Invoice \(invoice.invoiceNumber) for \(client.name) is \(daysOverdue) \(daysOverdue == 1 ? "day" : "days") overdue. Amount: \(amount)"
            
        case .standard:
            return "Payment reminder: Invoice \(invoice.invoiceNumber) for \(client.name) is \(daysOverdue) days overdue. Amount: \(amount)"
            
        case .firm:
            return "Invoice \(invoice.invoiceNumber) for \(client.name) is \(daysOverdue) days overdue. Please follow up. Amount: \(amount)"
            
        case .final:
            return "Final notice: Invoice \(invoice.invoiceNumber) for \(client.name) is \(daysOverdue) days overdue. Immediate attention required. Amount: \(amount)"
        }
    }
    
    /// Get count of pending (unpaid/overdue) invoices for badge.
    /// Returns 0 until ModelContext injection is added in a future build.
    private func getPendingInvoiceCount() async -> Int {
        // FUTURE: Inject ModelContext at service init to query real invoice counts (Build 9+)
        return 0
    }
    
    // MARK: - Email Reminders (Placeholder)
    
    /// Generate email reminder text
    func generateEmailReminder(for invoice: Invoice, type: ReminderType) -> EmailReminder {
        guard let client = invoice.client else {
            return EmailReminder(subject: "", body: "")
        }
        
        let amount = invoice.totalAmount.formatted(.currency(code: "USD"))
        let daysOverdue = invoice.daysOverdue
        
        let subject: String
        let body: String
        
        switch type {
        case .gentle:
            subject = "Friendly Reminder: Invoice \(invoice.invoiceNumber)"
            body = """
            Hi \(client.contactName ?? client.name),
            
            I hope this email finds you well! This is a friendly reminder that invoice \(invoice.invoiceNumber) is now \(daysOverdue) \(daysOverdue == 1 ? "day" : "days") past its due date.
            
            Invoice Details:
             Invoice Number: \(invoice.invoiceNumber)
             Amount Due: \(amount)
             Original Due Date: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
            
            If you've already sent payment, please disregard this reminder. If you have any questions or concerns about this invoice, please don't hesitate to reach out.
            
            Thank you for your business!
            
            Best regards
            """
            
        case .standard:
            subject = "Payment Reminder: Invoice \(invoice.invoiceNumber) - \(amount)"
            body = """
            Dear \(client.contactName ?? client.name),
            
            This is a reminder that invoice \(invoice.invoiceNumber) is currently \(daysOverdue) days past due.
            
            Invoice Details:
             Invoice Number: \(invoice.invoiceNumber)
             Amount Due: \(amount)
             Original Due Date: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
             Days Overdue: \(daysOverdue)
            
            Please arrange payment at your earliest convenience. If payment has already been sent, thank you! If there are any issues with this invoice, please let me know.
            
            Best regards
            """
            
        case .firm:
            subject = "Overdue Notice: Invoice \(invoice.invoiceNumber) - Action Required"
            body = """
            Dear \(client.contactName ?? client.name),
            
            This is an important notice regarding invoice \(invoice.invoiceNumber), which is now \(daysOverdue) days overdue.
            
            Invoice Details:
             Invoice Number: \(invoice.invoiceNumber)
             Amount Due: \(amount)
             Original Due Date: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
             Days Overdue: \(daysOverdue)
            
            Please arrange immediate payment. If there are any issues preventing timely payment, please contact me as soon as possible so we can discuss a resolution.
            
            Thank you for your prompt attention to this matter.
            
            Best regards
            """
            
        case .final:
            subject = "FINAL NOTICE: Invoice \(invoice.invoiceNumber) - Immediate Action Required"
            body = """
            Dear \(client.contactName ?? client.name),
            
            This is a final notice regarding invoice \(invoice.invoiceNumber), which is now significantly overdue (\(daysOverdue) days).
            
            Invoice Details:
             Invoice Number: \(invoice.invoiceNumber)
             Amount Due: \(amount)
             Original Due Date: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
             Days Overdue: \(daysOverdue)
            
            Immediate payment is required. If I do not receive payment or hear from you within the next 3 business days, I will need to consider additional collection measures.
            
            If you are experiencing financial difficulties or have concerns about this invoice, please contact me immediately to discuss payment arrangements.
            
            Best regards
            """
        }
        
        return EmailReminder(subject: subject, body: body)
    }
}

// MARK: - Daily Check

extension InvoiceReminderService {
    /// Perform daily check for invoices needing reminders
    /// This should be called by the app delegate or a background task
    /// Updated for InvoiceService v4.0 - uses legacy non-throwing method
    func performDailyReminderCheck(context: ModelContext) async {
        print("Performing daily invoice reminder check...")
        
        // Use legacy method for backward compatibility with InvoiceService v4.0
        let invoicesNeedingReminders = InvoiceService.shared.getInvoicesNeedingRemindersLegacy(
            context: context
        )
        
        for invoice in invoicesNeedingReminders {
            await scheduleReminder(for: invoice, immediately: true)
            
            // Record that reminder was sent
            invoice.recordReminderSent()
        }
        
        try? context.save()
        
        print("Daily reminder check complete: \(invoicesNeedingReminders.count) reminders sent")
    }
}
