# San3a

San3a is a cross-platform service marketplace built with Flutter and Firebase. It connects customers who need practical work done — plumbing, electrical, construction and similar trades — with the independent professionals and contracting companies who can do it, and gives an administrator the tools to moderate the whole marketplace.

The platform addresses a common problem in the local services market: finding a trustworthy provider usually depends on word of mouth, and once work is agreed there is no shared record of what was requested, what was agreed, or what was delivered. San3a puts discovery, ordering, communication, and feedback into a single application, with every stage recorded against the order.

---

## About San3a

A customer opens the app, browses service categories or providers, and submits a service request. That request reaches the chosen provider as an order, which the provider can accept, work on, and mark complete. Throughout the process both sides can exchange messages, share photographs, and receive in-app notifications. When the work is finished the customer can leave a rating and a written review.

Providers come in two forms. A **professional** is an individual tradesperson who handles their own orders. A **contractor** represents a company that maintains a roster of workers and assigns them to jobs. Both use the same ordering and messaging system, but the contractor experience adds workforce management on top.

An **admin** oversees the marketplace: managing users and orders, handling complaints, moderating reviews and conversations, curating service categories, and sending announcements.

---

## Main User Roles

The application defines four roles. Three of them — Customer, Professional and Contractor — can be chosen during registration. The Admin role is not self-registerable; it is assigned to existing accounts. After sign-in, the application routes each user to the home screen for their role.

### Customer

- Browse service categories and discover professionals and contractors
- View a provider's profile, services, and existing reviews
- Save providers to a favourites list
- Create a service request (order) against a provider, with an optional photo
- Track orders through their lifecycle and view order details
- Chat with providers, including image attachments and voice messages
- Submit and edit a review with per-criterion star ratings and a comment
- Raise complaints and request a new service category
- Manage a profile including languages, favourite services, and preferred contact hours
- Use the AI Service Assistant to turn a free-text problem description into a suggested category and request

### Professional

- View a dashboard of incoming and active orders
- Accept, complete, or reject/cancel orders, with a cancellation reason
- Open full order details, including the customer's information and attached photos
- Chat with customers
- Maintain a profile: services offered, specialties, work area, working days, and working hours
- View received reviews and ratings
- Receive in-app notifications for orders, messages, and reviews
- Raise complaints
- Use the Professional AI Assistant to prepare for a specific job

### Contractor

- View a dashboard of orders and schedules
- Accept and complete orders, or reject/cancel them with a reason
- Assign one or more workers to an order and unassign them again
- Manage a roster of workers and suppliers — add, edit, and remove entries with specialties and availability status
- Chat with customers
- Maintain a company profile, specialties, working days and hours
- Receive in-app notifications
- Use the Contractor AI Crew & Order Planner to plan staffing for a job

### Admin

- Review platform statistics on a dashboard
- Manage users: view details, edit profile fields, and apply account actions
- Manage orders across the platform: view, edit, approve, complete, cancel, and reassign contractor workers
- Handle the Complaints Center
- Moderate reviews: hide, unhide, soft-delete, mark safe, or edit a comment
- Manage chats: view conversations, block and unblock them, handle user help requests, and maintain Quick Replies
- Manage service categories and category requests submitted by customers
- Send broadcast messages to one or more audiences
- Configure the review criteria used by the rating form

---

## Key Features

**Authentication.** Email and password sign-up and sign-in through Firebase Authentication. Registration asks for the account type (Customer, Professional, or Contractor) along with role-specific details. A profile document is created in Cloud Firestore on registration.

**Role-based experience.** After sign-in the application inspects the stored role and presents a completely different home screen, navigation bar, and feature set for each role. An access gate blocks accounts that have been suspended or deleted.

**User profiles.** Each role has an editable profile. Customers manage contact details, languages, favourite services, and preferred contact hours. Providers additionally manage services, specialties, work area, working days, and working hours. Profile photographs can be uploaded, changed, or removed.

