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
<img width="1080" height="2400" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM" src="https://github.com/user-attachments/assets/c73ed3ef-cdf3-45be-902e-f03139ba35ff" /><img width="1080" height="2400" alt="WhatsApp Image 2026-05-17 at 1 40 22 PM" src="https://github.com/user-attachments/assets/8de3f81f-1938-482f-8bac-7b23428f43e0" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (1)" src="https://github.com/user-attachments/assets/5c7d5091-cf9c-4948-92ee-ee9013109267" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 46 PM" src="https://github.com/user-attachments/assets/bfbd73ec-65d3-4ac4-b866-54661f84ead5" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (2)" src="https://github.com/user-attachments/assets/29123999-9374-4d49-b3f9-8d06017d80d3" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM" src="https://github.com/user-attachments/assets/53fade26-bd51-4ac9-b180-88a2dadfe8fd" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (1)" src="https://github.com/user-attachments/assets/480f417a-9287-4063-98cb-13f817b761b6" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM" src="https://github.com/user-attachments/assets/8c8e2692-c7af-486c-8a51-1d86f6dbef33" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM (1)" src="https://github.com/user-attachments/assets/409af1d5-a4a0-4d9e-93bc-3d43e9b9683a" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM (2)" src="https://github.com/user-attachments/assets/dc253660-d4f3-4261-a4fa-40f597913acf" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (2)" src="https://github.com/user-attachments/assets/2c9a8c39-b6e8-4f3e-a93b-0c541121ed6f" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (3)" src="https://github.com/user-attachments/assets/846cd85d-1961-49ca-be58-4015f95108ee" />
<img width="920" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 42 PM" src="https://github.com/user-attachments/assets/123c1b0f-8541-4d2e-a94c-b57ea7e48530" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 42 PM (1)" src="https://github.com/user-attachments/assets/74168ed3-5500-475b-b484-ad562ef50df6" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM" src="https://github.com/user-attachments/assets/05b690f4-8a4d-414b-917c-45503db7d385" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (1)" src="https://github.com/user-attachments/assets/d0919b93-ea0f-49fd-a281-5a6330a386fc" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (2)" src="https://github.com/user-attachments/assets/f09b886d-c587-455b-8ac2-fb7dd6468e80" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (3)" src="https://github.com/user-attachments/assets/330b47c9-2340-41f3-983a-f1191a600fda" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (3)" src="https://github.com/user-attachments/assets/79a94466-08ee-4764-86cf-2c6808221be8" />


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
