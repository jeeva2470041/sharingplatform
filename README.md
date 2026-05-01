<h1 align="center">🔄 Campus Sharing Platform</h1>

<p align="center">
  <b>A cross-platform Flutter application for secure, trust-based item lending and borrowing within campus communities.</b>
</p>

<p align="center">
  <!-- Language & Framework -->
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <!-- Backend / DB -->
  <img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Node.js-Socket.IO%20Server-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js"/>
  <!-- AI APIs -->
  <img src="https://img.shields.io/badge/Groq%20API-LLaMA%203.3%2070B-FF6F00?style=for-the-badge&logo=openai&logoColor=white" alt="Groq API"/>
  <img src="https://img.shields.io/badge/Google%20Gemini-AI%20Chat-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Gemini"/>
  <!-- Auth -->
  <img src="https://img.shields.io/badge/Google%20Sign--In-OAuth2-EA4335?style=for-the-badge&logo=google&logoColor=white" alt="Google Sign-In"/>
  <img src="https://img.shields.io/badge/Apple%20Sign--In-OAuth2-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Apple Sign-In"/>
  <!-- Build / Deploy -->
  <img src="https://img.shields.io/badge/Firebase%20Hosting-Deployed-FFA000?style=for-the-badge&logo=firebase&logoColor=white" alt="Firebase Hosting"/>
  <!-- License -->
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License"/>
</p>

---

## 📌 Problem Statement / Objective

Campus communities commonly face a recurring logistical challenge: students and staff own items that sit idle while others need them temporarily — lab equipment, sports gear, tools, textbooks, and more. Existing solutions (WhatsApp groups, noticeboards) lack trust mechanisms, structured workflows, and accountability.

**Campus Sharing Platform** solves this by providing:
- A structured **lend/borrow marketplace** backed by Firebase Firestore
- A **deposit-based wallet system** to enforce accountability
- **QR-code handover verification** to confirm physical item transfers
- **AI-powered assistants** (Groq LLaMA 3.3 70B, Google Gemini) for user support
- A **trust scoring and rating system** to build community reputation

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔐 Multi-Provider Auth | Email/Password, Google Sign-In, Apple Sign-In via Firebase Auth |
| 🛒 Item Marketplace | Post, browse, and request items with image upload to Firebase Storage |
| 📋 Multi-Request Queue | Up to 5 simultaneous borrowing requests per item with FIFO approval |
| 📦 QR Code Handover | Lender generates a QR code; borrower scans to confirm physical transfer |
| 💰 Deposit Wallet | Deposits are locked on request and released/forfeited on return/damage |
| 💬 Real-Time Chat | Item-scoped chat using Cloud Firestore streams + Socket.IO relay server |
| 🤖 AI Assistants | Groq (LLaMA 3.3 70B) and Google Gemini chat assistants built in |
| ⭐ Trust Score System | Post-transaction ratings build a lender/borrower reputation score |
| 🧾 Transaction Lifecycle | Full state machine: Requested → Approved → QR Handover → Active → Returned / Settled |
| 🗑️ Soft Delete & Audit | Items support soft deletion with `isDeleted` flag and `deletedAt` timestamp |
| 🔒 Firestore Security Rules | Role-scoped read/write rules for items, chats, transactions, profiles, and ratings |
| 🌐 Cross-Platform | Android, iOS, Web, Windows, Linux, macOS from a single Dart codebase |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend Framework** | Flutter 3.x (Dart) |
| **UI Design System** | Material Design 3 |
| **Authentication** | Firebase Auth — Email/Password, Google OAuth2, Apple OAuth2 |
| **Database** | Cloud Firestore (NoSQL, real-time streams) |
| **File Storage** | Firebase Storage (item images) |
| **Real-Time Messaging** | Cloud Firestore streams + Socket.IO v4 relay (Node.js / Express) |
| **AI / LLM** | Groq API (llama-3.3-70b-versatile), Google Gemini |
| **QR Code** | `qr_flutter` (generation) + `mobile_scanner` (scanning) |
| **HTTP Client** | `http` package + `flutter_dotenv` for environment configuration |
| **Cryptography** | `crypto` (SHA-256 nonce for Apple Sign-In) |
| **State Management** | Flutter `StreamBuilder` + `setState` (reactive Firestore streams) |
| **Deployment** | Firebase Hosting (web), flutter build (native platforms) |
| **Platform Targets** | Android · iOS · Web · Windows · Linux · macOS |