**Service discovery.** Customers browse a category grid, open a category to see its providers, search, and open a full provider profile showing services, ratings, and reviews. Providers can be saved to favourites.

**Orders.** A customer creates an order against a provider, choosing services, a service date, an area, a priority, and optionally attaching a photo. Orders move through four statuses: `pending`, `inProgress`, `completed`, and `cancelled`. Both sides see the same order, and the actions available depend on the viewer's role.

**Order photos.** Photos can be attached when an order is created and added, replaced, or appended afterwards. Images are stored in Firebase Storage and referenced from the order.

**Chat and messaging.** One-to-one conversations between customers and providers, with unread counts, read receipts, message editing and deletion, blocking, image attachments, voice messages, and emoji input. Admins can send warning messages into a conversation.

**Camera and gallery.** Every photo entry point — chat attachments, profile photos, order creation, and order photo management — offers a choice between taking a new photo with the device camera and choosing an existing one from the gallery.

**Notifications.** An in-app notification centre per role, backed by Cloud Firestore. Notifications are generated for order updates, new reviews, complaints, category requests, and admin broadcasts. Users can open a notification to jump to the related item and can mark all as read. Read and hidden state is stored per user.

**Reviews and ratings.** Customers rate a provider against admin-configurable criteria and leave a written comment. Reviews can be edited by their author, reported by the reviewed provider, and moderated by an admin. A provider's displayed rating is derived from their visible reviews.

**Preferred contact hours.** Customers can state when they prefer to be contacted — Morning, Afternoon, Evening, Night, or Any Time. "Any Time" is mutually exclusive with the specific periods.

**Complaints.** Customers, professionals, and contractors can raise complaints about an order, a provider, a review, or a general issue. Admins triage them in the Complaints Center.

**Category requests.** Customers can request a service category that does not exist yet; admins approve or reject the request.

**Admin broadcasts.** Admins compose a message and select one or more target audiences — All Users, Customers, Professionals, Contractors — and the message is delivered as a notification to everyone in the selected audiences, without duplicates.

**Quick Replies.** A shared library of short canned messages that admins create, edit, delete, and search. Users can insert a quick reply into the message box from the chat screen.

**Help Centre.** A browsable set of help articles available in the application.

**On-demand translation.** Individual chat messages, provider "About" text, service descriptions, reviews, and help articles can be translated on demand into Arabic, Hebrew, or English. The original text is never replaced; the translation appears alongside it.

---

## AI Features

San3a includes four AI-backed capabilities. All of them run through Google Gemini inside Firebase Cloud Functions — the model is never called from the device, and the API key is held as a Firebase secret rather than shipped in the application. Every callable verifies the caller's Firebase Authentication session and role before doing any work, and the AI's response is validated against a fixed, versioned schema on the server before it is returned to the app.

### AI Service Assistant — Customers

Available to customers from the home feed. The customer describes their problem in their own words, in free text. The assistant identifies the language, suggests a real service category from the platform's catalogue, proposes whether a professional or a contractor is more appropriate, drafts a request title and description, suggests a priority, explains why that category was chosen, and may ask short follow-up questions to refine the result. The customer can then use the suggestion to start a service request.

### Professional AI Assistant — Professionals

Available to professionals from their dashboard. Given one of the professional's own orders, it produces a job briefing: a summary, questions worth asking the customer, a tools and materials list, suggested steps, safety warnings, and a draft message to send to the customer.

### Contractor AI Crew & Order Planner — Contractors

Available to contractors from their dashboard. Given one of the contractor's own orders and their worker roster, it produces a staffing plan: a summary, a recommended worker count, crew guidance, questions for the customer, tools and materials, suggested steps, coordination notes, safety warnings, a draft customer message, and a ranked view of the contractor's workers. Worker ranking is computed on the server from real data — specialty match, current workload, availability status, and schedule proximity — rather than being invented by the model.

### Translation Assistant — All roles

Backs the on-demand translation described above, for chat messages and for provider and help content, into Arabic, Hebrew, or English.

Usage is rate-limited server-side, with per-user and platform-wide daily caps and a cooldown between requests, tracked in Cloud Firestore.

