# Gather – Group Food Ordering Application

## Overview

Gather is a mobile application designed to simplify group food ordering by bringing the entire ordering process into one shared experience. Instead of having each person browse restaurants, decide what to order, and coordinate payments separately, Gather allows friends to organize their food orders through a shared group session.

The application enables users to discover restaurants, create or join group sessions, add food items to a shared cart, select a payment arrangement, and follow order progress. It also provides additional features such as an AI food assistant, food stories, rewards, vouchers, notifications, and an administrative dashboard.

Gather was developed as a Senior Graduation Project at Prince Sultan University using Flutter and Firebase.

---

## Main Features

### 1. User Authentication and Profile Management

Users can create accounts, log in, and access their personal profiles.

Features include:

- User registration and login.
- User profile management.
- Username management.
- Account-related settings.
- English and Arabic language support.

### 2. Restaurant Browsing and Menus

Users can explore available restaurants and browse their menus before starting or joining a group order.

Features include:

- Restaurant listings.
- Restaurant details.
- Menu categories.
- Food item details.
- Favorites for preferred restaurants.

### 3. Group Ordering Sessions

Group ordering is the main functionality of Gather.

A user can create a group session and become its host. The application generates a unique four-digit session code that other users can use to join.

The group session allows participants to:

- Create a group order.
- Join an existing session using its code.
- View the shared group session.
- Browse restaurants and select food.
- Coordinate their orders with other participants.

The host has additional session-management permissions.

### 4. Shared Shopping Cart

Gather provides a shared cart where all participants can coordinate their food selections.

Each participant can:

- Add food items to the group cart.
- Edit their own cart items.
- Remove their own items.
- View the items added by other participants.
- Follow the group's order selections.

This approach keeps the group order organized and allows participants to manage their individual selections.

### 5. Payment Options

Gather provides three payment arrangements for group orders:

- **Individual Payment:** Each participant is responsible for their own order.
- **Equal Split:** The total amount is divided equally among participants.
- **Host Pays:** The host is responsible for the group order.

Payment operations are simulated within the application for demonstration purposes. Gather does not process real financial transactions or connect to a live payment gateway.

### 6. Order Tracking

Users can follow the progress of their group orders through the application's order-tracking functionality.

The application displays order progress and related status updates. Tracking is handled within Gather and does not depend on an external delivery provider API.

### 7. Saved Group Sessions

Users can save group sessions and access their saved sessions later.

This feature helps users keep track of previous group-order activities.

### 8. Favorites

Users can save their preferred restaurants for easier access when browsing available restaurants.

### 9. AI Food Assistant

Gather includes an AI-powered food assistant integrated with Google Gemini.

The assistant helps users make food decisions and supports the group-ordering experience.

Its capabilities include:

- Providing food recommendations.
- Suggesting available restaurant menu items.
- Helping users choose food based on their preferences.
- Answering questions about restaurants and food.
- Assisting users with questions about using Gather.
- Supporting English and Arabic conversations.

The assistant uses available restaurant and menu information to provide relevant recommendations.

**AI Implementation**

The application uses a service-based architecture for the assistant:

`AssistantScreen → AssistantService → AssistantBrain`

The application supports two assistant implementations:

- **GeminiBrain:** Communicates with Google Gemini using an HTTP request.
- **RetrievalBrain:** A local rule-based assistant that provides fallback responses.

When a valid Gemini API key is configured, the application can use Gemini. If the key is unavailable or a request fails, the application falls back to the local assistant.

The Gemini API key is not included in the public repository. Developers must configure their own key locally.

### 10. Food Stories

Gather includes a food stories feature that allows users to upload and share food pictures.

Stories provide a social element within the application and allow users to share food-related content.

Story records are stored in the root-level `stories` collection in Cloud Firestore.

### 11. Spin & Win

The Spin & Win feature provides users with an interactive spinning wheel through which they can receive available rewards and vouchers.

The feature is designed to make the food-ordering experience more engaging.

### 12. Vouchers and Rewards

Users can access available vouchers and rewards through the application.

The rewards functionality is connected to the Spin & Win feature.

### 13. Notifications

Gather includes a notification feature to keep users informed about relevant application activities and updates.

### 14. Admin Dashboard

Gather includes administrative functionality for managing application data and settings.

The administrative features include:

- Managing restaurant information.
- Managing payment methods.
- Adding new accepted payment methods.
- Enabling and disabling payment methods.
- Managing administrative application data.

Payment methods are managed dynamically through the application's administrative functionality rather than requiring changes to the application code whenever a new method is added.

### 15. Application Settings

Users can access application settings to manage their preferences.

The application supports language selection between English and Arabic.

---

## Technology Stack

| Technology              | Purpose                                       |
| ----------------------- | --------------------------------------------- |
| Flutter                 | Cross-platform mobile application development |
| Dart                    | Main programming language                     |
| Firebase Authentication | User authentication                           |
| Cloud Firestore         | Cloud database and data management            |
| Google Gemini           | AI-powered food assistant                     |
| Riverpod                | Application state management                  |
| GoRouter                | Application navigation                        |
| HTTP                    | Communication with the Gemini API             |
| Shared Preferences      | Local preference storage                      |