---

## 🏗️ System Architecture / Workflow

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Client App                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │  Auth    │ │Marketplace│ │  Chat   │ │   AI Chat │  │
│  │ Screen  │ │  Screen  │ │ Screen  │ │  (Groq /  │  │
│  │(Firebase│ │(Firestore│ │(Firestore│ │  Gemini)  │  │
│  │  Auth)  │ │ Streams) │ │+Socket) │ │           │  │
│  └────┬─────┘ └────┬─────┘ └────┬────┘ └─────┬─────┘  │
│       │             │             │             │        │
│  ┌────▼─────────────▼─────────────▼─────────────▼────┐  │
│  │          Service Layer (Dart)                     │  │
│  │  AuthService · ItemService · TransactionService  │  │
│  │  RatingService · ProfileService · GrokService    │  │
│  └────┬─────────────────────────────────────────────┘  │
└───────┼─────────────────────────────────────────────────┘
        │
        ├──► Firebase Auth  (Identity)
        ├──► Cloud Firestore (Items, Chats, Transactions,
        │                     Profiles, Ratings, Requests)
        ├──► Firebase Storage (Item Images)
        ├──► Socket.IO Server (Node.js/Express — real-time relay)
        └──► Groq API / Gemini API (AI Assistants)
```

### Lending Workflow

```
Borrower requests item
        │
        ▼
Lender approves request ──► Deposit locked in borrower's wallet
        │
        ▼
Lender generates QR code ──► Borrower scans QR ──► Physical handover confirmed
        │
        ▼
Item marked ACTIVE ──► Borrower uses item
        │
        ├──► Normal Return ──► Deposit refunded to balance
        └──► Damaged / Kept ──► Deposit transferred to lender (settled)
                                        │
                                        ▼
                              Post-transaction rating submitted
```

---

## ⚙️ Installation & Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.9.2
- [Dart SDK](https://dart.dev/get-dart) ≥ 3.x (bundled with Flutter)
- [Node.js](https://nodejs.org/) ≥ 18 (for the Socket.IO server)
- A [Firebase project](https://console.firebase.google.com/) with Auth, Firestore, and Storage enabled
- (Optional) [Groq API key](https://console.groq.com/) for the AI assistant

### 1. Clone the Repository

```bash
git clone https://github.com/jeeva2470041/sharingplatform.git
cd sharingplatform
```

### 2. Configure Firebase

```bash
# Install the FlutterFire CLI
dart pub global activate flutterfire_cli

# Link to your Firebase project
flutterfire configure --project=<your-firebase-project-id>
```

This generates `lib/firebase_options.dart` automatically.

Enable the following in your Firebase Console:
- **Authentication** → Email/Password, Google, Apple
- **Cloud Firestore** → Start in production mode, then apply `firestore.rules`
- **Storage** → Apply `storage.rules`

### 3. Set Environment Variables

Create a `.env` file in the project root:

```env
GROK_API_KEY=your_groq_api_key_here
```

> ⚠️ **Never commit `.env` to version control.** It is listed in `.gitignore`.

### 4. Install Flutter Dependencies

```bash
flutter pub get
```

### 5. Start the Socket.IO Server (optional — for real-time chat relay)

```bash
cd server
npm install
npm start
```

The server runs on `http://localhost:3000` by default.

### 6. Run the Application