---

## Technology Stack

**Application**

- Flutter (Dart SDK `>=3.0.0 <4.0.0`)
- Riverpod (`flutter_riverpod`) for state management
- `intl` and `flutter_localizations` for formatting

**Firebase**

- Firebase Authentication (`firebase_auth`) — email/password sign-in
- Cloud Firestore (`cloud_firestore`) — application data
- Firebase Storage (`firebase_storage`) — profile photos, order photos, chat media
- Cloud Functions (`cloud_functions`) — callable functions, including all AI features
- Firebase Core (`firebase_core`)

**Cloud Functions (`functions/`)**

- TypeScript on Node.js 22
- `firebase-functions` (2nd generation) and `firebase-admin`
- `@google/genai` — Google Gemini client
- ESLint for linting

**Notable Flutter packages**

- `image_picker` — camera and gallery
- `record` and `just_audio` — voice messages
- `cached_network_image` — remote image loading
- `flutter_rating_bar` — star ratings
- `emoji_picker_flutter` — emoji input
- `geolocator` and `geocoding` — location and address lookup
- `permission_handler` — runtime permissions
- `url_launcher` — external links, maps, and phone calls
- `shared_preferences` — local persistence
- `path_provider`, `collection`, `badges`, `google_fonts`, `http`

**Security rules**

- `firestore.rules` and `storage.rules` define role-based authorization
- `rules_tests/` — a standalone Node.js and Mocha suite that exercises those rules against the Firebase emulators

> Note: push notifications via Firebase Cloud Messaging are **not** part of this project. Notifications are delivered in-app through Cloud Firestore.

---

## Project Architecture

The Flutter application uses a feature-based structure under `lib/`.

- **`lib/core`** — cross-cutting foundations: the application theme (`core/theme`) and a hand-written localization layer (`core/localization`). The interface itself is English-only; the translation feature described above is a separate, on-demand capability.
- **`lib/features`** — one directory per role or capability: `auth`, `customer`, `professional`, `contractor`, `admin`, `help`, plus the AI features `ai_service_assistant`, `professional_ai_assistant`, `contractor_ai_planner`, and `translation`. Feature directories follow a `presentation/{providers,screens,widgets}` layout; the AI features add `data/` for their repository and `models/` for their result types.
- **`lib/shared`** — code used by more than one role: the domain models (`shared/models/models.dart`), reusable widgets, helper utilities, and shared screens.

**State management.** The application uses Riverpod throughout. Most application-wide providers — authentication state, orders, conversations, notifications, reviews, categories, and the Firestore read/write helpers behind them — are declared in `lib/features/auth/presentation/providers/app_providers.dart`, which acts as the central state layer. Role-specific and AI feature providers live inside their own feature directories.

**Navigation.** Navigation is handled with Flutter's built-in `Navigator` and `MaterialPageRoute`. `main.dart` selects the home screen from the signed-in user's role and wraps it in an access gate.

**Backend logic.** Business rules that must not be trusted to the client — AI prompting and response validation, rate limiting, and role checks for AI features — live in `functions/src/`. Data authorization is enforced by `firestore.rules` and `storage.rules`.

---

## Project Structure

