# 📌 EVIM — ARCHITECTURAL IMPLEMENTATION PLAN

Evim is a multi-tenant family SaaS and expat life operating system designed for Arab and international resident households in Turkey. It streamlines shared household operations, real-time grocery lists, recurring bills & Aidat tracking, critical residency deadlines, kitchen pantry management, and Turkish administrative workflows.

---

## 1. Project Overview & Business Domain
* **App Name:** Evim (Package / Bundle ID: `com.evim.app`)
* **Type:** Multi-Tenant Family SaaS / Expat Life Operating System in Turkey
* **Target Audience:** Arab and international resident households living in Turkey
* **Core Value Proposition:** Managing shared household operations in one unified workspace:
  1. Real-time synchronised grocery lists between family members and spouses.
  2. Recurring utility bills & Aidat (building dues) tracking.
  3. Critical residency & legal deadlines (İkamet renewal, rental contracts, TÜVTÜRK inspection, DASK).
  4. Kitchen pantry inventory & AI recipe suggestions based on on-hand ingredients.
  5. Interactive step-by-step guides for Turkish administrative workflows (E-Devlet, Adres Kaydı, utility subscriptions).
  6. Multi-home switching (Primary residence, summer house / Yazlık, family properties).

---

## 2. Technical Stack & Infrastructure
* **Frontend:** Flutter (iOS & Android) with Material 3 design system.
* **State Management:** Flutter Riverpod (`AsyncNotifierProvider`, `StreamProvider`).
* **Backend as a Service (BaaS):** Supabase (PostgreSQL, Supabase Auth, Supabase Realtime, Storage, Edge Functions).
* **Database Configuration (`.env`):**
  * `SUPABASE_URL`: `https://velgkvvaobpqcpkzsmwn.supabase.co`
  * `SUPABASE_ANON_KEY`: `sb_publishable__dUGVexcNBn0rzQJoCVxIQ_lb_jQtrq`
* **In-App Purchases / SaaS Paywall:** RevenueCat (household-level entitlements).
* **Push Notifications:** Firebase Cloud Messaging (FCM) + Supabase Edge Functions / `pg_cron`.
* **AI Integration:** Lightweight LLM API for kitchen recipe generation from ingredients.

---

## 3. Core Architectural Principles

### A. Household-Level Multi-Tenancy
* **Data Isolation:** All operational tables (`shopping_items`, `recurring_expenses`, `critical_deadlines`, `pantry_items`) MUST hold a foreign key `household_id references households(id)`.
* **Membership Model:** Users maintain distinct user accounts (`auth.users`). Spouses and housemates are linked via the `household_members` junction table.
* **Active Household Context:** The client state must maintain an active `current_household_id`. Switching homes alters this context and triggers a reactive re-fetch of all active streams.
* **Security (RLS):** Supabase Row Level Security must enforce that a user cannot read, insert, update, or delete records unless `household_id in (select get_my_households())`.

### B. Validation & Data Integrity Standards
All inputs must undergo two layers of validation (Client-side & DB Constraints):
1. **Email:** Standard RFC 5322 regex validation.
2. **Password:** Minimum 8 characters, at least 1 uppercase letter, and 1 numeric digit.
3. **Invite Code:** Exactly 6 uppercase alphanumeric characters (`^[A-Z0-9]{6}$`).
4. **Financial Inputs:** Strictly positive numeric values with standard Turkish Lira formatting (`TRY`).
5. **Turkish Mobile:** Format verification (`+90 5XX XXX XX XX`).

### C. Error Handling Strategy
* Catch all `PostgrestException` and `AuthException` within the Repository layer.
* Map errors to a unified domain failure model (`AppException`).
* Return localized, user-friendly error strings in Arabic and Turkish (never expose raw database errors or stack traces to the UI).

---

## 4. Phased Implementation Roadmap

### Phase 0: Project Scaffolding & Standards
* Clean Architecture folder structure (`core/`, `features/`).
* Environment configuration via `flutter_dotenv`.
* Core utility validators, Evim visual theme, and failure handling classes.

### Phase 1: Authentication & Session Engine
* Email & password authentication flow (Sign in, Sign up, Password recovery).
* Session lifecycle tracking & auto-token refresh.
* Route guarding: Redirect to `AuthScreen` if unauthenticated; redirect to `HouseholdSetupScreen` if user has no linked home; redirect to `HomeScreen` if active home exists.

### Phase 2: Household Engine & Invitation Flow
* Household entity creation: Automatic generation of a 6-character unique invite code.
* Role assignment: Creator as `owner`, partner joining via code as `member`.
* Household switcher state logic for multi-home accounts.

### Phase 3: Real-Time Collaborative Shopping & Kitchen Pantry
* Instant bidirectional syncing via `Supabase Realtime Stream`.
* Automated categorization based on major Turkish supermarket chains (BİM, A101, Şok, Migros, Bazaar).
* Kitchen pantry tracker and recipe generator bridge (converts missing recipe items to shopping tasks).

### Phase 4: Expense Radar, Utility Bills & Critical Deadlines
* Expense calculation engine (Monthly budget, Aidat, utilities, rental payments).
* Life Deadlines radar with dynamic warning intervals (İkamet renewal 60-day alert, TÜVTÜRK, DASK).
* Scheduled notification dispatcher via FCM.

### Phase 5: Interactive Turkish Government Guide (Gov-Guide)
* Cloud-driven interactive checklists (Adres Kaydı, utility connection, Tax Number).
* Progress persistence and one-tap conversion of legal steps into household deadlines.

### Phase 6: Multi-Home Paywall & SaaS Monetization
* RevenueCat integration for weekly/monthly/annual subscriptions in TRY.
* Entitlement propagation: Household-level premium status (if one spouse pays, the household unlocks premium perks).
* Multi-home feature gating (1 home free/standard, up to 3 homes on Family Plus).

---

## 5. Definition of Done (DoD)
* Zero cross-tenant data leaks across household boundaries.
* Sub-second synchronization latency on shopping list modifications.
* Graceful offline handling: Cached views when mobile data drops inside stores.
* 100% null-safe Dart code adhering to strict linting rules.

---

## 6. Verification Plan

### Automated Tests
- Unit tests for core validators (RFC 5322 email, password strength, Turkish phone number format, invite code regex).
- Unit tests for domain models and JSON serialization/deserialization.
- Repository layer tests mocking Supabase client responses and verifying `AppException` mapping.
- Riverpod state notifier tests for household switching and session management.

### Manual Verification
- Verify Supabase RLS policies directly via SQL queries ensuring cross-household data isolation.
- Real-time shopping sync test across two connected devices/clients.
- Test onboarding routing flow: unauthenticated $\rightarrow$ setup household $\rightarrow$ home dashboard.
