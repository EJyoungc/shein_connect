# Changelog

## 2026-09-23
- **Layout & Constraint Fixes**:
  - Fixed infinite-width assertion crash in `AppTheme` by adjusting `minimumSize` on `ElevatedButton` and `OutlinedButton` to `Size(0, 48)` and adding safe constraints.
  - Resolved button flex constraints in `MyOrdersScreen`.
- **Application Rebranding to "SheIn Connect"**:
  - Updated branding across all application touchpoints: Splash Screen, Login Screen, Register Screen, Profile Screen, Android Manifest label, Web `index.html` title & meta tags, Windows Desktop window title (`main.cpp`), and Windows executable resource metadata (`Runner.rc`).
- **Proof of Payment & Order Management**:
  - Implemented proof of payment upload and re-upload/replacement flow for users on their order cards.
  - Added "Change Proof" button, status indicators, and modal preview before submission.
  - Added Supabase RLS migration policy (`20260929_allow_user_payment_proof_update.sql`) enabling users to update `proof_of_payment_url` and replace receipts in the `payment_proofs` storage bucket.
- **Payment Details Management (Bank, Airtel Money, TNM Mpamba)**:
  - Created Supabase table `public.payment_details` with RLS policies allowing customer reads and admin full management. Pushed migration `20260930_payment_details_table.sql`.
  - Added `PaymentDetailModel` and CRUD state methods in `SessionService` (`loadPaymentDetails`, `addPaymentDetail`, `updatePaymentDetail`, `deletePaymentDetail`).
  - Added customer-facing `PaymentDetailsModal` allowing users to view accounts and 1-tap copy account owner names and numbers with visual feedback.
  - Linked `PaymentDetailsModal` to Dashboard Quick Actions, Profile screen, and Proof of Payment upload sheet.
  - Added dedicated "Payment Accounts" tab in Admin Control Hub allowing administrators to add, edit, toggle visibility, and delete Bank, Airtel Money, and TNM Mpamba accounts.
- **About SheIn Connect & Developer Credits**:
  - Created `AboutScreen` highlighting "Developed by Techlink360".
  - Integrated direct launch buttons to Techlink360's Facebook page (`https://www.facebook.com/tlink360`) and WhatsApp (`0995936887` / `wa.me/265995936887`).
  - Added navigation tile in `ProfileScreen`.
- **CI/CD & Multi-Platform Release Automation**:
  - Created GitHub Actions workflow `.github/workflows/build_release.yml` automating compilation and releases for:
    - **Android**: Compiles `app-release.apk` (direct APK install) and `app-release.aab` (Google Play bundle).
    - **Linux**: Installs GTK & CMake build dependencies, compiles desktop binary, and packages into `shein-connect-linux-x64.tar.gz`.
    - **iOS**: Builds on `macos-14`, packages Runner bundle into `shein-connect-ios-unsigned.ipa`.
  - Configured automated GitHub Release publishing on version tags (`v*`) or manual triggers (`workflow_dispatch`).
- **Testing & Verification**:
  - Added integration test `test_supabase_user_orders.dart` covering order creation, proof-of-payment upload, receipt re-uploading, and order deletion.
  - Verified 0 errors and 0 warnings with `flutter analyze`.

## 2026-09-22
- Fixed multiple analyzer warnings in `cart_service.dart` and `session_service.dart` by removing unnecessary type checks and adding proper casting.
- Added `// ignore: use_build_context_synchronously` comment in `cart_screen.dart` to silence async‑context warning.
- Replaced invalid icon `Icons.shopping_bag_checkout` with `Icons.shopping_bag_outlined`.
- Rewrote the entire `SessionService` (`lib/services/session_service.dart`) to correct Dart syntax errors, improve error handling, and add comprehensive Supabase integration.
- Implemented robust order‑submission flow with session status verification, order header insertion, cart‑item snapshot into `order_items`, and offline fallback mock order creation.
- Added fallback demo procurement session when the database returns no data.
- Implemented `loadUserOrders` with proper JSON parsing and error logging.
- Cleaned up stale Windows build artefacts, killed lingering `shein_pro.exe` process, and performed `flutter clean`.
- Successfully rebuilt and ran the Windows desktop version; Supabase client initialized and connected.

## 2026-09-21
- Added splash screen and navigation to registration/login flow.
- Implemented registration form with validation for full name, email, Malawian phone number (10 digits), gender, and password.
- Implemented login form supporting email or phone (Malawian format) and password validation.
- Integrated Supabase Auth for email/password and phone sign‑in.
- Created local cart persistence using SharedPreferences.
- Added basic in‑app web view (`flutter_inappwebview`) to browse Shein site.
- Implemented product link capture and extraction of product name, price, variations, and description for adding to local cart.

## 2026-09-20
- Project scaffolding with Riverpod state management and folder structure.
- Added core utilities, constants, and error logging infrastructure.
- Set up Supabase service wrapper (`SupabaseService`).
- Added models for `CartItem`, `ProcurementSession`, `SessionOrder`, `OrderItem`.
- Implemented basic UI screens for splash, login, registration, cart, and session list.

*All changes are committed to the repository and the app builds without errors on Windows.*
