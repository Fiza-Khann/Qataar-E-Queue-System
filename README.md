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

## Screenshots
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (2)" src="https://github.com/user-attachments/assets/0bef7f14-6b89-41b2-b465-11e6126fce52" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (3)" src="https://github.com/user-attachments/assets/9056bb5a-e379-478c-9b6a-33bf5e8141be" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (3)" src="https://github.com/user-attachments/assets/f5a247ea-16a1-45ca-89b2-ffe5e9a29c7c" />
<img width="1080" height="2400" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM" src="https://github.com/user-attachments/assets/dfdc6ceb-c54d-4109-af80-6ba3f34d5991" />
<img width="1080" height="2400" alt="WhatsApp Image 2026-05-17 at 1 40 22 PM" src="https://github.com/user-attachments/assets/fd18bcf1-7049-4d89-a074-54ea7ff6afb3" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (1)" src="https://github.com/user-attachments/assets/ac5ac29b-e95f-4a82-be47-716d8d087b13" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 46 PM" src="https://github.com/user-attachments/assets/33cb2856-9d92-4f7f-99a2-07515c8543a0" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (2)" src="https://github.com/user-attachments/assets/a4bcbd36-92c5-4efa-93e4-261242036f41" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM" src="https://github.com/user-attachments/assets/98b3ded0-e948-42c1-a019-e5e9fb8b344b" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (1)" src="https://github.com/user-attachments/assets/09578322-807e-4df6-ad8b-1962a2d7390a" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM" src="https://github.com/user-attachments/assets/2087f85a-3cbb-4139-864a-f513444215ee" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM (1)" src="https://github.com/user-attachments/assets/07fba4d6-c53d-4899-a987-dd2ef6cb8371" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM (2)" src="https://github.com/user-attachments/assets/e79cb503-d5ab-4304-be2b-231398fa4d0b" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (2)" src="https://github.com/user-attachments/assets/3737093a-f05b-4d5f-a515-fa6c289face4" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (3)" src="https://github.com/user-attachments/assets/574654c5-11da-4eef-bb98-81bc1d6b1caf" />
<img width="920" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 42 PM" src="https://github.com/user-attachments/assets/ecd335c3-8c20-4906-bd38-32e776191101" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 42 PM (1)" src="https://github.com/user-attachments/assets/44c56954-ce38-4613-bf5b-04734d4e763b" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM" src="https://github.com/user-attachments/assets/e20553fa-2b86-4f35-acd1-0fa3af20d718" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (1)" src="https://github.com/user-attachments/assets/0937c132-6a71-4d55-90c0-0702a55ac09f" />
