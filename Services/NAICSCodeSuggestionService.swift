//  NAICSCodeSuggestionService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Auto-suggest NAICS codes from spending category patterns
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Maps transaction category spending patterns to likely NAICS codes.
//  Uses a heuristic approach based on dominant expense categories.
//

import Foundation

// MARK: - Result Types

struct NAICSSuggestion: Identifiable {
    let id = UUID()
    let code: String
    let title: String
    let description: String
    let confidence: Double // 0.0–1.0
    let matchedCategories: [String]
}

// MARK: - Service

final class NAICSCodeSuggestionService {
    static let shared = NAICSCodeSuggestionService()

    private init() {}

    // MARK: - Public API

    /// Suggests NAICS codes based on transaction spending patterns.
    func suggestCodes(
        transactions: [Transaction],
        businessType: BusinessType
    ) -> [NAICSSuggestion] {
        // Get category distribution
        let categorySpending = buildCategoryDistribution(transactions: transactions)
        guard !categorySpending.isEmpty else { return [] }

        // Get candidates based on business type + categories
        var suggestions = matchToNAICS(
            categorySpending: categorySpending,
            businessType: businessType
        )

        // Sort by confidence descending
        suggestions.sort { $0.confidence > $1.confidence }

        // Return top 5
        return Array(suggestions.prefix(5))
    }

    /// Returns a curated list of common NAICS codes for manual selection.
    func commonCodes(for businessType: BusinessType) -> [NAICSSuggestion] {
        let codes: [(String, String, String)]

        switch businessType {
        case .farm:
            codes = [
                ("111100", "Oilseed and Grain Farming", "Corn, soybeans, wheat, rice"),
                ("111300", "Fruit and Tree Nut Farming", "Orchards, vineyards, berries"),
                ("111400", "Greenhouse and Nursery", "Floriculture, mushrooms, nursery stock"),
                ("111900", "Other Crop Farming", "Tobacco, hay, sugar, specialty"),
                ("112100", "Cattle Ranching", "Beef cattle, feedlots"),
                ("112300", "Poultry and Egg", "Chickens, turkeys, eggs"),
                ("112900", "Other Animal Production", "Horses, bees, aquaculture, mixed"),
                ("115100", "Crop Support Services", "Spraying, harvesting, planting"),
            ]
        case .rentalProperty:
            codes = [
                ("531110", "Lessors of Residential", "Apartment buildings, houses, condos"),
                ("531120", "Lessors of Nonresidential", "Commercial, industrial, warehouse"),
                ("531190", "Lessors of Other Real Estate", "Mini storage, vacant lots"),
                ("531210", "Offices of Real Estate Agents", "Brokerage, property management"),
                ("531311", "Residential Property Managers", "Residential property management"),
                ("531312", "Nonresidential Property Managers", "Commercial property management"),
            ]
        default:
            codes = [
                ("236100", "Residential Construction", "Home building, remodeling"),
                ("238000", "Specialty Trade Contractors", "Plumbing, HVAC, electrical"),
                ("484000", "Truck Transportation", "Freight, moving, delivery"),
                ("511000", "Publishing Industries", "Books, software, apps, content"),
                ("518000", "Computing Infrastructure", "Web hosting, SaaS, data processing"),
                ("541100", "Legal Services", "Attorneys, legal aid, mediation"),
                ("541200", "Accounting Services", "CPA firms, tax prep, bookkeeping"),
                ("541300", "Architectural/Engineering", "Architecture, surveying, design"),
                ("541400", "Specialized Design", "Graphic, interior, industrial design"),
                ("541500", "Computer Systems Design", "Software dev, IT consulting, custom programming"),
                ("541600", "Management Consulting", "Strategy, operations, HR consulting"),
                ("541800", "Advertising/PR", "Advertising agencies, media buying, public relations"),
                ("541900", "Other Professional Services", "Photography, translation, consulting"),
                ("561000", "Administrative Services", "Office admin, facilities support"),
                ("611000", "Educational Services", "Tutoring, training, driving schools"),
                ("621000", "Health Care — Ambulatory", "Physicians, dentists, therapists"),
                ("711100", "Performing Arts", "Theater, dance, music"),
                ("711500", "Independent Artists/Writers", "Freelance writers, artists, performers"),
                ("722500", "Restaurants", "Full-service, limited-service, catering"),
                ("812100", "Personal Care Services", "Hair salons, spas, beauty"),
                ("812900", "Other Personal Services", "Pet care, tailoring, miscellaneous"),
            ]
        }

        return codes.map { code, title, desc in
            NAICSSuggestion(
                code: code,
                title: title,
                description: desc,
                confidence: 0,
                matchedCategories: []
            )
        }
    }

    // MARK: - Category Distribution

    private func buildCategoryDistribution(transactions: [Transaction]) -> [String: Double] {
        var spending: [String: Double] = [:]

        for txn in transactions where !txn.isIncome && !txn.isTransfer && txn.financeType == .business {
            let categoryName = txn.category?.name ?? "Uncategorized"
            spending[categoryName, default: 0] += txn.amount
        }

        return spending
    }

