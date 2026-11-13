# Gather – Group Food Ordering Application

Gather is a mobile food-ordering application developed as a senior project at Prince Sultan University (PSU). It is designed to make ordering food with friends easier by allowing users to create or join group sessions, browse restaurants, select meals, and manage their orders together.

Instead of coordinating everyone's choices separately, Gather brings the group into one shared ordering experience. Each participant can add and manage their own food items, while the host coordinates the restaurant selection and payment arrangement.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Main Features](#main-features)
- [Technology Stack](#technology-stack)
- [Application Architecture](#application-architecture)
- [AI Assistant Implementation](#ai-assistant-implementation)
- [Firebase and Database](#firebase-and-database)
- [Payment Implementation](#payment-implementation)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Firebase Configuration](#firebase-configuration)
- [Gemini API Configuration](#gemini-api-configuration)
- [Running the Application](#running-the-application)
- [Testing](#testing)
- [Development Commands](#development-commands)
- [Project Team](#project-team)

---

## Project Overview

Gather addresses common difficulties in group food ordering, such as collecting individual meal choices, deciding on a restaurant, organizing shared orders, and dividing the total cost.

The application provides a shared environment where users can:

1. Create a group ordering session.
2. Invite friends using a session code or invitation link.
3. Browse available restaurants and menus.
4. Add food items to a shared group cart.
5. Participate in restaurant selection.
6. Choose a payment arrangement.
7. Follow order progress.
8. Use additional features such as the AI food assistant, rewards, and Food Stories.

The application supports both English and Arabic.

## Main Features

### 1. User Accounts and Profiles

- User registration and login.
- Authentication using Firebase Authentication.
- User profile viewing and editing.
- Username-based user lookup.
- Account settings and language preferences.
- Personal payment methods and saved information.

### 2. Restaurant Browsing

- Browse available restaurants.
- View restaurant information and menus.
- Search for restaurants and food items.
- View food descriptions, prices, ratings, and availability.
- Explore best-selling and recommended food items.
- Add restaurants and dishes to favourites.

### 3. Group Ordering Sessions

- Create a group session as the host.
- Generate a unique four-digit session code.
- Invite other users through a shareable link or session code.
- Find and invite users by username.
- Join an existing session using its four-digit code.
- View group members and their participation.
- Manage the session as the host.

### 4. Shared Cart

- Add food items to the group order.
- Allow participants to manage their own cart items.
- Display the group's selected items in a shared session.
- Update quantities and item details.
- Keep group order information synchronized through Cloud Firestore.

Each participant manages their own items, while the host has additional control over the overall session.

### 5. Restaurant Selection

- Allow group members to suggest restaurants.
- Support group participation in restaurant decisions.
- Allow the host to manage the final restaurant selection.
- Include the Restaurant Spin feature to help groups decide where to order.

### 6. Payment Options

Gather supports different ways to divide the group order:

- **Individual Payment:** Each participant pays for the items they selected.
- **Equal Split:** The total amount is divided equally among participants.
- **Host Pays:** The host covers the group's total amount.

The application also supports payment methods managed through the administrator functionality.

**Note:** Payment processing in the current application is simulated. Gather does not connect to a live payment gateway or process real financial transactions.

### 7. Orders and Tracking

- View order information.
- Follow order status and progress.
- Display delivery progress.
- Provide order-related notifications.

The application includes simulated delivery progress rather than a connection to an external delivery provider.

### 8. Saved Sessions and Favourites

- Save group sessions for later access.
- View previously saved sessions.
- Manage favourite restaurants and food items.

### 9. AI Food Assistant

The AI assistant helps users discover food, receive recommendations, and understand how to use Gather.

It supports:
- Food and dish recommendations.
- Restaurant-related questions.
- Recommendations based on food categories.
- Budget-based food filtering.
- Popular and highly rated food suggestions.
- Questions about using Gather.
- English and Arabic responses.

The assistant uses Gather's restaurant and menu catalogue to provide relevant answers.

The AI implementation is explained in detail in the [AI Assistant Implementation](#ai-assistant-implementation) section.

### 10. Spin & Win Rewards

- Allow users to participate in the Spin & Win feature.
- Provide rewards and vouchers.
- Manage reward information through the application.
- Apply reward-related rules to user participation.

### 11. Food Stories

- Allow users to share food-related stories.
- Display stories within the application.
- Provide a social-style way to share food experiences.

### 12. Notifications

- Receive notifications related to orders and group activity.
- Display notification information inside the application.
- Support local notifications for order updates.

### 13. Administrator Features

The administrator functionality provides management capabilities, including:

- Manage restaurant and menu catalogue information.
- Manage users and administrative roles.
- Monitor group sessions and orders.
- Manage available payment methods.
- Manage rewards and vouchers.
- Manage support requests.
- Control application-related administrative information.

---

## Technology Stack

| Category | Technology |
|---|---|
| Frontend | Flutter |
| Programming Language | Dart |
| State Management | Riverpod |
| Navigation | GoRouter |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| AI Integration | Google Gemini |
| HTTP Communication | HTTP package |
| Local Preferences | Shared Preferences |
| Unique Identifiers | UUID |
| Date and Number Formatting | Intl |
| Testing | Flutter Test and Integration Test |
| Version Control | Git and GitHub |

### Main Dependencies

The application uses the following packages, defined in `pubspec.yaml`:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `flutter_riverpod`
- `go_router`
- `intl`
- `uuid`
- `collection`
- `shared_preferences`
- `cached_network_image`
- `share_plus`
- `http`

---

## Application Architecture

Gather follows a service-oriented Flutter application structure.

The application separates its interface, data models, state management, and business logic into different areas.

### Architecture Layers

**1. Presentation Layer**

Contains the application screens and user interface components. It is responsible for displaying information and handling user interactions.

**2. State Management Layer**

Riverpod manages application state and provides access to application services and data.

**3. Service Layer**

Contains the main application logic, including authentication, sessions, restaurants, cart management, orders, payments, notifications, rewards, and the AI assistant.

**4. Data Layer**

Cloud Firestore stores and synchronizes application information, while Firebase Authentication manages user authentication.

### Main Service Files

| File | Responsibility |
|---|---|
| `auth_service.dart` | User authentication and profile operations |
| `catalog_service.dart` | Restaurant and menu catalogue |
| `session_service.dart` | Group session management |
| `cart_service.dart` | Cart operations |
| `order_service.dart` | Order management and calculations |
| `payment_service.dart` | Payment options and simulated payment processing |
| `admin_service.dart` | Administrative operations |
| `assistant_service.dart` | AI assistant interface and local recommendation logic |
| `gemini_brain.dart` | Google Gemini integration |
| `notification_service.dart` | Application notifications |
| `story_service.dart` | Food Stories functionality |
| `voucher_service.dart` | Voucher and reward management |
| `spin_service.dart` | Spin & Win functionality |
| `support_service.dart` | Support request management |
| `seed_service.dart` | Initial catalogue setup |

---

## AI Assistant Implementation

Gather includes an AI food assistant implemented using two interchangeable components:

- `RetrievalBrain`
- `GeminiBrain`

Both implement the `AssistantBrain` interface defined in:

`lib/core/services/assistant_service.dart`

### 1. RetrievalBrain – Local Recommendation Logic

`RetrievalBrain` provides an on-device recommendation mechanism based on Gather's existing restaurant and menu catalogue.

It processes user questions using predefined matching logic.

The implementation can:

- Identify food categories such as desserts, drinks, snacks, meals, and vegan options.
- Detect budget-related requests.
- Search for dish names and ingredients.
- Identify questions about specific restaurants.
- Sort recommendations using price, ratings, and best-seller information.
- Answer predefined questions about how to use Gather.

This component does not require an external AI model or an API key.

### 2. GeminiBrain – Google Gemini Integration

The application also integrates Google's Gemini model.

**Model used:** `gemini-3.5-flash-lite`

The implementation is located in:

`lib/core/services/gemini_brain.dart`

Gemini is accessed through Google's `generateContent` REST endpoint using the HTTP package.

The application sends the user's question together with relevant context from Gather's restaurant and food catalogue.

The request includes:
- System instructions describing the assistant's role.
- The available restaurant and food catalogue.
- Previous conversation messages.
- The user's current question.
- A structured JSON response schema.

The response contains:
- A text answer.
- Recommended food item IDs.
- Restaurant IDs.
- An action describing the type of response.

The application validates returned item and restaurant IDs against its own catalogue. Unknown IDs are discarded, preventing the assistant from displaying recommendations that do not exist in Gather's data.

The assistant supports English and Arabic responses.

### 3. Automatic Fallback Mechanism

Gather is designed to keep the assistant available even when Gemini cannot respond.

The application selects the assistant implementation through:

`lib/core/providers/providers.dart`

- If a usable Gemini API key is provided, the application uses `GeminiBrain`.
- If a usable key is not available, the application uses `RetrievalBrain`.
- If the Gemini request fails, times out, or returns an invalid response, the application falls back to `RetrievalBrain`.

The Gemini request timeout is configured to 4.5 seconds.

This approach allows Gather to provide food recommendations even when the external Gemini service is unavailable.

### AI Assistant Source Files

| File | Purpose |
|---|---|
| `assistant_service.dart` | Defines `AssistantBrain`, `AssistantContext`, `AssistantReply`, and `RetrievalBrain` |
| `gemini_brain.dart` | Handles Gemini requests, catalogue context, structured responses, and fallback |
| `providers.dart` | Selects the appropriate assistant implementation |
| `assistant_message.dart` | Represents assistant conversation messages |

---

## Firebase and Database

Gather uses Firebase services for authentication and application data management.

### Firebase Authentication

Firebase Authentication manages user sign-up, login, and authentication state.

### Cloud Firestore

Cloud Firestore is the main database used to store and synchronize application data.

The database contains collections and documents for:

| Collection | Purpose |
|---|---|
| `users` | User profiles and account information |
| `usernames` | Username lookup and uniqueness |
| `restaurants` | Restaurant information |
| `restaurants/{restaurantId}/menu` | Restaurant menu items |
| `sessions` | Group ordering sessions |
| `sessionCodes` | Four-digit session code lookup |
| `orders` | Order information |
| `vouchers` | Voucher information |
| `tickets` | Support requests |
| `meta` | Application metadata and catalogue setup |

User-related subcollections include:

- `cart`
- `savedSessions`
- `paymentMethods`
- `aiChat`
- `vouchers`
- `notifications`

Group sessions also contain a `lines` subcollection for shared cart items.

### Real-Time Synchronization

Cloud Firestore streams are used to keep relevant application information updated.

For example, group members can see changes to the shared session and cart without manually refreshing the application.

### Firestore Security Rules

Database access is controlled through:

`firestore.rules`

The rules include:
- Authentication checks.
- User ownership restrictions.
- Administrator role verification.
- Session membership validation.
- Host-specific permissions.
- Restrictions on modifying other participants' cart items.
- Protection of user privilege fields such as roles and account status.
- A default deny rule for unmatched database paths.

Firebase configuration files:

- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`
- `lib/firebase_options.dart`

The Firebase project is configured for the Android, iOS, and web application targets.

---

## Payment Implementation

Gather provides three group payment arrangements: Individual Payment, Equal Split, and Host Pays.

The payment implementation is organized in:

`lib/core/services/payment_service.dart`

The application uses a `PaymentGateway` abstraction and a `SimulatedPaymentGateway` implementation.

This allows the application to demonstrate payment-related workflows without connecting to a real payment provider.

Payment information and available payment methods are managed through the application's services and Firestore data.

No real card transaction or external payment gateway processing is performed.

---

## Project Structure

The repository root contains the latest complete Gather application.

```text
Gather-/
│
├── android/
├── ios/
├── web/
│
├── assets/
│   ├── images/
│   └── fonts/
│
├── lib/
│   ├── app/
│   │   └── app.dart
│   │
│   ├── core/
│   │   ├── models/
│   │   ├── providers/
│   │   │   ├── app_prefs.dart
│   │   │   └── providers.dart
│   │   │
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── catalog_service.dart
│   │   │   ├── session_service.dart
│   │   │   ├── cart_service.dart
│   │   │   ├── order_service.dart
│   │   │   ├── payment_service.dart
│   │   │   ├── admin_service.dart
│   │   │   ├── assistant_service.dart
│   │   │   ├── gemini_brain.dart
│   │   │   ├── notification_service.dart
│   │   │   ├── story_service.dart
│   │   │   ├── voucher_service.dart
│   │   │   ├── spin_service.dart
│   │   │   └── support_service.dart
│   │   │
│   │   └── ...
│   │
│   ├── features/
│   │   └── Application feature screens and components
│   │
│   ├── l10n/
│   │   └── Localization resources
│   │
│   ├── firebase_options.dart
│   └── main.dart
│
├── test/
│   └── Unit and widget tests
│
├── integration_test/
│   └── Integration and system tests
│
├── Sprint2/
│   └── Sprint 2 project snapshot
│
├── Sprint3/
│   └── Sprint 3 project snapshot
│
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── PHASE-1.md
└── README.md
```

**Note:** `Sprint2/` and `Sprint3/` are retained as sprint snapshots. The repository root is the main application to install and run.

---

## Getting Started

### Prerequisites

Before running Gather, make sure the following tools are installed:

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Android emulator or a physical Android device
- Xcode for iOS development on macOS
- A Firebase project with Authentication and Cloud Firestore configured
- A Google Gemini API key if Gemini-powered responses are required

### 1. Clone the Repository

```bash
git clone https://github.com/221511324/Gather-.git
```

Navigate to the project directory:

```bash
cd Gather-
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Check the Flutter Environment

```bash
flutter doctor
```

Resolve any required setup issues before running the application.

---

## Firebase Configuration

The repository includes Firebase configuration files for the configured application platforms.

The main Firebase initialization is performed in:

`lib/main.dart`

The application initializes Firebase using:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

The platform-specific Firebase options are defined in:

`lib/firebase_options.dart`

To use the application with Firebase:

1. Make sure the Firebase project is accessible.
2. Enable the Email/Password sign-in provider in Firebase Authentication.
3. Create or enable the Cloud Firestore database.
4. Deploy the Firestore security rules and indexes when setting up a new Firebase environment.

To deploy Firestore rules and indexes, install and authenticate the Firebase CLI, then run:

```bash
firebase login
firebase deploy --only firestore:rules,firestore:indexes
```

The repository's Firebase configuration is connected to the Gather project. If using a separate Firebase project, regenerate the platform configuration with the FlutterFire CLI.

---

## Gemini API Configuration

Gemini is optional because Gather includes the local `RetrievalBrain` fallback.

To enable Gemini-powered responses, create a local configuration file.

### 1. Create the Configuration Directory

From the project root:

```bash
mkdir -p config
```

### 2. Create `config/secrets.json`

```json
{
  "GEMINI_API_KEY": "PASTE_YOUR_GEMINI_API_KEY_HERE"
}
```

Replace `PASTE_YOUR_GEMINI_API_KEY_HERE` with a valid API key from Google AI Studio.

This value is a placeholder. It must be replaced with your own key.

### 3. Protect the API Key

Do not commit your actual API key to GitHub.

Add the following line to `.gitignore`:

```gitignore
config/secrets.json
```

The API key is read in `gemini_brain.dart` using:

```dart
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
```

The application receives the value through Flutter's `--dart-define-from-file` option.

---

## Running the Application

### Run with Gemini Enabled

After creating `config/secrets.json`, run:

```bash
flutter run --dart-define-from-file=config/secrets.json
```

### Run Without Gemini

To use the local recommendation assistant instead:

```bash
flutter run
```

Without a usable Gemini key, the application selects `RetrievalBrain`.

### Run on a Specific Device

First, list available devices:

```bash
flutter devices
```

Then run the application on the selected device:

```bash
flutter run -d DEVICE_ID
```

To run with Gemini on a specific device:

```bash
flutter run -d DEVICE_ID --dart-define-from-file=config/secrets.json
```

Replace `DEVICE_ID` with the identifier displayed by `flutter devices`.

---

## Testing

Gather includes unit, widget, integration, and system-level test files.

### 1. Unit and Widget Tests

The test files are located in:

`test/`

They cover application logic and individual components, including:

- AI assistant responses.
- Gemini request and response handling.
- Localization.
- Date and money calculations.
- Payment logic.
- Reward rules.
- Spin functionality.
- Notifications.
- UI components.

Run the Flutter test suite:

```bash
flutter test
```

### 2. Integration and System Tests

Integration tests are located in:

`integration_test/`

They cover application workflows and interactions, including:

- Application navigation and routes.
- User stories from different sprints.
- Group session creation and joining.
- Shared cart behavior.
- Payment workflows.
- AI assistant functionality.
- Rewards and Spin & Win.
- Stories.
- Notifications and settings.
- System and non-functional requirements.

Run an individual integration test on a connected device:

```bash
flutter test integration_test/sprint3_system_tests.dart -d DEVICE_ID
```

Other integration test files can be executed individually by replacing the file name.

Some integration tests require a configured Firebase environment and appropriate test data.

### 3. Sprint 3 Testing Documentation

The Sprint 3 testing documentation is maintained separately in the project deliverables.

It records the Sprint 3 test cases, testing results, identified defects, and corrections.

---

## Development Commands

| Command | Description |
|---|---|
| `flutter pub get` | Install project dependencies |
| `flutter doctor` | Check Flutter development setup |
| `flutter devices` | List connected devices |
| `flutter run` | Run the application |
| `flutter test` | Run unit and widget tests |
| `flutter analyze` | Analyze Dart code |
| `dart format lib test integration_test` | Format source and test files |
| `flutter clean` | Remove generated build files |

---

## Project Team

Developed by Software Engineering students at:

**Prince Sultan University (PSU)**  
College of Computer and Information Sciences  
Senior Project

- Rama Alrashodi
- Mashael Aljarbou
- Reema Alnamazi
- Dana Albassam
- Tib Othman

---

## Important Notes

- The repository root contains the latest complete Gather application.
- The `Sprint2/` and `Sprint3/` directories are retained as sprint snapshots.
- Firebase Authentication and Cloud Firestore are used for authentication and application data.
- Gemini-powered responses require a valid API key. The local `RetrievalBrain` provides a fallback.
- Payment processing is simulated and does not perform real transactions.
- Delivery progress is simulated within the application.

---

**Gather – Making group food ordering easier, together.**
