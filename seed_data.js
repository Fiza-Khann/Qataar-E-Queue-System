const fs = require('fs');
const path = require('path');

// ─────────────────────────────────────────
// CONFIGURATION
// ─────────────────────────────────────────

// Look for any service account JSON in the project root
const jsonFiles = fs.readdirSync(__dirname).filter(f => f.endsWith('.json') && f.includes('firebase'));
const serviceAccountPath = jsonFiles.length > 0
  ? path.join(__dirname, jsonFiles[0])
  : process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? process.env.GOOGLE_APPLICATION_CREDENTIALS
    : null;

if (!serviceAccountPath || !fs.existsSync(serviceAccountPath)) {
  console.error(`
❌ Service Account Key Not Found!

The seed script requires a Firebase Admin SDK service account key.
Please follow these steps:

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save the JSON file to this project folder
   (e.g., c:/Users/Wajiz.pk/StudioProjects/qataar/serviceAccountKey.json)

OR set the environment variable:
   $env:GOOGLE_APPLICATION_CREDENTIALS="path/to/your/serviceAccount.json"

Then run: node seed_data.js
`);
  process.exit(1);
}

const admin = require("firebase-admin");
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function seedGroceryData() {
  console.log("🌱 Seeding grocery dummy data...");

  // ─────────────────────────────────────────
  // 1. STORE: Imtiaz Super Market
  // ─────────────────────────────────────────
  const storeRef = db.collection("stores").doc("imtiaz_karachi");
  await storeRef.set({
    name: "Imtiaz Super Market",
    location: "Karachi",
  });
  console.log("✅ Store created: Imtiaz Super Market");

  // ─────────────────────────────────────────
  // 2. BRANCH: Clifton Branch
  // ─────────────────────────────────────────
  const branchRef = storeRef.collection("branches").doc("clifton_branch");
  await branchRef.set({
    name: "Clifton Branch",
    location: "Karachi",
    latitude: 24.8138,
    longitude: 67.0300,
    address: "Block 5, Clifton, Karachi",
  });
  console.log("✅ Branch created: Clifton Branch");

  // ─────────────────────────────────────────
  // 3. COUNTERS (3 active counters)
  // ─────────────────────────────────────────
  const counters = [
    { id: "counter_1", name: "Counter 1", isActive: true },
    { id: "counter_2", name: "Counter 2", isActive: true },
    { id: "counter_3", name: "Counter 3", isActive: true },
  ];

  for (const c of counters) {
    await branchRef.collection("counters").doc(c.id).set({
      name: c.name,
      isActive: c.isActive,
    });
  }
  console.log("✅ 3 Counters created");

  // ─────────────────────────────────────────
  // 4. TIME SLOTS (Morning to Evening)
  // ─────────────────────────────────────────
  const timeSlots = [
    { id: "slot_1", startTime: "09:00", endTime: "09:30", capacity: 20, bookedCount: 0 },
    { id: "slot_2", startTime: "09:30", endTime: "10:00", capacity: 20, bookedCount: 0 },
    { id: "slot_3", startTime: "10:00", endTime: "10:30", capacity: 20, bookedCount: 3 },
    { id: "slot_4", startTime: "10:30", endTime: "11:00", capacity: 20, bookedCount: 1 },
    { id: "slot_5", startTime: "11:00", endTime: "11:30", capacity: 20, bookedCount: 0 },
    { id: "slot_6", startTime: "11:30", endTime: "12:00", capacity: 20, bookedCount: 0 },
    { id: "slot_7", startTime: "14:00", endTime: "14:30", capacity: 20, bookedCount: 0 },
    { id: "slot_8", startTime: "14:30", endTime: "15:00", capacity: 20, bookedCount: 0 },
    { id: "slot_9", startTime: "15:00", endTime: "15:30", capacity: 20, bookedCount: 0 },
    { id: "slot_10", startTime: "15:30", endTime: "16:00", capacity: 20, bookedCount: 0 },
    { id: "slot_11", startTime: "16:00", endTime: "16:30", capacity: 20, bookedCount: 0 },
    { id: "slot_12", startTime: "16:30", endTime: "17:00", capacity: 20, bookedCount: 0 },
  ];

  for (const slot of timeSlots) {
    await branchRef.collection("timeSlots").doc(slot.id).set({
      startTime: slot.startTime,
      endTime: slot.endTime,
      capacity: slot.capacity,
      bookedCount: slot.bookedCount,
    });
  }
  console.log("✅ 12 Time Slots created");

  // ─────────────────────────────────────────
  // 5. PRE-SEED SOME TOKENS (to simulate queue)
  // ─────────────────────────────────────────
  const todayStr = new Date().toISOString().split('T')[0];

  const dummyTokens = [
    {
      userId: "dummy_user_1",
      tokenNumber: "QTR-1001",
      numberOfItems: 8,
      slotId: "slot_3",
      counterId: "counter_1",
      status: "serving",
      queuePosition: 1,
      priority: "normal",
      congestionLevel: "Low",
      estimatedWaitMinutes: 0,
      date: todayStr,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      userId: "dummy_user_2",
      tokenNumber: "QTR-1002",
      numberOfItems: 15,
      slotId: "slot_3",
      counterId: "counter_1",
      status: "waiting",
      queuePosition: 2,
      priority: "normal",
      congestionLevel: "Low",
      estimatedWaitMinutes: 4,
      date: todayStr,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      userId: "dummy_user_3",
      tokenNumber: "QTR-1003",
      numberOfItems: 25,
      slotId: "slot_3",
      counterId: "counter_2",
      status: "waiting",
      queuePosition: 1,
      priority: "high",
      congestionLevel: "Medium",
      estimatedWaitMinutes: 5,
      date: todayStr,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      userId: "dummy_user_4",
      tokenNumber: "QTR-1004",
      numberOfItems: 5,
      slotId: "slot_4",
      counterId: "counter_1",
      status: "waiting",
      queuePosition: 3,
      priority: "normal",
      congestionLevel: "Low",
      estimatedWaitMinutes: 8,
      date: todayStr,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  for (let i = 0; i < dummyTokens.length; i++) {
    await branchRef.collection("tokens").doc(`token_${1001 + i}`).set(dummyTokens[i]);
  }
  console.log("✅ 4 Dummy Tokens created");

  // ─────────────────────────────────────────
  // 6. SECOND STORE: Carrefour
  // ─────────────────────────────────────────
  const store2Ref = db.collection("stores").doc("carrefour_karachi");
  await store2Ref.set({
    name: "Carrefour",
    location: "Karachi",
  });

  const branch2Ref = store2Ref.collection("branches").doc("dolmen_branch");
  await branch2Ref.set({
    name: "Dolmen Mall Branch",
    location: "Karachi",
    latitude: 24.8142,
    longitude: 67.0310,
    address: "Dolmen Mall, Clifton, Karachi",
  });

  await branch2Ref.collection("counters").doc("counter_a").set({
    name: "Express Counter",
    isActive: true,
  });
  await branch2Ref.collection("counters").doc("counter_b").set({
    name: "Regular Counter",
    isActive: true,
  });

  const slots2 = [
    { id: "slot_a1", startTime: "10:00", endTime: "10:30", capacity: 15, bookedCount: 0 },
    { id: "slot_a2", startTime: "10:30", endTime: "11:00", capacity: 15, bookedCount: 0 },
    { id: "slot_a3", startTime: "11:00", endTime: "11:30", capacity: 15, bookedCount: 0 },
    { id: "slot_a4", startTime: "11:30", endTime: "12:00", capacity: 15, bookedCount: 0 },
  ];
  for (const s of slots2) {
    await branch2Ref.collection("timeSlots").doc(s.id).set({
      startTime: s.startTime,
      endTime: s.endTime,
      capacity: s.capacity,
      bookedCount: s.bookedCount,
    });
  }

  console.log("✅ Second store (Carrefour) created with 2 counters and 4 slots");

  console.log("\n🎉 Seed complete! You can now test the grocery module.");
  console.log("\n📋 Test Flow:");
  console.log("   1. Login as a user");
  console.log("   2. Select 'Shop & Groceries'");
  console.log("   3. Pick 'Imtiaz Super Market' → 'Clifton Branch'");
  console.log("   4. Enter item count and select a preferred slot");
  console.log("   5. View suggested slots and book one");
  console.log("   6. See your token and live dashboard");
  process.exit(0);
}

seedGroceryData().catch((err) => {
  console.error("❌ Seed failed:", err);
  process.exit(1);
});