    // MARK: - NAICS Matching

    private func matchToNAICS(
        categorySpending: [String: Double],
        businessType: BusinessType
    ) -> [NAICSSuggestion] {
        let totalSpending = categorySpending.values.reduce(0, +)
        guard totalSpending > 0 else { return [] }

        var suggestions: [NAICSSuggestion] = []
        let lowerCategories = categorySpending.mapKeys { $0.lowercased() }

        // Check each NAICS pattern
        for pattern in naicsPatterns {
            let matchedCats = pattern.keywords.compactMap { keyword -> (String, Double)? in
                for (cat, amount) in lowerCategories {
                    if cat.contains(keyword.lowercased()) {
                        return (cat, amount)
                    }
                }
                return nil
            }

            if !matchedCats.isEmpty {
                let matchedAmount = matchedCats.reduce(0) { $0 + $1.1 }
                let categoryMatch = Double(matchedCats.count) / Double(pattern.keywords.count)
                let spendingMatch = matchedAmount / totalSpending

                // Boost confidence if business type matches
                let typeBoost: Double = pattern.businessTypes.contains(businessType) ? 0.2 : 0

                let confidence = min(1.0, (categoryMatch * 0.5 + spendingMatch * 0.3 + typeBoost))

                if confidence > 0.15 {
                    suggestions.append(NAICSSuggestion(
                        code: pattern.code,
                        title: pattern.title,
                        description: pattern.description,
                        confidence: confidence,
                        matchedCategories: matchedCats.map { $0.0 }
                    ))
                }
            }
        }

        return suggestions
    }

    // MARK: - Pattern Data

    private struct NAICSPattern {
        let code: String
        let title: String
        let description: String
        let keywords: [String]
        let businessTypes: [BusinessType]
    }