```
san3a/
├── lib/
│   ├── core/
│   │   ├── localization/          # AppLocalizations
│   │   └── theme/                 # AppTheme, chat theme
│   ├── features/
│   │   ├── auth/                  # sign-in, registration, app-wide providers
│   │   ├── customer/              # customer screens and theme
│   │   ├── professional/          # professional screens and theme
│   │   ├── contractor/            # contractor screens and theme
│   │   ├── admin/                 # admin screens and providers
│   │   ├── help/                  # help centre
│   │   ├── ai_service_assistant/  # customer AI
│   │   ├── professional_ai_assistant/
│   │   ├── contractor_ai_planner/
│   │   └── translation/           # on-demand translation
│   ├── shared/
│   │   ├── models/                # domain models
│   │   ├── widgets/               # shared widgets
│   │   ├── helpers/               # shared utilities
│   │   └── screens/
│   ├── firebase_options.dart
│   └── main.dart
├── functions/                     # Cloud Functions (TypeScript)
│   └── src/
├── rules_tests/                   # security-rules test suite
├── test/                          # Flutter unit and widget tests
├── android/  ios/  web/  windows/  linux/  macos/
├── firestore.rules
├── storage.rules
├── firebase.json
└── pubspec.yaml
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** with a Dart SDK in the range `>=3.0.0 <4.0.0`
- **Android Studio** or **Visual Studio Code** with the Flutter and Dart plugins
- **Android SDK** and either an Android emulator or a physical Android device with USB debugging enabled
- **Java 17** — the Android build is configured for Java 17
- A **Firebase project**, because the application cannot start without one (see [Firebase Setup](#firebase-setup))

Optional, only if you intend to work on the backend or the security rules:

- **Node.js 22** and the **Firebase CLI**, for Cloud Functions and the rules test suite

### Installation

```bash
git clone https://github.com/wmz05/san3a.git
cd san3a
flutter pub get
```

### Running the Application

Connect a physical Android device or start an emulator, then:

```bash
flutter run
```

To select a device explicitly when more than one is connected:

```bash
flutter devices
flutter run -d <device-id>
```

The default entry point is `lib/main.dart`, so `flutter run` and `flutter run -t lib/main.dart` are equivalent.

---

## Firebase Setup

The application reads its Firebase configuration from `lib/firebase_options.dart` and, on Android, from `android/app/google-services.json`. To run the project against your own Firebase project:

1. Create a Firebase project in the Firebase console.
2. Enable **Authentication** with the Email/Password provider.
3. Enable **Cloud Firestore** and **Firebase Storage**.
4. Register an Android application using your own application ID and download its `google-services.json` into `android/app/`.
5. Regenerate the Dart configuration with the FlutterFire CLI:

   ```bash
   flutterfire configure --project=<your-firebase-project-id>
   ```

6. Deploy the security rules:

   ```bash
   firebase deploy --only firestore:rules,storage:rules
   ```

7. To use the AI features, deploy the Cloud Functions and provide a Gemini API key as a Firebase secret. The key is **never** stored in this repository:

   ```bash
   firebase functions:secrets:set GEMINI_API_KEY
   firebase deploy --only functions
   ```

> **Security note:** no API keys, passwords, service-account files, private keys, or tokens are included in this documentation, and none should be committed to the repository. Replace every `<placeholder>` above with your own values, and keep credential files out of version control.

The application also works against the Firebase emulator suite; ports are declared in `firebase.json`.

---

## Testing and Quality Checks

Static analysis, using the `flutter_lints` rule set configured in `analysis_options.yaml`:

```bash
flutter analyze
```

Flutter unit and widget tests:

```bash
flutter test
flutter test test/preferred_contact_hours_test.dart   # a single file
```

Android debug build:

```bash
flutter build apk --debug
```

Cloud Functions linting and compilation:

```bash
npm --prefix functions run lint
npm --prefix functions run build
```

Firestore and Storage security-rules tests. These require the Firebase emulators and the Firebase CLI, and the dependencies in `rules_tests/` must be installed first:

```bash
npm --prefix rules_tests install
firebase emulators:exec --only firestore "npm --prefix rules_tests test"
firebase emulators:exec --only storage "npm --prefix rules_tests run test:storage"
```

---

## Supported Platforms

The repository contains platform folders for Android, iOS, Web, Windows, Linux, and macOS. Development and verification for this project targeted **Android**, which is the platform the application has been built and tested against. The remaining platform folders are present but have not been validated as part of this work.

---

## Academic Project

San3a was developed as a university software engineering project. It is intended for academic assessment and demonstration, and is not a commercially deployed product.

---

## Contributors

Project Team:

- Yanal Odeh
- Walid Zoubi

---

## License

No public license has been specified for this repository. All rights are reserved by the project team unless a license file is added.

