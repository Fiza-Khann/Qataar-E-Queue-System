# Qataar: SEL-448 Detailed Project Report (Mobile Application)

**Course:** SEL-448 Software Applications for Mobile Devices  
**Term:** Spring 2026  
**Class:** BSE-6 (C)

---

## 1. Table of Content
1. Table of Content
2. System architecture and design
3. Implementation details (code explanation)
4. Output screenshots
5. Challenges and solutions

---

## 2. System architecture and design

### 2.1 Overview
**Qataar** is a token-based queue management system that supports public and private services. It enables users to:
- Browse service categories and branches
- Select a service and book a token
- Receive real-time status updates through **Firebase Cloud Messaging (FCM)**
- View token details including estimated waiting time
- Scan a QR code at the branch to mark a token as **served**

Additionally, the system supports **grocery slot-based tokens**, including:
- Choosing preferred time slot and priority level
- Booking a grocery token (with capacity control)
- Receiving FCM notifications for “turn approaching” and “your turn”
- Auto-skipping/advancing queue when a serving token times out

### 2.2 High-level architecture
The application is composed of three main parts:

1. **Mobile Client (Flutter)**
   - Screens for login/signup, service browsing, token booking, grocery booking, dashboards, and QR scanning.
   - Firebase integration:
     - Firebase Authentication (Google Sign-In + email/password)
     - Firestore (data storage and live updates)
     - Firebase Messaging (push notifications)
   - Local notifications via `flutter_local_notifications`.

2. **Backend Server (Node.js / Express)**
   - Exposes REST endpoints used by the mobile app.
   - Sends FCM notifications.
   - Performs scheduled tasks using `node-cron`.
   - Sends email OTP for 2FA-like verification.

3. **Firebase Services (Firestore + FCM + Auth)**
   - Firestore stores:
     - users, categories, branches, services
     - token bookings and daily state
     - grocery stores/branches/counters/tokens and time slots
   - FCM delivers push notifications to devices.

---

### 2.3 Core data flow

#### A) Service token booking & notifications
1. **User books a service token**
   - Flutter collects:
     - `userId`, `serviceId`, `branchId`, `categoryId`, `fcmToken`, and location/service metadata
   - The booking is saved under the backend-controlled daily token structure.

2. **Backend `/bookings` endpoint** (in `server.js`)
   - Creates a token booking document in:
     - `tokens/{date}/bookings`
   - Automatically assigns **next token number** per service using the last token record.
   - Increments `dailyTokenCounter` in the service document.

3. **Backend sends “Booking Confirmed” FCM notification**
   - Message includes a notification title/body.

4. **Cron job notifies “Your Turn is Near!” and “It’s Your Turn!”**
   - Every minute, cron scans service definitions and checks the booking documents.
   - Rules:
     - “Approaching” when token is 2 away from `currentToken`.
     - “Your Turn” when booking token equals `currentToken + 1`.

#### B) Grocery token booking, queue updates & notifications
1. **User selects grocery preferences**
   - Flutter loads live time slots (capacity and booked count).
   - User enters approximate item count.
   - User selects a preferred slot and priority.

2. **Backend grocery notification endpoint**
   - Endpoint `/grocery/notify` is **notification-only**.
   - It validates slot capacity.
   - It ensures the backend stores/merges the user’s `fcmToken` into `users/{userId}`.
   - It sends FCM confirmation notification containing tokenNumber and computed queuePosition.

3. **Grocery cron job**
   - Every minute:
     - Determines current serving token for each active counter.
     - If none is serving, it promotes the first waiting token.
     - Sends “Your Turn is Near!” and “It’s Your Turn!” based on `tokensAhead`.

4. **Auto-skip missed serving tokens**
   - Runs every 30 seconds.
   - If a serving token has exceeded timeout (3 minutes), it:
     - Marks token as `missed`
     - Promotes next waiting token as `serving`
     - Sends FCM notifications to both affected and next user.

---

### 2.4 Design principles applied
- **Event-driven UI**: Flutter screens use `StreamBuilder` to react to Firestore snapshot updates.
- **Separation of concerns**:
  - UI screens in `lib/screens/*`
  - Networking logic in `lib/services/*`
  - QR-related logic in `lib/services/qr_service.dart`
  - Route/time estimation logic in `lib/services/route_service.dart`
- **Performance improvement**:
  - `HomeScreen` uses Firestore `collectionGroup('branches')` to avoid N+1 query patterns.
- **Robust asynchronous handling**:
  - UI loading states while waiting for documents.

---

## 3. Implementation details (code explanation)

### 3.1 App bootstrap and Firebase initialization (`lib/main.dart`)
Key responsibilities:
1. Initialize Flutter binding and Firebase (`Firebase.initializeApp()`).
2. Enable **Firestore offline persistence** using `Settings(persistenceEnabled: true)`.
   - Helps reduce network reads and improves UX.
