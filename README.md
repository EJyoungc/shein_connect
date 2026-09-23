# 🛍️ SheIn Connect (Malawi)

**SheIn Connect** is a cross-platform consolidated procurement and freight aggregation mobile & desktop application. It enables shoppers in Malawi to browse Shein's international catalogue, capture product details (colors, sizes, live pricing) into a local cart, aggregate orders into procurement batches, and submit orders directly with local payment verification (Bank Transfer, Airtel Money, and TNM Mpamba).

Developed with pride by **Techlink360**.

---

## 🌟 Key Features

### 🛒 1. Seamless In-App Shein Browsing & Product Capture
- Embedded, high-performance in-app browser (`webview_flutter` & `webview_windows`).
- **1-Tap Product Capture**: Automatically parses and extracts item title, variation (size, color, SKU), high-resolution imagery, and USD pricing.
- Local shopping cart with persistent offline caching (`SharedPreferences`).

### 📦 2. Procurement Batch Sessions
- Group orders into consolidated procurement batches with live exchange rates (MWK per USD).
- Direct pricing calculation in Malawi Kwacha (MWK).
- Session lock safeguards to protect orders during consolidated freight shipping.

### 💳 3. Payment Accounts & 1-Tap Copying
- Customers can view and 1-tap copy verified payment accounts for:
  - **National Bank of Malawi**
  - **Airtel Money**
  - **TNM Mpamba**
- Accessible from Customer Dashboard, Profile, and Proof of Payment sheet.

### 🧾 4. Proof of Payment Upload & Replacement
- Direct photo/receipt selection (`image_picker`).
- Instant image preview and upload directly to Supabase Storage (`payment_proofs` bucket).
- **"Change Proof"** capability allowing customers to replace slips with automated verification state updates.
- Ability for users to cancel/delete unverified orders.

### 🛡️ 5. Administrator Control Hub
- **KPI Metrics Dashboard**: Tracks total revenue (MWK), order volumes, and pending receipt verifications.
- **Session Governance**: Create and manage procurement sessions, toggle lock states, and configure exchange rates.
- **Order Processing**: Review order snapshots, examine receipt attachments, approve/reject payment states, and migrate orders across batches.
- **Payment Destination Config**: Add, edit, toggle visibility, and remove Bank, Airtel Money, and TNM Mpamba accounts.

### ℹ️ 6. About SheIn Connect & Developer Credits
- Dedicated About screen honoring **Techlink360**.
- Direct launch shortcuts to:
  - **Facebook**: [facebook.com/tlink360](https://www.facebook.com/tlink360)
  - **WhatsApp**: [+265 995 936 887](https://wa.me/265995936887)

---

## 🏗️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.11.4`)
- **Backend & Database**: [Supabase](https://supabase.com) (PostgreSQL with Row-Level Security, Storage, Auth)
- **State Management**: [Riverpod](https://riverpod.dev) & [Provider](https://pub.dev/packages/provider)
- **Networking & Web**: `http`, `webview_flutter`, `webview_windows`, `url_launcher`
- **Supported Platforms**: Android, iOS, Windows Desktop, Linux Desktop, Web

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24+ recommended)
- Git & modern C++ compilers (for Windows/Linux desktop builds)

### 1. Clone & Setup Dependencies
```bash
git clone <repository-url>
cd shein_pro
flutter pub get
```

### 2. Environment Configuration
Create a `.env` file in the project root (see `.env.example`):
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
APP_ENV=development
```

### 3. Run the App
```bash
# Windows Desktop
flutter run -d windows

# Android Device / Emulator
flutter run -d android

# Chrome / Web
flutter run -d chrome
```

---

## 🔄 Version Bumping & Release Automation (`bump.cmd`)

The project includes an automated version bumper and Git release utility:

```cmd
# Increments patch version (e.g., 1.0.0 -> 1.0.1+2), updates files, commits, tags, and pushes
bump.cmd

# Increment minor version (e.g., 1.0.1 -> 1.1.0+3) with custom message
bump.cmd minor "feat: added new payment options"

# Increment major version (e.g., 1.1.0 -> 2.0.0+4)
bump.cmd major "release: version 2.0.0"
```

Files automatically synchronized:
1. `pubspec.yaml` (`version: X.Y.Z+B`)
2. `lib/core/constants/app_config.dart` (`appVersion`, `buildNumber`)
3. `CHANGELOG.md` (adds release version header)
4. Git operations: executes `git add .`, commits with `chore(release): bump version to vX.Y.Z`, tags `vX.Y.Z`, and pushes to remote.

---

## 🤖 CI/CD Pipeline (GitHub Actions)

Located at [`.github/workflows/build_release.yml`](.github/workflows/build_release.yml):
- **Android**: Compiles `SheIn-Connect-Android.apk` and `SheIn-Connect-Android.aab`.
- **Linux**: Installs GTK3 build libraries, compiles desktop binary, and packages `shein-connect-linux-x64.tar.gz`.
- **iOS**: Builds on `macos-14` and packages `shein-connect-ios-unsigned.ipa`.
- **GitHub Releases**: Automatically publishes a release when pushing tags matching `v*` (or via manual workflow dispatch).

---

## 📄 License & Attribution

- Application Architecture & Development: **Techlink360**
- WhatsApp: `0995936887`
- Facebook: [https://www.facebook.com/tlink360](https://www.facebook.com/tlink360)
- All rights reserved.