```bash
# Mobile / Desktop
flutter run

# Web
flutter run -d chrome

# Build for production (Android)
flutter build apk --release
```

---

## 🚀 Usage

| Action | Steps |
|---|---|
| **Register / Login** | Launch app → Register with email or sign in via Google/Apple |
| **Post an Item** | Dashboard → "Post Item" → Enter name, category, deposit amount, upload photos |
| **Browse & Request** | Marketplace tab → Browse listings → Tap "Request" → Deposit is locked |
| **Approve / Reject Request** | Dashboard → Pending Requests → Approve or reject borrower |
| **Handover via QR** | Lender: Transactions tab → "Generate QR" → Show to borrower · Borrower: "Scan QR" |
| **Return Item** | Transactions → Mark as Returned → Deposit refunded |
| **AI Assistant** | Chat tab → Select Groq or Gemini assistant → Ask any question |
| **Rate a User** | After transaction completion → Rate as Lender or Borrower (1–5 stars) |

---

## 📸 Screenshots or Demo

> Screenshots will be added as the UI stabilizes. The app supports Android, iOS, and Web layouts.

| Screen | Description |
|---|---|
| Login / Register | Multi-provider auth with SSN college branding |
| Dashboard | Overview of posted items, active borrows, wallet balance |
| Marketplace | Card-based item grid with status badges and deposit info |
| QR Handover | Full-screen QR display (lender) and camera scanner (borrower) |
| AI Chat | Conversational interface with Groq LLaMA 3.3 70B or Gemini |
| Profile & Trust Score | User bio, lending history, aggregated rating |

---

## 🔌 API Integration

### Firebase Services

| Service | Usage |
|---|---|
| `firebase_auth` | Email/Password, Google OAuth2, Apple OAuth2 sign-in |
| `cloud_firestore` | Real-time NoSQL database for all domain data |
| `firebase_storage` | Item image upload and CDN delivery |

### Groq API (LLM)

- **Endpoint**: `https://api.groq.com/openai/v1/chat/completions`
- **Model**: `llama-3.3-70b-versatile`
- **Auth**: Bearer token via `GROK_API_KEY` env variable
- **Web proxy**: Requests are routed through the local Node.js server (`/api/groq/chat`) to avoid CORS issues on web builds

### Socket.IO Server

- **Stack**: Node.js + Express + Socket.IO v4 + CORS
- **Events**: `joinRoom`, `sendMessage`, `receiveMessage`
- **Purpose**: Real-time message relay for item-scoped chat rooms

### QR Code

- **Generation**: `qr_flutter` — encodes transaction ID as QR payload
- **Scanning**: `mobile_scanner` — decodes QR and verifies transaction ownership before confirming handover

---

## 📁 Folder Structure