    private let naicsPatterns: [NAICSPattern] = [
        NAICSPattern(code: "112900", title: "Other Animal Production",
                     description: "Horses, bees, aquaculture, mixed livestock",
                     keywords: ["feed", "veterinary", "vet", "livestock", "animal", "hay", "pasture", "fencing"],
                     businessTypes: [.farm]),
        NAICSPattern(code: "111900", title: "Other Crop Farming",
                     description: "Hay, tobacco, sugar, specialty crops",
                     keywords: ["seed", "fertilizer", "chemical", "crop", "harvest", "irrigation"],
                     businessTypes: [.farm]),
        NAICSPattern(code: "541500", title: "Computer Systems Design",
                     description: "Software development, IT consulting",
                     keywords: ["software", "hosting", "domain", "cloud", "server", "saas", "api", "developer"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "541900", title: "Other Professional Services",
                     description: "Photography, consulting, translation",
                     keywords: ["consulting", "professional", "photography", "translation"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "541400", title: "Specialized Design Services",
                     description: "Graphic, interior, industrial design",
                     keywords: ["design", "graphic", "creative", "branding", "logo"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "236100", title: "Residential Building Construction",
                     description: "Home building, remodeling",
                     keywords: ["lumber", "concrete", "construction", "building", "material", "hardware", "plumbing"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "484000", title: "Truck Transportation",
                     description: "Freight, moving, delivery services",
                     keywords: ["fuel", "diesel", "truck", "freight", "delivery", "dispatch", "mileage"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "722500", title: "Restaurants and Eating Places",
                     description: "Full-service, limited-service, catering",
                     keywords: ["food", "restaurant", "kitchen", "catering", "menu", "ingredient"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "531110", title: "Lessors of Residential Buildings",
                     description: "Apartment, house, condo rentals",
                     keywords: ["rent", "tenant", "maintenance", "repair", "property", "mortgage", "insurance"],
                     businessTypes: [.rentalProperty]),
        NAICSPattern(code: "812100", title: "Personal Care Services",
                     description: "Hair salons, spas, beauty services",
                     keywords: ["salon", "beauty", "spa", "hair", "nail", "cosmetic"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "621000", title: "Ambulatory Health Care",
                     description: "Physicians, dentists, therapists",
                     keywords: ["medical", "health", "therapy", "clinic", "patient", "dental"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),

        // Retail Trade
        NAICSPattern(code: "445100", title: "Grocery Stores",
                     description: "Retailing a general line of food products",
                     keywords: ["grocery", "supermarket", "food store", "produce"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "448100", title: "Clothing Stores",
                     description: "Retailing new clothing and clothing accessories",
                     keywords: ["clothing", "apparel", "fashion", "boutique", "garment"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "454110", title: "E-Commerce & Mail Order",
                     description: "Electronic shopping and mail-order houses",
                     keywords: ["shopify", "etsy", "ebay", "ecommerce", "online store", "amazon seller"],
                     businessTypes: [.soleProprietorship, .llc]),

        // Professional Services
        NAICSPattern(code: "541100", title: "Legal Services",
                     description: "Offices of lawyers and legal services",
                     keywords: ["legal", "attorney", "law firm", "paralegal", "mediation", "notary"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "541200", title: "Accounting & Tax Preparation",
                     description: "Accounting, tax preparation, and payroll services",
                     keywords: ["accounting", "bookkeeping", "cpa", "tax prep", "audit", "payroll"],
                     businessTypes: [.soleProprietorship, .llc, .partnership]),
        NAICSPattern(code: "541800", title: "Advertising & Marketing",
                     description: "Advertising, public relations, and related services",
                     keywords: ["marketing", "advertising", "social media", "seo", "campaign", "branding", "pr"],
                     businessTypes: [.soleProprietorship, .llc]),

        // Auto & Repair
        NAICSPattern(code: "811100", title: "Automotive Repair & Maintenance",
                     description: "Automotive mechanical and electrical repair and maintenance",
                     keywords: ["auto repair", "mechanic", "oil change", "tire", "brake", "body shop", "transmission"],
                     businessTypes: [.soleProprietorship, .llc]),

        // Services
        NAICSPattern(code: "561730", title: "Landscaping Services",
                     description: "Landscape care and maintenance services",
                     keywords: ["landscaping", "lawn", "mowing", "tree service", "hardscape", "garden", "irrigation"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "561720", title: "Janitorial & Cleaning Services",
                     description: "Janitorial and building cleaning services",
                     keywords: ["cleaning", "janitorial", "maid", "pressure wash", "carpet clean", "housekeeping"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "541920", title: "Photography Services",
                     description: "Photographic services including portrait and commercial",
                     keywords: ["photography", "photo", "portrait", "headshot", "wedding photo", "videography"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "713940", title: "Fitness & Wellness",
                     description: "Fitness and recreational sports centers",
                     keywords: ["fitness", "gym", "trainer", "yoga", "pilates", "crossfit", "wellness"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "722330", title: "Mobile Food Services",
                     description: "Mobile food services including food trucks",
                     keywords: ["food truck", "mobile food", "concession", "catering trailer", "street food"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "624410", title: "Child Day Care Services",
                     description: "Child day care services and preschools",
                     keywords: ["childcare", "daycare", "babysitting", "preschool", "after school", "nanny"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "812910", title: "Pet Care Services",
                     description: "Pet care except veterinary services",
                     keywords: ["pet", "grooming", "dog walk", "boarding", "kennel", "pet sitting"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "611691", title: "Exam Preparation & Tutoring",
                     description: "Exam preparation and tutoring services",
                     keywords: ["tutor", "tutoring", "test prep", "academic", "homework", "education"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "561920", title: "Convention & Event Planning",
                     description: "Convention and trade show organizers",
                     keywords: ["event", "wedding planner", "party", "conference", "event planning", "coordinator"],
                     businessTypes: [.soleProprietorship, .llc]),

        // Manufacturing & Wholesale
        NAICSPattern(code: "311000", title: "Food Manufacturing",
                     description: "Food manufacturing and processing",
                     keywords: ["manufacturing", "processing", "packaging", "canning", "bottling", "bakery production"],
                     businessTypes: [.llc, .partnership]),
        NAICSPattern(code: "423000", title: "Durable Goods Wholesale",
                     description: "Merchant wholesalers of durable goods",
                     keywords: ["wholesale", "distributor", "supplier", "bulk", "warehouse"],
                     businessTypes: [.llc, .partnership]),

        // Other
        NAICSPattern(code: "721100", title: "Hotels & Motels",
                     description: "Traveler accommodation including hotels and motels",
                     keywords: ["hotel", "motel", "inn", "lodge", "bed and breakfast", "airbnb host"],
                     businessTypes: [.llc, .partnership]),
        NAICSPattern(code: "562000", title: "Waste Management",
                     description: "Waste collection, treatment, and disposal",
                     keywords: ["waste", "recycling", "disposal", "hauling", "dumpster", "junk removal"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "531210", title: "Real Estate Agents",
                     description: "Offices of real estate agents and brokers",
                     keywords: ["real estate", "realtor", "broker", "listing", "commission", "mls"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "512100", title: "Motion Picture & Video",
                     description: "Motion picture and video industries",
                     keywords: ["film", "video", "production", "editing", "streaming", "content creation"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "519100", title: "News & Media",
                     description: "News syndicates and internet publishing",
                     keywords: ["news", "media", "publishing", "blog", "podcast", "newsletter", "journalism"],
                     businessTypes: [.soleProprietorship, .llc]),
        NAICSPattern(code: "713900", title: "Amusement & Recreation",
                     description: "Other amusement and recreation industries",
                     keywords: ["recreation", "amusement", "arcade", "bowling", "mini golf", "trampoline"],
                     businessTypes: [.soleProprietorship, .llc]),
    ]
}

// MARK: - Dictionary Helper

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
