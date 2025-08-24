# Copilot Instructions for Deuda Flow Flutter

## Project Overview
- This is a Flutter app for debt management, supporting offline/online sync, user sessions, and multi-platform deployment (Android, iOS, Web, Desktop).
- Data is stored locally using Hive and synced to Supabase (PostgreSQL backend).
- The app enforces single-session-per-device logic using a local device ID (not hardware ID).

## Key Architecture
- `lib/main.dart`: App entry point, initializes Supabase, Hive, and providers.
- `lib/services/`: Core business logic and backend integration:
  - `session_authority_service.dart`: Manages session authority, device ID, and real-time sync with Supabase.
  - `supabase_service.dart`: Handles all Supabase data operations (CRUD, sync, user settings).
- `lib/models/`: Data models for clients and transactions, including Hive adapters.
- `lib/providers/`: State management using Provider for clients, transactions, sync, navigation, etc.
- `lib/screens/`: UI screens for login, dashboard, transactions, etc.
- `lib/widgets/`: Reusable UI components and theming.
- `lib/offline/offline_helper.dart`: Utilities for offline data persistence and sync.

## Developer Workflows
- **Build (Android .aab):**
  - `flutter build appbundle --release`
- **Run (Web):**
  - `flutter run -d chrome`
- **Local Storage:**
  - Uses Hive; boxes are opened in `main.dart` and `offline_helper.dart`.
- **Sync:**
  - Supabase is the source of truth; local changes are synced when online.
- **Session Management:**
  - Device ID is generated and stored locally (not hardware ID), synced to Supabase for session authority.

## Project Conventions
- Spanish is used for code comments and some identifiers.
- All business logic and data access are in `services/` and `offline/`.
- UI logic is separated into `screens/` and `widgets/`.
- Providers are used for state management; avoid direct setState in screens.
- Do not use hardware/system device IDs; only use the app-generated device ID.
- Use `BudgetoTheme` and `budgeto_colors.dart` for consistent theming.

## External Integrations
- **Supabase:** Auth, real-time sync, and data storage.
- **Hive:** Local/offline storage.
- **Provider:** State management.
- **Other:** Google Sign-In, PDF/printing, app links, permissions, etc.

## Examples
- See `session_authority_service.dart` for device/session logic.
- See `offline_helper.dart` for offline-first patterns.
- See `main.dart` for initialization and provider setup.

---
If you are unsure about a workflow or pattern, check the relevant file in `lib/services/`, `lib/providers/`, or `lib/offline/` for examples.