```
sharingplatform/
├── lib/
│   ├── main.dart                  # App entry point, Firebase + env init
│   ├── app_theme.dart             # Global Material theme
│   ├── firebase_options.dart      # FlutterFire generated config
│   ├── login_screen.dart          # Multi-provider login UI
│   ├── register_screen.dart       # User registration
│   ├── dashboard_screen.dart      # Central hub: posted items, active loans
│   ├── marketplace_screen.dart    # Browse and request available items
│   ├── post_item_screen.dart      # Form for listing a new item
│   ├── profile_screen.dart        # User profile, ratings, history
│   ├── chat_screen.dart           # Item-scoped real-time chat
│   ├── qr_handover_screen.dart    # QR generation & scanning for handover
│   ├── return_qr_screen.dart      # QR scanning for return verification
│   ├── transactions_screen.dart   # Full transaction lifecycle view
│   ├── gemini_chat_screen.dart    # Google Gemini AI assistant
│   ├── grok_chat_screen.dart      # Groq LLaMA AI assistant
│   ├── models/                    # Domain data models
│   │   ├── item.dart              # Item entity with status state machine
│   │   ├── item_request.dart      # Multi-request queue model
│   │   ├── message.dart           # Chat message model
│   │   ├── transaction.dart       # Lending transaction lifecycle
│   │   ├── user.dart              # Firebase user wrapper
│   │   ├── user_profile.dart      # Extended profile (bio, avatar)
│   │   ├── user_rating.dart       # Per-transaction rating record
│   │   └── user_wallet.dart       # Deposit wallet (balance + locked)
│   ├── services/                  # Business logic & Firebase wrappers
│   │   ├── auth_service.dart      # Multi-provider authentication
│   │   ├── item_service.dart      # CRUD + streams for items
│   │   ├── item_request_service.dart  # Request queue management
│   │   ├── transaction_service.dart   # Transaction + wallet sync
│   │   ├── rating_service.dart    # Trust score aggregation
│   │   ├── profile_service.dart   # User profile CRUD
│   │   ├── socket_service.dart    # Socket.IO client wrapper
│   │   └── grok_service.dart      # Groq LLM API client
│   ├── widgets/                   # Reusable UI components
│   │   ├── qr_scanner_dialog.dart
│   │   ├── rating_dialog.dart
│   │   ├── status_badge.dart
│   │   ├── notification_dropdown.dart
│   │   ├── profile_guard.dart
│   │   └── user_profile_info_dialog.dart
│   ├── data/
│   │   └── mock_data.dart         # Local wallet + seed data
│   └── constants/
│       └── assistant_prompts.dart # LLM system prompts
├── server/
│   ├── index.js                   # Socket.IO + Express server
│   └── package.json
├── assets/
│   └── ssn_college.jpg
├── firestore.rules                # Firestore security rules
├── storage.rules                  # Storage security rules
├── firebase.json                  # Firebase project config
├── pubspec.yaml                   # Flutter dependencies
└── .env                           # Environment variables (not committed)
```

---

## 🔮 Future Enhancements / Roadmap

- [ ] **Push Notifications** — FCM alerts for request approvals, chat messages, and due dates
- [ ] **Item Categories & Search** — Full-text search with category and availability filters
- [ ] **Return Due Dates** — Configurable lending periods with automated reminder notifications
- [ ] **Admin Dashboard** — Dispute resolution, item moderation, and analytics panel
- [ ] **Offline Support** — Firestore offline persistence for low-connectivity environments
- [ ] **Multi-Campus Federation** — Extend platform to multiple institutions with campus-scoped data isolation
- [ ] **In-App Payments** — UPI / Razorpay integration for real monetary deposit handling
- [ ] **Item Condition Photos** — Pre- and post-lending photo comparison to streamline damage assessment
- [ ] **Gamification** — Badges and leaderboards to incentivize active participation
- [ ] **Web PWA Optimization** — Service worker and responsive layout improvements for progressive web app

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Commit** your changes with clear messages: `git commit -m "feat: add return due dates"`
4. **Push** to your fork: `git push origin feature/your-feature-name`
5. **Open a Pull Request** describing the motivation and changes

### Code Guidelines

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` and fix all warnings before submitting
- Add/update tests under `test/` for any new business logic
- Keep services decoupled from UI — all Firestore and API calls belong in `lib/services/`

---

## 📄 License

This project is licensed under the **MIT License**.  
See the [LICENSE](LICENSE) file for details, or visit [opensource.org/licenses/MIT](https://opensource.org/licenses/MIT).

---

## 👤 Author / Contact

**Jeeva** — Developer & Maintainer

| Channel | Link |
|---|---|
| GitHub | [@jeeva2470041](https://github.com/jeeva2470041) |
| Repository | [jeeva2470041/sharingplatform](https://github.com/jeeva2470041/sharingplatform) |

> Built as a production-oriented prototype for campus resource sharing, demonstrating full-stack mobile development with Firebase BaaS, real-time messaging, AI integration, and secure QR-based item handover workflows.
