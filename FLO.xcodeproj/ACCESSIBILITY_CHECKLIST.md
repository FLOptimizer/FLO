# ✅ FLO Accessibility Quick Reference Checklist

**Use this checklist when developing new features or reviewing PRs**

---

## 📱 VIEW-LEVEL CHECKLIST

When creating or modifying a view, ensure:

### Screen Announcements
- [ ] Add `.onAppear` with `AccessibilityAnnouncement.screenChanged("View Name")`
- [ ] Include key context (e.g., "Dashboard. 5 transactions.")
- [ ] Test announcement with VoiceOver enabled

### Navigation Elements
- [ ] All tabs have `.accessibilityLabel()` and `.accessibilityHint()`
- [ ] Navigation titles are descriptive
- [ ] Back buttons read clearly (auto-handled by NavigationStack)

### Loading States
- [ ] Skeleton views use `.accessibilityElement(children: .ignore)`
- [ ] Add `.accessibilityLabel("Loading [content]")`
- [ ] Add `.accessibilityAddTraits(.updatesFrequently)`

### Empty States
- [ ] Custom illustrations either have descriptive labels or are hidden
- [ ] Empty message is accessible
- [ ] Call-to-action buttons have labels and hints

---

## 💰 FINANCIAL DATA CHECKLIST

When displaying money values:

### Currency Display
- [ ] Use `.accessibleCurrency(amount, label: "Description")`
- [ ] For balance: `"Balance: twelve dollars and thirty four cents"`
- [ ] For prices: `"Price: nine dollars and ninety nine cents"`
- [ ] Test with VoiceOver to verify natural speech

### Progress Indicators
- [ ] Add `.accessibilityLabel()` describing what's being measured
- [ ] Add `.accessibilityValue()` with percentage and amounts
- [ ] Example: `"Budget progress, 75% used, $375 of $500"`

### Charts & Graphs
- [ ] Add `.accessibilityLabel()` with chart title
- [ ] Add `.accessibilityChartDescriptor()` for data access
- [ ] Provide text summary in `.accessibilityValue()`
- [ ] Consider audio graph for complex visualizations

---

## 🎛️ INTERACTIVE ELEMENTS CHECKLIST

### Buttons
- [ ] Use `.accessibleButton(label:hint:)` modifier
- [ ] Label describes action: "Add transaction", "Delete trip"
- [ ] Hint provides context: "Opens form to create new transaction"
- [ ] Icon-only buttons MUST have labels

### Toggles
- [ ] Use `.accessibilityToggle(label:isOn:hint:)`
- [ ] Or add custom label with state
- [ ] Example: `"Trip notifications, enabled"`
- [ ] Announce state changes

### Pickers
- [ ] Add `.accessibilityLabel()` with current selection
- [ ] Example: `"Category: Groceries"`
- [ ] Add `.accessibilityHint()` describing purpose
- [ ] Announce selection changes

### Text Fields
- [ ] Use `.accessibleField(label:hint:)`
- [ ] Label describes purpose: "Transaction amount"
- [ ] Hint provides guidance: "Enter amount in dollars"
- [ ] Validation errors announced immediately

### Swipe Actions
- [ ] Each action has `.accessibilityLabel()`
- [ ] Each action has `.accessibilityHint()`
- [ ] Example: `"Delete transaction. Permanently removes from records."`
- [ ] Consider adding rotor actions as alternative

---

## 🎨 VISUAL ELEMENTS CHECKLIST

### Images
- [ ] Decorative images: `.accessibilityHidden(true)`
- [ ] Informative images: `.accessibilityLabel("Description")`
- [ ] SF Symbols in buttons: Hidden (button label is enough)
- [ ] Custom illustrations: Descriptive label or hidden

### Colors
- [ ] Use `Color.brandPrimary` not hex codes
- [ ] Verify 4.5:1 contrast ratio for text
- [ ] Test in Light and Dark mode
- [ ] Test with Increased Contrast enabled

### Touch Targets
- [ ] All interactive elements minimum 44x44pt
- [ ] Use `.minimumTouchTarget()` modifier
- [ ] Or `.frame(minWidth: 44, minHeight: 44)`
- [ ] Test with large pointer size enabled

