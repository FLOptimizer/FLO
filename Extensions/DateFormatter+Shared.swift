//  DateFormatter+Shared.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Phase 1 Performance Optimization.
//  Static lazy DateFormatter instances eliminate repeated allocations.
//  DateFormatter() is expensive (~2ms per allocation on iOS).
//  Reuse these shared instances instead of creating new ones.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation

extension DateFormatter {

    // MARK: - Month + Year Formats

    /// "March 2026" — Budget headers, receipt storage, report titles
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// "Mar 2026" — Compact month/year labels, credit card summaries
    static let shortMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    /// "2026-03" — Budget keys, notification scheduling, data grouping
    static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    // MARK: - Month-Only Formats

    /// "March" — Budget list period labels
    static let fullMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    /// "Mar" — Chart axis labels, trend data
    static let shortMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // MARK: - Day Formats

    /// "Mar 15" — Date range text, week displays
    static let shortMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    // MARK: - Year-Only

    /// "2026" — Year selector, annual reports
    static let yearOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    // MARK: - ISO Formats

    /// "2026-03-15" — CSV export, mileage trips, receipt export
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// "14:30" — Trip time display
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "2026-03-15 14:30:00" — Full timestamp for export/logging
    static let isoDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - System Style Formats

    /// "Mar 15, 2026" — Medium date style for general display
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// "March 15, 2026" — Long date style for formal display
    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// "3/15/26" — Short date style
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
}
