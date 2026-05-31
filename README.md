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

<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (3)" src="https://github.com/user-attachments/assets/536e53d4-89f5-4bfb-a72a-2d1a1356960d" />
<img width="1080" height="2400" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM" src="https://github.com/user-attachments/assets/8495b651-78b0-4455-86f9-fe23fb8d9b42" />
<img width="1080" height="2400" alt="WhatsApp Image 2026-05-17 at 1 40 22 PM" src="https://github.com/user-attachments/assets/41c8f44c-22b6-4da6-a6aa-b3c3673f31dc" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (1)" src="https://github.com/user-attachments/assets/7637875a-33f6-4159-b544-ed2e90146750" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 46 PM" src="https://github.com/user-attachments/assets/14e26342-a34c-4a35-96a5-6443723a2f91" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 45 PM (2)" src="https://github.com/user-attachments/assets/7cdb7cf9-b953-4d86-bb8e-68455bba9a61" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM" src="https://github.com/user-attachments/assets/63f8b5d5-2304-45a0-93c0-2e3e99da068e" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (1)" src="https://github.com/user-attachments/assets/45da2f7b-1772-4f6f-bc26-dbca2841c617" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM" src="https://github.com/user-attachments/assets/9e64ca75-bc1b-4124-a99b-c8002aa17a56" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM (1)" src="https://github.com/user-attachments/assets/31e70423-1c67-4f0c-8364-87cef94dc75c" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 44 PM (2)" src="https://github.com/user-attachments/assets/c7e62fad-8649-4e9a-943a-e020ae201b03" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (2)" src="https://github.com/user-attachments/assets/6c584818-be07-4a7b-9f1d-f705b834bdef" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 43 PM (3)" src="https://github.com/user-attachments/assets/7bd127c5-3869-422a-8e15-a51f586470b6" />
<img width="920" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 42 PM" src="https://github.com/user-attachments/assets/89b16ffc-faea-451e-a402-30b131c5d22c" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 42 PM (1)" src="https://github.com/user-attachments/assets/48efd8d6-6d05-4fe1-92e7-3dd776612b44" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM" src="https://github.com/user-attachments/assets/a86e3e7e-e20f-454d-abfe-6822e8bd6dc4" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (1)" src="https://github.com/user-attachments/assets/cd2214e1-13ac-4302-8116-e9d98f068f12" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (2)" src="https://github.com/user-attachments/assets/132b7c59-8e98-4120-afa6-a6d98d40d462" />
<img width="720" height="1600" alt="WhatsApp Image 2026-05-17 at 1 38 41 PM (3)" src="https://github.com/user-attachments/assets/400c09c6-ac9f-4ab6-a816-77f4672fe978" />