---

## 📝 FORM CHECKLIST

### Field Labels
- [ ] All fields have clear labels
- [ ] Labels describe purpose, not format
- [ ] Good: "Email address", Bad: "Enter your email"

### Validation
- [ ] Errors announced immediately with `AccessibilityAnnouncement.announce()`
- [ ] Error messages are descriptive and actionable
- [ ] Good: "Amount must be greater than zero"
- [ ] Bad: "Invalid input"

### Submit/Cancel
- [ ] Save button labeled with action: "Save transaction"
- [ ] Cancel button hints at outcome: "Discards changes and returns to list"
- [ ] Disable state announced: "Save, button, dimmed"

---

## 📊 CARD/LIST CHECKLIST

### Card Components
- [ ] Use `.accessibleCard(label:hint:value:)` for read-only cards
- [ ] Use `.accessibleTappableCard()` for interactive cards
- [ ] Combine child elements: `.accessibilityElement(children: .ignore)`
- [ ] Create single spoken label with all info

### List Rows
- [ ] Combine row elements into single accessibility element
- [ ] Example: `"Groceries, expense, twelve dollars, yesterday"`
- [ ] Add `.accessibilityHint("Double tap to view details")`
- [ ] Section headers: `.accessibilityAddTraits(.isHeader)`

### Badges & Indicators
- [ ] Status badges: `.accessibilityLabel("Status: Paid")`
- [ ] Count badges: `.accessibilityLabel("5 unread")`
- [ ] Hide decorative indicators

---

## 🔊 ANNOUNCEMENT CHECKLIST

### When to Announce
- [ ] Screen appears (always)
- [ ] User action completes (save, delete, create)
- [ ] Filter/sort changes (include count)
- [ ] Error occurs (with context)
- [ ] State changes (GPS, battery, network)

### How to Announce
```swift
// Screen change
AccessibilityAnnouncement.screenChanged("View Name")

// General announcement
AccessibilityAnnouncement.announce("Action completed")

// With delay (if needed)
AccessibilityAnnouncement.announce("Message", delay: 0.2)
```

### What NOT to Announce
- [ ] ❌ Every minor update (overwhelming)
- [ ] ❌ Background data sync
- [ ] ❌ Trivial state changes
- [ ] ❌ Decorative animations

### Smart Filtering
- [ ] Only announce significant changes
- [ ] Group related changes
- [ ] Use delay to avoid conflicts
- [ ] Consider user context

---

## 🧪 TESTING CHECKLIST

### Before Committing
- [ ] Run Accessibility Inspector audit (0 errors)
- [ ] Test with VoiceOver on at least one flow
- [ ] Verify labels are descriptive
- [ ] Check that hints are helpful

### Before PR Review
- [ ] All new interactive elements have labels
- [ ] All new financial values use currency formatter
- [ ] All new forms have validation announcements
- [ ] Documentation updated if needed

### Before Release
- [ ] Full VoiceOver testing on primary flows
- [ ] Test at maximum Dynamic Type size (AX5)
- [ ] Test in Increased Contrast mode
- [ ] Test with Reduce Motion enabled
- [ ] Verify all charts/graphs are accessible

---

## 🛠️ COMMON PATTERNS

### Pattern: Read-Only Card
```swift
VStack {
    Text("Title")
    Text("$1,234.56")
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Title: one thousand two hundred thirty four dollars")
```

### Pattern: Interactive Card
```swift
Button {
    action()
} label: {
    VStack {
        Text("Title")
        Text("Detail")
    }
}
.accessibleTappableCard(
    label: "Title, Detail",
    hint: "Double tap to view details"
)
```

### Pattern: Currency Display
```swift
Text("$\(amount, specifier: "%.2f")")
    .font(.title)
    .accessibleCurrency(amount, label: "Balance")
```

### Pattern: Progress Indicator
```swift
ProgressView(value: current, total: limit)
    .accessibilityLabel("Budget progress")
    .accessibilityValue("\(Int(percentage))% used, \(spoken(current)) of \(spoken(limit))")
```