---

## Application Architecture

Gather follows a structured architecture that separates the user interface, state management, application logic, and data operations.

### Presentation Layer

The presentation layer contains the application's screens and user interface components. It handles user interactions and displays application data.

### State Management Layer

Riverpod is used to manage application state and provide application services to the relevant screens.

### Service Layer

The service layer contains the main application operations, keeping business logic separate from the user interface.

It includes services responsible for:

- Authentication.
- Restaurant catalogues.
- Group sessions.
- Shopping carts.
- Orders.
- Payments.
- Notifications.
- AI assistance.
- Food stories.
- Vouchers and rewards.
- Administrative operations.
- Support functionality.

### Backend and Data Layer

Firebase provides the backend services used by Gather.

Firebase Authentication handles user authentication, while Cloud Firestore stores and retrieves application data.

---

## Firebase and Database Structure

Gather uses Cloud Firestore as its cloud database.

The main Firestore root collections include:

| Collection     | Purpose                          |
| -------------- | -------------------------------- |
| `users`        | User accounts and personal data  |
| `restaurants`  | Restaurant information and menus |
| `sessions`     | Group ordering sessions          |
| `sessionCodes` | Group session joining codes      |
| `orders`       | Order information                |
| `tickets`      | Support-related information      |
| `stories`      | Food stories shared by users     |
| `meta`         | Application metadata             |

Additional data is organized through subcollections and documents.

User-related data includes:

- Cart information.
- Saved sessions.
- Payment methods.
- Notifications.
- AI conversations.
- Vouchers.

Restaurant documents contain menu information, while group sessions contain their related order lines.

Food stories are stored in the root-level `stories` collection in Firestore.

Firestore security rules are used to control access to application data and protect user-specific operations.

---

## AI Assistant Configuration

The Gemini API key is intentionally excluded from this public repository.

To enable Gemini integration, developers must configure their own API key.

Create a file named `config/secrets.json` in the project root:

```json
{
  "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY"
}
```

Replace `YOUR_GEMINI_API_KEY` with a valid API key.

Make sure the file is included in `.gitignore`:

```gitignore
config/secrets.json
```

Never commit API keys or private credentials to GitHub.

If no valid key is configured, the application can use its local rule-based assistant instead.

---

## Getting Started

### Prerequisites

Before running Gather, make sure you have:

- Flutter SDK installed.
- Dart SDK installed.
- Android Studio or Visual Studio Code.
- A configured Firebase project.
- Git installed.

### 1. Clone the Repository

```bash
git clone https://github.com/221511324/Gather-.git
```

### 2. Navigate to the Project Directory

```bash
cd Gather-
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Configure Firebase

Set up your Firebase project and configure the required Firebase application files.

### 5. Configure the Gemini API Key

Create `config/secrets.json` and add your Gemini API key as described in the AI Assistant Configuration section.

### 6. Run the Application

```bash
flutter run --dart-define-from-file=config/secrets.json
```

---

## Testing

Gather was developed and evaluated through multiple testing stages, including unit testing, integration testing, and system testing.

The final Sprint 3 testing report documents 60 test cases:

| Testing Type        | Number of Test Cases |
| ------------------- | -------------------: |
| Unit Testing        |                    3 |
| Integration Testing |                   35 |
| System Testing      |                   22 |
| **Total**           |               **60** |

All 60 test cases passed according to the final Sprint 3 testing report.

Testing covered application functionality, interactions between features, and overall application behavior.

---

## Project Structure

The project is organized into separate directories for application code, platform configurations, tests, and Firebase configuration.

```text
Gather/
│
├── android/
├── ios/
├── assets/
│
├── lib/
│   ├── core/
│   │   ├── providers/
│   │   └── services/
│   │
│   ├── features/
│   │
│   ├── main.dart
│   └── firebase_options.dart
│
├── test/
├── integration_test/
│
├── firebase.json
├── firestore.rules
├── pubspec.yaml
└── README.md
```

---

## Important Implementation Notes

- Gather is a Flutter application backed by Firebase.
- Group sessions use unique four-digit joining codes.
- Participants manage their own food selections within a shared group cart.
- The host has additional group-session permissions.
- The application supports Individual Payment, Equal Split, and Host Pays.
- Payment processing is simulated and does not involve real financial transactions.
- Order tracking is handled within the application without an external delivery provider API.
- Food stories are stored in the root-level Firestore `stories` collection.
- Gemini integration requires a developer-provided API key.
- The AI assistant has a local rule-based fallback when Gemini is unavailable.
- The application supports English and Arabic.

---

## Project Supervision

**Supervised by:**

Dr. Zainab Masood

## Prepared By

| Student Name | Student ID |
|---|---|
| Rama Alrashodi | 221410353 |
| Mashael Aljarbou | 221410453 |
| Reema Alnamazi | 221511324 |
| Dana Albassam | 221511449 |
| Tib Othman | 223511267 |

**Senior Graduation Project – Gather**

Prince Sultan University  
College of Computer and Information Sciences
