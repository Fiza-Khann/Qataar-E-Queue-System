const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");
const cron = require("node-cron");
const nodemailer = require("nodemailer");
const dotenv = require("dotenv");
const crypto = require("crypto");

dotenv.config();

const serviceAccount = (() => {
  try {
    return require("./qataar-f48c7-127054c57832.json");
  } catch (e) {
    // allow syntax check even if the service account json isn't present locally
    return null;
  }
})();

if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} else {
  console.warn("[WARN] Missing service account json. Admin SDK not initialized.");
}


const app = express();
app.use(cors());
app.use(bodyParser.json());

const db = admin.firestore();

/* ---------------------------
   1️⃣ Booking Endpoint (saves to Firestore)
---------------------------- */
app.post("/bookings", async (req, res) => {
  try {
    const {
      userId,
      serviceName,
      branchId,
      serviceId,
      branchName,
      categoryId,
      categoryName,
      city,
      fcmToken,
    } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ success: false, message: "Missing FCM token" });
    }

    const dateStr = new Date().toISOString().split('T')[0];
    const bookingsCollection = db.collection('tokens').doc(dateStr).collection('bookings');

    // Automatically assign next token number per service
    const lastTokenSnapshot = await bookingsCollection
      .where("serviceId", "==", serviceId)
      .orderBy("tokenNumber", "desc")
      .limit(1)
      .get();

    let newTokenNumber = 1;
    if (!lastTokenSnapshot.empty) {
      newTokenNumber = lastTokenSnapshot.docs[0].data().tokenNumber + 1;
    }

    const bookingRef = bookingsCollection.doc();

    await bookingRef.set({
      userId,
      serviceName,
      serviceId,
      branchId,
      branchName,
      categoryId,
      categoryName,
      city,
      fcmToken,
      tokenNumber: newTokenNumber,
      status: 'booked',
      notified: false,
      notifiedApproaching: false,
      notifiedTurn: false,
      bookingTime: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Increment dailyTokenCounter in services doc
    const serviceRef = db.collection('categories').doc(categoryId).collection('branches').doc(branchId).collection('services').doc(serviceId);
    await serviceRef.set({ dailyTokenCounter: admin.firestore.FieldValue.increment(1) }, { merge: true });

    // Send Booking Confirmed Notification
    const message = {
      token: fcmToken,
      notification: {
        title: "Booking Confirmed!",
        body: `Your token ${newTokenNumber} is booked for ${serviceName} at ${branchName}.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };
    await admin.messaging().send(message);
    await bookingRef.update({ notified: true });

    res.status(200).json({
      success: true,
      message: "Booking saved and notification sent.",
      tokenNumber: newTokenNumber,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   2️⃣ Send Notification Only (no Firestore save)
---------------------------- */
app.post("/sendNotification", async (req, res) => {
  try {
    const { fcmToken, tokenNumber, serviceName, branchName } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ success: false, message: "Missing FCM token" });
    }

    // Send Booking Confirmed Notification
    const message = {
      token: fcmToken,
      notification: {
        title: "Booking Confirmed!",
        body: `Your token ${tokenNumber} is booked for ${serviceName} at ${branchName}.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };
    await admin.messaging().send(message);

    res.status(200).json({
      success: true,
      message: "Notification sent successfully.",
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   3️⃣ Update Current Token
---------------------------- */
app.post("/updateToken", async (req, res) => {
  const { categoryId, branchId, serviceId, currentToken } = req.body;
  try {
    const serviceRef = db.collection('categories').doc(categoryId).collection('branches').doc(branchId).collection('services').doc(serviceId);
    await serviceRef.set({ currentToken }, { merge: true });
    res.status(200).json({ success: true, message: "Current token updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   4️⃣ Grocery Notification Endpoint (NO Firestore writes)
---------------------------- */
app.post("/grocery/notify", async (req, res) => {
  try {
    const {
      userId,
      storeId,
      branchId,
      slotId,
      counterId,
      numberOfItems,
      fcmToken,
    } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ success: false, message: "Missing FCM token" });
    }

    const branchRef = db.collection('stores').doc(storeId).collection('branches').doc(branchId);
    const tokensRef = branchRef.collection('tokens');
    const slotRef = branchRef.collection('timeSlots').doc(slotId);

    const todayStr = new Date().toISOString().split('T')[0];

    // Get token count for today
    const tokenCountSnap = await tokensRef.where('date', '==', todayStr).get();
    const tokenCount = tokenCountSnap.size;
    const tokenNumber = `QTR-${1001 + tokenCount}`;

    // Calculate queue position
    const counterTokensSnap = await tokensRef
      .where('counterId', '==', counterId)
      .where('status', 'in', ['waiting', 'serving'])
      .orderBy('queuePosition', 'desc')
      .limit(1)
      .get();

    let queuePosition = 1;
    if (!counterTokensSnap.empty) {
      queuePosition = (counterTokensSnap.docs[0].data().queuePosition || 0) + 1;
    }

    // Priority
    let priority = 'normal';
    if (numberOfItems > 30) {
      priority = 'high';
    }

    // Check slot capacity
    const slotDoc = await slotRef.get();
    const slotData = slotDoc.data() || {};
    const currentBooked = slotData.bookedCount || 0;
    const capacity = slotData.capacity || 20;

    if (currentBooked >= capacity) {
      return res.status(400).json({ success: false, message: "Slot is full" });
    }

    // IMPORTANT:
    // Grocery token creation must happen only in the Flutter transaction.
    // Backend /grocery/notify should be notification-only.


    // Ensure the cron job can find the user's FCM token
    // Grocery cron uses: db.collection('users').doc(userId).data().fcmToken
    await db.collection('users').doc(userId).set({ fcmToken }, { merge: true });

    // Send notification
    const message = {
      token: fcmToken,
      notification: {
        title: "Grocery Token Booked!",
        body: `Your token ${tokenNumber} is confirmed. Queue position: ${queuePosition}`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };
    await admin.messaging().send(message);


    res.status(200).json({
      success: true,
      message: "Grocery token notification sent successfully.",
      tokenNumber,
      queuePosition,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   5️⃣ Cron Job: Turn Approaching & Your Turn (Services)
---------------------------- */
const SERVICES_CRON_INTERVAL = process.env.SERVICES_CRON_INTERVAL || '*/3 * * * *';

cron.schedule(SERVICES_CRON_INTERVAL, async () => {
  try {
    console.log("🔄 Services cron job running...");

    const todayStr = new Date().toISOString().split('T')[0];
    const categoriesSnapshot = await db.collection('categories').get();

    for (const categoryDoc of categoriesSnapshot.docs) {
      const categoryId = categoryDoc.id;
      const branchesSnapshot = await db.collection('categories').doc(categoryId).collection('branches').get();

      for (const branchDoc of branchesSnapshot.docs) {
        const branchId = branchDoc.id;
        const servicesSnapshot = await db.collection('categories').doc(categoryId).collection('branches').doc(branchId).collection('services').get();

        for (const serviceDoc of servicesSnapshot.docs) {
          const serviceData = serviceDoc.data();
          const currentToken = serviceData.currentToken || 0;
          const serviceId = serviceDoc.id;

          console.log(`📍 Checking service ${serviceId} in branch ${branchId}, category ${categoryId}, currentToken: ${currentToken}`);

const bookingsRef = db.collection('tokens').doc(todayStr)
            .collection('bookings')
            .where("serviceId", "==", serviceId)
            .where("branchId", "==", branchId)
            .where("categoryId", "==", categoryId)
            .where('notifiedTurn', '==', false);

          const snapshot = await bookingsRef.get();

          for (const doc of snapshot.docs) {
            const booking = doc.data();

            if (booking.tokenNumber <= currentToken) continue;

            console.log(`🎫 Checking booking token ${booking.tokenNumber}, notifiedTurn: ${booking.notifiedTurn}`);

            // Turn Approaching (2 tokens away)
            if (!booking.notifiedApproaching && booking.tokenNumber - currentToken === 2) {
              console.log(`📢 Sending 'Your Turn is Near!' to token ${booking.tokenNumber}`);
              const msg = {
                token: booking.fcmToken,
                notification: {
                  title: "Your Turn is Near!",
                  body: `Token ${booking.tokenNumber} will be called soon at ${booking.branchName}.`,
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              };
              await admin.messaging().send(msg);
              await doc.ref.update({ notifiedApproaching: true });
            }

            // Your Turn (next token)
            if (!booking.notifiedTurn && booking.tokenNumber === currentToken + 1) {
              console.log(`🚨 Sending 'It's Your Turn!' to token ${booking.tokenNumber}`);
              const msg = {
                token: booking.fcmToken,
                notification: {
                  title: "It's Your Turn!",
                  body: `Please prepare. Your token ${booking.tokenNumber} is next to be served at ${booking.branchName}.`,
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              };
              await admin.messaging().send(msg);
              await doc.ref.update({ notifiedTurn: true });
            }
          }
        }
      }
    }
    console.log("✅ Services cron job completed");
  } catch (err) {
    console.error("❌ Services cron job error:", err);
  }
});

/* ---------------------------  
   6️⃣ Cron Job: Grocery Turn Approaching & Your Turn
---------------------------- */
const GROCERY_CRON_INTERVAL = process.env.GROCERY_CRON_INTERVAL || '*/3 * * * *';

cron.schedule(GROCERY_CRON_INTERVAL, async () => {
  try {
    console.log("🛒 Grocery cron job running...");

    // FIRESTORE QUOTA MITIGATION:
    // Only load grocery tokens that still need notifications.
    // This avoids reading the entire waiting list every cron tick.
    const needApproach = false;
    const needTurn = false;

    const todayStr = new Date().toISOString().split('T')[0];
    const storesSnapshot = await db.collection('stores').get();

    for (const storeDoc of storesSnapshot.docs) {
      const storeId = storeDoc.id;
      const branchesSnapshot = await db.collection('stores').doc(storeId).collection('branches').get();

      for (const branchDoc of branchesSnapshot.docs) {
        const branchId = branchDoc.id;
        const countersSnapshot = await db.collection('stores').doc(storeId).collection('branches').doc(branchId).collection('counters').get();

        for (const counterDoc of countersSnapshot.docs) {
          const counterId = counterDoc.id;
          const counterData = counterDoc.data();

          if (!counterData.isActive) continue;

          // Get currently serving token at this counter
          const servingSnap = await db.collection('stores').doc(storeId)
            .collection('branches').doc(branchId)
            .collection('tokens')
            .where('counterId', '==', counterId)
            .where('status', '==', 'serving')
            .orderBy('queuePosition')
            .limit(1)
            .get();

          let currentServingPosition = 0;
          if (!servingSnap.empty) {
            currentServingPosition = servingSnap.docs[0].data().queuePosition || 0;
          } else {
            // If no serving token exists, promote the first waiting token
            // so notifications can work (tokensAhead window depends on currentServingPosition).
            const firstWaitingSnap = await db.collection('stores').doc(storeId)
              .collection('branches').doc(branchId)
              .collection('tokens')
              .where('counterId', '==', counterId)
              .where('status', '==', 'waiting')
              .orderBy('queuePosition')
              .limit(1)
              .get();

            if (!firstWaitingSnap.empty) {
              const nextDoc = firstWaitingSnap.docs[0];
              const nextData = nextDoc.data() || {};

              console.log(`🍽️ Grocery: promoting first waiting token ${nextData.tokenNumber} to serving at counter ${counterId}`);

              await nextDoc.ref.update({
                status: 'serving',
                startTime: admin.firestore.FieldValue.serverTimestamp(),
              });

              currentServingPosition = nextData.queuePosition || 0;
            } else {
              currentServingPosition = 0;
            }
          }

          console.log(`🧮 Grocery: counter=${counterId} currentServingPosition=${currentServingPosition}`);

          // Reload serving token after possible promotion (helps keep cron consistent)
          if (currentServingPosition === 0) {
            const servingSnap2 = await db.collection('stores').doc(storeId)
              .collection('branches').doc(branchId)
              .collection('tokens')
              .where('counterId', '==', counterId)
              .where('status', '==', 'serving')
              .orderBy('queuePosition')
              .limit(1)
              .get();
            if (!servingSnap2.empty) {
              currentServingPosition = servingSnap2.docs[0].data().queuePosition || 0;
            }
          }


          // Get waiting tokens (quota mitigation: only tokens that still need notifications)
          const waitingSnap = await db.collection('stores').doc(storeId)
            .collection('branches').doc(branchId)
            .collection('tokens')
            .where('counterId', '==', counterId)
            .where('status', '==', 'waiting')
            .where('notifiedTurn', '==', false)
            .orderBy('queuePosition')
            .get();

          for (const doc of waitingSnap.docs) {
            const token = doc.data();
            const queuePosition = token.queuePosition || 0;
            const userId = token.userId;

            // Calculate tokens ahead
            const tokensAhead = queuePosition - currentServingPosition;

            // Get user FCM token
            const userDoc = await db.collection('users').doc(userId).get();
            const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

            if (!fcmToken) continue;

            // Turn Approaching (2 positions away) - use <= for robustness
            if (tokensAhead <= 2 && !token.notifiedApproaching) {

              console.log(`📢 Grocery: 'Your Turn is Near!' for token ${token.tokenNumber}`);
              const msg = {
                token: fcmToken,
                notification: {
                  title: "Your Turn is Near!",
                  body: `Your grocery token ${token.tokenNumber} will be called soon at counter ${counterData.name || counterId}.`,
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              };
              await admin.messaging().send(msg);
              await doc.ref.update({ notifiedApproaching: true });
            }

            // Your Turn (next position) - handle queuePosition alignment
            if (tokensAhead <= 1 && !token.notifiedTurn) {

              console.log(`🚨 Grocery: 'It's Your Turn!' for token ${token.tokenNumber}`);
              const msg = {
                token: fcmToken,
                notification: {
                  title: "It's Your Turn!",
                  body: `Please prepare. Your grocery token ${token.tokenNumber} is next at counter ${counterData.name || counterId}.`,
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              };
              await admin.messaging().send(msg);
              await doc.ref.update({ notifiedTurn: true });
            }
          }
        }
      }
    }
    console.log("✅ Grocery cron job completed");
  } catch (err) {
    console.error("❌ Grocery cron job error:", err);
  }
});

/* ---------------------------  
   7️⃣ Auto-Skip Missed Serving Tokens (Grocery) - Every 30 seconds
---------------------------- */
const AUTOSKIP_CRON_INTERVAL = process.env.AUTOSKIP_CRON_INTERVAL || '*/90 * * * * *';

cron.schedule(AUTOSKIP_CRON_INTERVAL, async () => {

  try {
    console.log('⏰ Auto-skip cron running...');
    const now = Date.now();
    const timeoutMs = 180000; // 3 minutes
    const todayStr = new Date().toISOString().split('T')[0];
    
    const storesSnapshot = await db.collection('stores').get();
    
    for (const storeDoc of storesSnapshot.docs) {
      const storeId = storeDoc.id;
      const branchesSnapshot = await db.collection('stores').doc(storeId).collection('branches').get();

      for (const branchDoc of branchesSnapshot.docs) {
        const branchId = branchDoc.id;
        const countersSnapshot = await db.collection('stores').doc(storeId).collection('branches').doc(branchId).collection('counters').get();

        for (const counterDoc of countersSnapshot.docs) {
          const counterId = counterDoc.id;
          if (!counterDoc.data().isActive) continue;

          // Find overdue serving token (no endTime, startTime < now - 3min)
          const overdueServingSnap = await db.collection('stores').doc(storeId)
            .collection('branches').doc(branchId)
            .collection('tokens')
            .where('counterId', '==', counterId)
            .where('status', '==', 'serving')
            .where('endTime', '==', null) // Use == null for missing field
            .get();

          if (overdueServingSnap.empty) continue;

          const overdueTokenDoc = overdueServingSnap.docs[0];
          const overdueToken = overdueTokenDoc.data();
          const startTimeMs = overdueToken.startTime ? overdueToken.startTime.toMillis() : 0;

          if (now - startTimeMs < timeoutMs) continue;

          console.log(`🚨 Skipping overdue token ${overdueToken.tokenNumber} at counter ${counterId}`);

          // Transaction to skip and promote next
          await db.runTransaction(async (transaction) => {
            // Re-fetch to verify
            const freshOverdue = await transaction.get(overdueTokenDoc.ref);
            if (!freshOverdue.exists || freshOverdue.data().status !== 'serving') return;

            // Mark as missed
            transaction.update(overdueTokenDoc.ref, {
              status: 'missed',
              missedAt: admin.firestore.FieldValue.serverTimestamp(),
              missedReason: 'timeout - auto skipped after 3 minutes',
            });

            // Find next waiting (lowest queuePosition)
            const nextWaitingSnap = await db.collection('stores').doc(storeId)
              .collection('branches').doc(branchId)
              .collection('tokens')
              .where('counterId', '==', counterId)
              .where('status', '==', 'waiting')
              .orderBy('queuePosition')
              .limit(1)
              .get({ transaction });

            if (!nextWaitingSnap.empty) {
              const nextTokenDoc = nextWaitingSnap.docs[0];
              transaction.update(nextTokenDoc.ref, {
                status: 'serving',
                startTime: admin.firestore.FieldValue.serverTimestamp(),
              });

              // Notify next user
              const nextUserDoc = await db.collection('users').doc(overdueToken.userId).get();
              const nextFcm = nextUserDoc.data()?.fcmToken;
              if (nextFcm) {
                const msg = {
                  token: nextFcm,
                  notification: {
                    title: "It's Your Turn Now!",
                    body: `Token ${nextTokenDoc.data().tokenNumber} - Previous token skipped due to timeout.`,
                  },
                };
                admin.messaging().send(msg);
              }
            }

            // Notify missed user (if fcmToken available)
            const userDoc = await db.collection('users').doc(overdueToken.userId).get();
            const fcmToken = userDoc.data()?.fcmToken;
            if (fcmToken) {
              const msg = {
                token: fcmToken,
                notification: {
                  title: "Token Skipped",
                  body: `Your token ${overdueToken.tokenNumber} was auto-skipped due to timeout. Please rebook if needed.`,
                },
              };
              admin.messaging().send(msg);
            }
          });

          console.log(`✅ Auto-skipped ${overdueToken.tokenNumber}, promoted next if available`);
        }
      }
    }
    console.log('✅ Auto-skip cron completed');
  } catch (err) {
    console.error('❌ Auto-skip cron error:', err);
  }
});

/* ---------------------------
   7️⃣ Start Server
---------------------------- */
const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

/* ---------------------------
   8️⃣ Optional: Update User Token Endpoint
---------------------------- */
app.post("/updateTokenForUser", async (req, res) => {
  const { userId, fcmToken } = req.body;
  if (!userId || !fcmToken) return res.status(400).send("Missing userId or token");

  await db.collection("users").doc(userId).set({ fcmToken }, { merge: true });
  res.send("Token updated");
});

/* ---------------------------
   🔑 Email OTP Endpoints
---------------------------- */

// Send Email OTP
app.post("/sendEmailOtp", async (req, res) => {
  try {
    const { userId, email } = req.body;

    if (!userId || !email) {
      return res.status(400).json({ success: false, message: "Missing userId or email" });
    }

    // Generate 6-digit OTP
    const otp = crypto.randomInt(100000, 999999).toString();
    const expiry = Date.now() + 5 * 60 * 1000; // 5 minutes

    // Store in Firestore
    await db.collection("emailOtps").doc(userId).set({
      otp,
      expiry,
      email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send email
const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.SMTP_EMAIL,
        pass: process.env.SMTP_PASS,
      },
    });

    await transporter.sendMail({
      from: process.env.SMTP_EMAIL,
      to: email,
      subject: "Your Qataar OTP Code",
      html: `<h2>Your OTP Code</h2><p><strong style="font-size: 24px;">${otp}</strong></p><p>Valid for 5 minutes.</p>`,
    });

    res.json({ success: true, message: "OTP sent successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Verify Email OTP
app.post("/verifyEmailOtp", async (req, res) => {
  try {
    const { userId, otp } = req.body;

    if (!userId || otp.length !== 6) {
      return res.status(400).json({ success: false, message: "Invalid input" });
    }

    const otpDoc = await db.collection("emailOtps").doc(userId).get();
    if (!otpDoc.exists) {
      return res.status(400).json({ success: false, message: "OTP not found" });
    }

    const data = otpDoc.data();
    if (Date.now() > data.expiry) {
      await otpDoc.ref.delete();
      return res.status(400).json({ success: false, message: "OTP expired" });
    }

    if (data.otp !== otp) {
      return res.status(400).json({ success: false, message: "Invalid OTP" });
    }

    await otpDoc.ref.delete();
    res.json({ success: true, message: "Verified" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