3. Register a **Firebase Messaging background handler**.
4. Initialize **local notifications** via `initializeNotifications()`.
5. `MyApp` requests notification permission and prints the device FCM token.

### 3.2 Notification handling (`lib/services/notification_service.dart`)
Main features:
- Creates an Android notification channel (`qataar_channel`).
- Handles:
  - Background messages (`firebaseMessagingBackgroundHandler`)
  - Foreground messages (`FirebaseMessaging.onMessage.listen`)
- Displays local notifications using `flutterLocalNotificationsPlugin.show(...)`.

> Important design note: routing on notification tap is limited because navigation currently logs and does not fully route without a global navigator key.

### 3.3 Authentication and role routing

#### 3.3.1 Login (`lib/screens/login_screen.dart`)
- Supports:
  - Email/password login via Firebase Auth
  - Google Sign-In
- After authentication:
  - Fetches the user document from Firestore
  - Sends OTP using backend endpoint `sendEmailOtp`
  - Navigates to role-appropriate screens after OTP verification

Role-based routing includes:
- `admin` → Admin home page
- `user` → Category selection screen

#### 3.3.2 Signup (`lib/screens/signup_screen.dart`)
- Creates a Firebase Auth account.
- Stores a user profile document in Firestore with:
  - `name`, `email`, and role=`user`.

#### 3.3.3 Email OTP APIs (`lib/services/auth_service.dart`)
- `sendEmailOtp(userId, email)` calls:
  - `POST {API_BASE_URL}/sendEmailOtp`
- `verifyEmailOtp(userId, otp)` calls:
  - `POST {API_BASE_URL}/verifyEmailOtp`

### 3.4 Backend: REST API and scheduled jobs (`server.js`)
The Node.js server uses Express + Firebase Admin.

#### 3.4.1 `/bookings` endpoint
- Input includes `serviceId`, `branchId`, `categoryId`, `fcmToken`, and `city`.
- Creates a booking document under:
  - `tokens/{date}/bookings`
- Assigns `tokenNumber` by reading the latest token for the same service.
- Increments `dailyTokenCounter` in the service definition document.
- Sends FCM notification: “Booking Confirmed!”.

#### 3.4.2 `/sendNotification` endpoint
- Notification-only endpoint (no Firestore write).
- Used to trigger FCM sending based on token metadata.

#### 3.4.3 `/updateToken` endpoint
- Updates a service definition’s `currentToken`.
- Used by admin or operational flow to advance the queue.

#### 3.4.4 Grocery `/grocery/notify`
- Notification-only for grocery booking confirmations.
- Computes:
  - tokenNumber using today’s token count
  - queuePosition based on last in-order token with `queuePosition` ordering
  - priority based on `numberOfItems` threshold
- Validates capacity from `timeSlots/{slotId}`.
- Ensures user’s FCM token is stored in `users/{userId}`.

#### 3.4.5 Cron jobs
1. **Services cron** (every minute)
   - Iterates through categories → branches → services.
   - Queries bookings in `tokens/{date}/bookings`.
   - Sends notifications:
     - “Your Turn is Near!” at 2 tokens away.
     - “It’s Your Turn!” at `currentToken + 1`.

2. **Grocery cron** (every minute)
   - Iterates through stores → branches → counters.
   - Finds serving token (`status='serving'`) or promotes first waiting token.
   - For each waiting token:
     - Calculates `tokensAhead = queuePosition - currentServingPosition`.
     - Sends notifications using `tokensAhead` thresholds.

3. **Auto-skip cron** (`*/30 * * * * *`)
   - Finds overdue serving tokens and applies transaction logic to:
     - mark as `missed`
     - promote next waiting token
     - notify affected next user(s)

### 3.5 QR-based serving flow

#### 3.5.1 QR encoding and parsing (`lib/services/qr_service.dart`)
- Grocery QR data is encoded as JSON:
  - `{ type: 'grocery', storeId, branchId, docId, tokenNumber }`

#### 3.5.2 Mark token as served
- `markTokenServed(data)`:
  - Validates type=‘grocery’
  - Loads Firestore document at:
    - `stores/{storeId}/branches/{branchId}/tokens/{docId}`
  - Updates:
    - `status` to `served`
    - `endTime` to server timestamp
  - Also decrements `bookedCount` for the slot (if `slotId` exists).

#### 3.5.3 QR scanning UI (`lib/screens/qr_scanner_screen.dart`)
- Uses `MobileScanner`.
- On barcode detection:
  - Parse QR payload
  - Call `QrService.markTokenServed(...)`
  - Show SnackBar feedback

