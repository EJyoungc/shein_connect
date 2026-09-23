# Implemented Functionality Overview

## Core Application Flow
- **Splash Screen** that transitions to authentication flow.
- **Registration** screen with validation for:
  - Full name
  - Email (format check)
  - Malawian mobile number (10‑digit validation)
  - Gender selection
  - Password (strength rules)
- **Login** screen supporting:
  - Email + password
  - Mobile number (Malawian format) + password
- **Supabase Auth** integration for email/password and phone sign‑in, storing user metadata in `public.profiles`.

## Cart Management
- `CartService` maintains a list of `CartItem` models.
- **Local persistence** using `SharedPreferences` for offline use.
- **Supabase sync** of cart items to `public.cart_items` when the user is authenticated.
- UI screen (`CartScreen`) shows items, totals, and a **Place Order** button.

## In‑App Browser & Product Capture
- Integrated `flutter_inappwebview` to embed the Shein store.
- Implemented JavaScript bridge to capture clicked product links.
- Extracted product details (name, price, variations/colors, description, image URL) and added them to the local cart.

## Procurement Sessions
- `SessionService` loads procurement sessions from Supabase (`procurement_sessions`).
- Provides the **active session** (first `OPEN` or a demo fallback).
- Handles loading state (`isLoading`).

## Branding & Identity
- **Application Name**: Officially rebranded to **SheIn Connect** (Malawi).
- Consistent branding integrated across:
  - Splash screen (branded badge, title, and tagline).
  - Authentication headers (Login, Registration).
  - Profile screen title.
  - Native platform metadata: Android application label (`AndroidManifest.xml`), Web app title & tags (`index.html`), Windows desktop window title (`main.cpp`), and Windows PE executable resources (`Runner.rc`).

## Order Management & Proof of Payment
- `submitOrder` validates cart non‑emptiness and session `OPEN` status.
- Inserts a row into `session_orders` and snapshots cart items into `order_items`.
- Returns a tuple `{success, message, orderId}` for UI feedback.
- Offline fallback creates a mock order locally when Supabase is unavailable.
- `loadUserOrders` fetches the authenticated user's orders with nested `order_items`.
- **Proof of Payment Upload & Replacement**:
  - Direct receipt image selection via `image_picker`.
  - Preview dialog displaying existing receipt or freshly selected image before upload.
  - Supabase Storage upload to `payment_proofs` bucket with automatic order status update to `VERIFYING`.
  - "Change Proof" functionality allowing users to update their receipt if rejected or re-uploaded.
  - Supabase Row-Level Security (RLS) policies (`20260929_allow_user_payment_proof_update.sql`) allowing users to update `proof_of_payment_url` and overwrite their existing receipts.
- **Order Deletion**:
  - Ability for users to cancel/delete their unverified orders.

## Payment Accounts & Details Management
- **Supabase Table**: `public.payment_details` storing:
  - `type` (`bank`, `airtel_money`, `mpamba`)
  - `account_name` (Name of owner of the account)
  - `account_number` (Account number or mobile number)
  - `bank_name` (e.g. National Bank of Malawi, Standard Bank, FDH Bank)
  - `branch_name` (Optional branch info)
  - `instructions` (Payment reference notes)
  - `is_active` (Active visibility flag)
- **Security & RLS**:
  - Customers can read active accounts.
  - Only administrators can create, update, or remove accounts.
- **Customer View & 1-Tap Copying**:
  - `PaymentDetailsModal`: Bottom sheet modal with badges for Bank, Airtel Money, and Mpamba.
  - 1-tap copy of account name and account number with clipboard confirmation feedback.
  - Accessible from the Customer Dashboard quick actions, Profile screen, and directly from the Proof of Payment upload sheet.
- **Admin Control Hub - Payment Accounts Tab**:
  - Dedicated tab displaying all configured accounts with status badges (`ACTIVE` / `INACTIVE`).
  - Add account modal supporting bank selector, mobile money options, branch, instructions, and visibility switch.
  - Full edit and delete confirmation dialogs.

## About SheIn Connect & Developer Credits
- **Screen**: `AboutScreen` (`lib/screens/profile/about_screen.dart`)
- **Developer Attribution**: Built with pride by **Techlink360**.
- **Interactive Social & Direct Contact Links**:
  - Facebook: Direct link to `https://www.facebook.com/tlink360` (opens via `url_launcher`).
  - WhatsApp: Direct chat link to `0995936887` (`https://wa.me/265995936887`).
- **Profile Navigation**: Integrated directly into `ProfileScreen`.

## Admin / Role Handling

## State Management & Architecture
- Riverpod (`flutter_riverpod`) provides providers for auth, cart, and session services.
- Clean folder structure:
  - `core/` – constants, errors, utils.
  - `features/` – auth, browser, cart, sessions, orders.
  - `shared/` – widgets, models, services.
  - `routing/` – navigation configuration.

## Platform Support & Build
- Project builds and runs on **Windows desktop** (Flutter Desktop). 
- Resolved LNK1168 build issue by terminating lingering `shein_pro.exe` and cleaning the build.
- Successful Supabase client initialization logged during runtime.
- Fixed infinite-width layout constraints across buttons (`ElevatedButton`, `OutlinedButton`) in `AppTheme`.

## CI/CD Pipeline & Automated Release (GitHub Actions)
- Automated workflow located at `.github/workflows/build_release.yml`:
  - **Android Matrix**: Compiles release APK (`SheIn-Connect-Android.apk`) and Play Store App Bundle (`SheIn-Connect-Android.aab`).
  - **Linux Matrix**: Sets up GTK3 & CMake development libraries on Ubuntu, builds desktop executable, and bundles into `shein-connect-linux-x64.tar.gz`.
  - **iOS Matrix**: Executes on `macos-14`, builds release Flutter iOS bundle, and generates installable `shein-connect-ios-unsigned.ipa`.
  - **Automated GitHub Releases**: When tags prefixed with `v*` (e.g. `v1.0.0`) are pushed or triggered manually via `workflow_dispatch`, all platform binaries are automatically collected and attached to a new GitHub Release.

## Miscellaneous & Testing
- Added comprehensive error logging via `AppLogger`.
- Suppressed analyzer warnings (`use_build_context_synchronously`).
- Replaced invalid icons and ensured all UI assets compile.
- Updated `pubspec.yaml` dependencies; lint warnings cleared.
- Added comprehensive Supabase integration test (`test/test_supabase_user_orders.dart`) testing order submission, proof of payment upload, replacement, and deletion.

---
All of the above functionality is currently operational in the repository located at `C:\laragon\www\shein_pro`.
