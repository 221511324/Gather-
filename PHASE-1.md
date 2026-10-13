# Gather — Phase 1 (Sprint 1)

This branch contains **only** the code for Sprint 1. It is a complete, running
Flutter app: it builds, it talks to the live Firebase project, and every screen
in it is finished. What it does not contain is anything belonging to a later
sprint, so nothing here is a stub or a placeholder.

## Scope — US1 to US7

Taken from the project charter, *Prioritized User Stories for Sprint 1*:

| User story | What it covers | Where it lives |
|---|---|---|
| US1 US2 | Create an account and log in | `features/auth/`, `features/splash/`, `features/onboarding/` |
| US3 | Manage my profile | `features/profile/` |
| US4 | Browse restaurants and menus | `features/home/`, `features/restaurant/`, `features/search/` |
| US5 | Create a group ordering session | `features/group/group_hub_screen.dart` |
| US6 | Invite by code, link, username or phone | `features/group/invite_sheet.dart` |
| U7 | Join a group session, see who is in it | `features/group/join_session_screen.dart`, `session_screen.dart` |

### Features implemented

- **Authentication** — registration, login, logout, password reset, secure access
- **User profile** — view and update personal information
- **Restaurant browsing** — restaurant list, restaurant detail, menus, item detail, search
- **Group session creation** — create a session and generate a unique 4-digit code
- **Group invitations** — invite by code, shareable link, username or phone number
- **Join a group session** — join with a code or link and view the participant list

## What is deliberately absent

These are **not** missing work; they are later sprints, and the code for them
has been removed from this branch rather than left half-wired.

| Sprint 2 | Sprint 3 |
|---|---|
| US8 restaurant suggestions and the spin wheel | US14 AI assistant |
| US9 shared group cart | US15 rewards and vouchers |
| US10 group payment options | US16 notifications |
| US11 order tracking | US17 application settings |
| US12 saved group sessions | US18 admin dashboard |
| US13 favourites | | US19 Share Stories |

Because of that, the bottom bar has **four** tabs in Phase 1 (Home, Search,
Group, Profile). Orders joins it in Phase 2. The menu item sheet shows an
item and its options but has no "add to cart" — that is US7/US8. The session
screen is the lobby: code, roster, invite, leave or cancel.

## Running it

```bash
flutter pub get
flutter run -d <device>
```

Firebase is already configured (`lib/firebase_options.dart`, project
`gather-856d1`). The restaurant catalogue seeds itself on first launch.

## Tests

```bash
flutter test                                              # 21 unit tests
flutter test integration_test/routes_test.dart -d <device>      # every Phase 1 route renders
flutter test integration_test/bottom_nav_test.dart -d <device>  # tab and highlight stay in sync
flutter test integration_test/group_join_test.dart -d <device>  # two real accounts, US4-US6
```

`group_join_test.dart` signs in as a host and a member in turn against the live
project, so every write is checked by the real security rules as the person who
would actually be making it.

## Layout

```
lib/
  app/          theme tokens, router, app shell
  core/
    models/     AppUser, Restaurant, MenuItem, GroupSession, CartLine
    services/   AuthService, CatalogService, SessionService, SeedService
    providers/  Riverpod providers
    widgets/    shared UI
  features/     one folder per screen area
```

48 Dart files. `flutter analyze` reports no issues.