### 3.6 Grocery token UI (`lib/screens/grocery_token_screen.dart`)
Main design elements:
- Uses `StreamBuilder` to wait for token document existence.
- Displays tokenNumber, queuePosition, status, estimated wait, and time slot.
- Shows QR via `QrImageView` using `QrService.buildGroceryQrData(...)`.
- Provides “View Map” that uses geolocation + Mapbox route duration.

### 3.7 Route/time estimation (`lib/services/route_service.dart`)
- Calls Mapbox Directions API.
- Returns `duration_in_traffic` when available.
- Used by grocery token screen to estimate route time.

### 3.8 Performance decision in `HomeScreen` (`lib/screens/home_screen.dart`)
- Instead of querying categories then branches separately,
  - uses Firestore `collectionGroup('branches')`
- Reduces query overhead and improves load speed.

---

## 4. Output screenshots

> Screenshots must be inserted by you.

### 4.1 Recommended screenshot list (capture exactly these screens)
1. **Splash screen** (logo + transition)
2. **Login screen** (email/password UI + Google sign-in)
3. **Signup screen** (fields for name/email/password)
4. **OTP verification screen** (OTP input UI)
5. **Home / Branch browsing screen** (categories tabs + branch list)
6. **Service list screen** (select service within a branch)
7. **Grocery input screen**
   - item count
   - priority dropdown
   - preferred time slot dropdown
8. **Grocery suggested slots screen** (best slots based on availability)
9. **Grocery token screen**
   - token info card
   - estimated wait time
   - QR code
10. **QR scanner screen** (camera scanning overlay)
11. **Admin panel/home** (admin entry screen)
12. **Admin service/token dashboard** (current token control)

### 4.2 Screenshot placeholders (paste your images here)
Use the following format in your final submission:

- **Figure 1:** Splash Screen  
  *(Insert screenshot here)*

- **Figure 2:** Login Screen  
  *(Insert screenshot here)*

- **Figure 3:** Signup Screen  
  *(Insert screenshot here)*

- **Figure 4:** OTP Verify Screen  
  *(Insert screenshot here)*

- **Figure 5:** Home / Branch Browsing  
  *(Insert screenshot here)*

- **Figure 6:** Grocery Input Screen  
  *(Insert screenshot here)*

- **Figure 7:** Grocery Suggested Slots  
  *(Insert screenshot here)*

- **Figure 8:** Grocery Token + QR  
  *(Insert screenshot here)*

- **Figure 9:** QR Scanner Screen  
  *(Insert screenshot here)*

- **Figure 10:** Admin Dashboard  
  *(Insert screenshot here)*

---

## 5. Challenges and solutions

### Challenge 1: Reliable notification delivery and UI display
- **Problem:** FCM messages may arrive when the app is in foreground/background, and the UI must still show user-friendly notifications.
- **Solution:**
  - Implemented both:
    - Foreground listener (`FirebaseMessaging.onMessage.listen`)
    - Background handler (annotated with `@pragma('vm:entry-point')`)
  - Used `flutter_local_notifications` to show consistent local notifications.

### Challenge 2: Asynchronous Firestore document availability
- **Problem:** Some screens need to wait for token documents to exist right after booking.
- **Solution:**
  - Used `StreamBuilder<DocumentSnapshot>` to handle `snapshot.hasData` and `snapshot.data!.exists` conditions.
  - The UI shows a loading state (“Token is being prepared…”) until the doc exists.

### Challenge 3: Queue timing correctness (“turn approaching” logic)
- **Problem:** Cron-based notifications must match server-side `currentToken` / queue state.
- **Solution:**
  - Services cron:
    - checks bookings against `currentToken` using tokenNumber math.
  - Grocery cron:
    - computes `tokensAhead` based on `queuePosition` and `currentServingPosition`.
  - Auto-skip cron ensures the queue doesn’t stall.

### Challenge 4: Navigation issues after notification tap
- **Problem:** Notification tap routing needs a global navigator key; the current implementation mainly logs debug info.
- **Solution:**
  - Fallback approach: keep behavior functional (local notifications + logging).
  - Documented improvement need to support deep-link navigation.

### Challenge 5: Performance issues with Firestore querying
- **Problem:** Naively fetching branches through multiple queries can lead to N+1 query overhead.
- **Solution:**
  - In `HomeScreen`, used Firestore `collectionGroup('branches')` to fetch all branch documents in a single query.

### Challenge 6: Slot capacity enforcement for grocery tokens
- **Problem:** Prevent booking tokens beyond slot capacity.
- **Solution:**
  - Backend checks `timeSlots/{slotId}`:
    - compares `bookedCount` with `capacity`
  - Rejects booking when slot is full.

### Known improvement items (from project TODO)
- Update grocery suggested slots screen to StatefulWidget.
- Add mounted guards before navigation replacements.
- Run `flutter analyze` and `flutter test`.

---

*End of report.*