### Pattern: Form Field
```swift
TextField("Amount", text: $amountText)
    .accessibleField(
        label: "Transaction amount",
        hint: "Enter amount in dollars"
    )
```

### Pattern: Validation Error
```swift
.onChange(of: showingError) { _, showing in
    if showing {
        AccessibilityAnnouncement.announce("Error: \(errorMessage)")
        HapticService.play(.error)
    }
}
```

---

## 📚 QUICK REFERENCE

### Available Modifiers
```swift
// Cards
.accessibleCard(label:hint:value:)
.accessibleTappableCard(label:hint:value:)

// Buttons
.accessibleButton(label:hint:)
.accessibleIconButton(label:hint:)
.minimumTouchTarget()

// Financial
.accessibleCurrency(_:label:)
.accessiblePercentage(_:label:)

// Forms
.accessibleField(label:hint:)
.accessibleToggle(label:isOn:hint:)

// Structure
.accessibleHeader(_:)
.accessibleSectionHeader(_:)
.accessibleListRow(label:hint:)
```

### Available Formatters
```swift
AccessibilityFormatters.spokenCurrency(1234.56)
// → "one thousand two hundred thirty four dollars and fifty six cents"

AccessibilityFormatters.spokenPercentage(0.175)
// → "seventeen point five percent"

AccessibilityFormatters.spokenDate(Date())
// → "February eighteenth, twenty twenty six"

AccessibilityFormatters.spokenRelativeDate(Date())
// → "today"
```

### Announcement Helpers
```swift
AccessibilityAnnouncement.screenChanged("View Name")
AccessibilityAnnouncement.announce("Message")
AccessibilityAnnouncement.layoutChanged(element)
```

---

## 🚫 COMMON MISTAKES

### ❌ DON'T
```swift
// No label
Button { action() } label: {
    Image(systemName: "plus")
}

// Generic label
Text("$1234.56")
    .accessibilityLabel("Amount")

// Separate elements
HStack {
    Text("Name")
    Text("$50")
}
// VoiceOver reads: "Name. Fifty dollars." (disjointed)

// No validation announcement
.alert("Error", isPresented: $showingError) { ... }
// User gets surprise alert
```

### ✅ DO
```swift
// Clear label
Button { action() } label: {
    Image(systemName: "plus")
}
.accessibilityLabel("Add transaction")
.accessibilityHint("Opens form to create new transaction")

// Natural speech
Text("$1234.56")
    .accessibleCurrency(1234.56, label: "Transaction amount")

// Combined element
HStack {
    Text("Name")
    Text("$50")
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Name, fifty dollars")

// Announce validation
.alert("Error", isPresented: $showingError) { ... }
.onChange(of: showingError) { _, showing in
    if showing {
        AccessibilityAnnouncement.announce("Error: \(message)")
    }
}
```

---

## 📞 HELP & RESOURCES

### Internal Resources
- `AccessibilityHelpers.swift` - Available modifiers
- `ACCESSIBILITY_AUDIT_FULL_PROJECT.md` - Complete audit
- `ACCESSIBILITY_FIXES_SPRINT_1.md` - Implementation guide

### External Resources
- [Apple Accessibility](https://developer.apple.com/accessibility/)
- [WCAG Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [VoiceOver Gesture Guide](https://support.apple.com/guide/iphone/learn-voiceover-gestures-iph3e2e2281/ios)

### Questions?
Contact the Accessibility Champion or email: flo.financeapp@gmail.com

---

## ✅ PR REVIEW CHECKLIST

**Before approving a PR, verify:**

- [ ] All new views have screen change announcement
- [ ] All new buttons have labels and hints
- [ ] All currency values use `.accessibleCurrency()`
- [ ] All progress indicators have values
- [ ] All forms have validation announcements
- [ ] No new accessibility warnings in Xcode
- [ ] Accessibility Inspector shows 0 errors
- [ ] Manual VoiceOver testing on new/changed screens

---

**Keep this checklist handy and reference it during development!**

Last Updated: February 18, 2026  
Version: 1.0  
Maintained by: Accessibility Champion
