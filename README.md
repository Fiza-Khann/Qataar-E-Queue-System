# Qataar (E-Queue System)

Qataar is a cross-platform, token-based queue management system designed to streamline physical waiting lines for both public services (banks, driving license centers) and retail grocery stores. Built using Flutter, Node.js, and Firebase, the system features real-time queue synchronization, automated push notifications, and QR-based verification.

---

## 🚀 Core Features

### 🏢 Public & Private Service Centers
* **Browse & Book:** Users can search through service categories, select distinct branches, and book entry tokens instantly[cite: 1].
* **Live Estimations:** Displays real-time token progression and calculated routing durations utilizing the Mapbox Directions API[cite: 1].
* **Cron-Driven Alerts:** Automated notifications ping users when their "Turn is Near" (2 tokens away) or when "It's Your Turn"[cite: 1].

### 🛒 Grocery Slot Management
* **Capacity Control:** Users can select preferred shopping windows governed by a server-side slot capacity enforcement mechanism[cite: 1].
* **Priority Queuing:** Leverages a custom priority matrix calculated from the user's approximate grocery item count[cite: 1].
* **Auto-Skip Automation:** A background cron job automatically skips and marks a token as "missed" if a user fails to show up within 3 minutes of being called[cite: 1].

### 🔒 Admin & Verification Workflow
* **QR Check-Ins:** Administrators scan customer-generated QR codes directly within the application to mark tokens as served and release counter capacity[cite: 1].
* **Secure Auth:** Implements Firebase Authentication (Email/Password & Google Sign-In) bolstered by a custom Node.js backend email OTP layer[cite: 1].

---

## 🏗️ System Architecture

The ecosystem relies heavily on decoupled, asynchronous communication divided across three distinct layers[cite: 1]:

1. **Mobile Client (Flutter):** Employs an event-driven UI utilizing `StreamBuilder` to listen for reactive Firestore snapshot mutations[cite: 1]. Leverages a optimized `collectionGroup('branches')` structure to completely eliminate N+1 database querying overhead[cite: 1].
2. **Backend Server (Node.js & Express):** Exposes core REST APIs handling token bookings, slot validations, and transactional database routines[cite: 1]. Employs `node-cron` to execute parallel queue-checking tasks every minute[cite: 1].
3. **Firebase Infrastructure:** Central hub storing relational data schemas (`users`, `tokens`, `timeSlots`), dealing real-time push payloads through Firebase Cloud Messaging (FCM), and tracking secure sessions[cite: 1].

---

## 🛠️ Tech Stack & Libraries

### Frontend (Mobile App)
* **Framework:** Flutter (Dart)[cite: 1]
* **State & Live Sync:** Cloud Firestore (`StreamBuilder`)[cite: 1]
* **Push Notifications:** `firebase_messaging` + `flutter_local_notifications`[cite: 1]
* **Hardware & Mapping:** `mobile_scanner` (QR engine), `qr_flutter`, Mapbox Directions API[cite: 1]

### Backend & Cloud
* **Runtime Environments:** Node.js, Express[cite: 1]
* **SDK:** Firebase Admin SDK[cite: 1]
* **Automation:** `node-cron`[cite: 1]

---

## 📁 Repository Structure

```text
├── qataar/              # Flutter Cross-Platform Application
│   ├── lib/
│   │   ├── main.dart           # App bootstrap, Firebase & background handler init
│   │   ├── screens/            # UI components (auth, grocery dashboards, QR reader)
│   │   └── services/           # Network abstraction, Mapbox routing, notification logic
│   └── pubspec.yaml            # Dart dependencies configuration
│
└── FCM_backend/             # Node.js REST API & Automation Server
    ├── server.js               # Entry point, routing definitions, database endpoints
    ├── package.json            # Node environment dependencies
    └── Configs/                # Firebase admin service account configuration tokens
---

<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (3)" src="https://github.com/user-attachments/assets/eff3777e-934e-4e53-af3b-536a49b2158b" />
