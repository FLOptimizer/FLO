# FLO — Future Features & Enhancements

## IAP / Premium Features

### Multiple Business Profiles
- **Priority:** High
- **Monetization:** In-App Purchase or Pro tier feature
- **Description:** Allow users to create and manage multiple business profiles (e.g., freelancer who has a consulting LLC and a separate e-commerce business). Each profile has its own branding, logo, address, tax ID for invoice generation.
- **Scope:**
  - Profile switcher in Settings → Business section
  - Each invoice links to a specific business profile
  - Reports filterable by business profile
  - Free tier: 1 business profile
  - Pro tier: Unlimited business profiles
- **Dependencies:** BusinessProfile model needs a `profiles` array, invoice creation needs profile picker

## Authentication & Identity

### Google Sign-In (Phase 2)
- **Priority:** Medium
- **Description:** Add Google Sign-In as secondary auth option alongside Sign In with Apple. Useful for cross-platform reach if FLO ever supports Android.
- **Dependencies:** GoogleSignIn SDK, OAuth flow, server-side token validation (optional)

### Server-to-Server Notifications
- **Priority:** Low (until backend exists)
- **Description:** Apple Sign In server-to-server notifications for credential revocation, email forwarding changes, account deletion. Requires a backend endpoint.

## Notes
- Updated: March 2026, Build 10
