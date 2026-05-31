import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SeedDataScreen extends StatelessWidget {
  const SeedDataScreen({super.key});

  final Color navyBlue = const Color(0xFF1C30A3);

  // ─────────────────────────────
  // COUNTERS
  // ─────────────────────────────
  Future<void> addCounters(DocumentReference branchRef) async {
    for (int i = 1; i <= 3; i++) {
      await branchRef.collection('counters').doc('counter_$i').set({
        'name': 'Counter $i',
        'isActive': true,
      });
    }
  }

  // ─────────────────────────────
  // TIME SLOTS
  // ─────────────────────────────
  Future<void> addTimeSlots(DocumentReference branchRef) async {
    for (int i = 0; i < 8; i++) {
      final hour = 9 + (i ~/ 2);
      final min = (i % 2) * 30;

      final endHour = min == 0 ? hour : hour + 1;
      final endMin = min == 0 ? 30 : 0;

      await branchRef.collection('timeSlots').doc('slot_${i + 1}').set({
        'startTime':
            '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
        'endTime':
            '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}',
        'capacity': 20,
        'bookedCount': i % 3,
      });
    }
  }

  // ─────────────────────────────
  // TOKENS
  // ─────────────────────────────
Future<void> addTokens(DocumentReference branchRef) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);

  final tokens = List.generate(6, (i) {
    return {
      'userId': 'user_${branchRef.id}_$i',
      'tokenNumber': 'QTR-${branchRef.id.substring(0, 3).toUpperCase()}-${1000 + i}',
      'numberOfItems': 3 + (i * 2),

      // slot distribution per branch
      'slotId': 'slot_${(i % 4) + 1}',

      // counter rotation (VERY IMPORTANT)
      'counterId': 'counter_${(i % 3) + 1}',

      'status': i == 0 ? 'serving' : 'waiting',
      'queuePosition': i + 1,

      // priority simulation
      'priority': (i == 4) ? 'high' : 'normal',

      // congestion simulation
      'congestionLevel': i < 2 ? 'Low' : (i < 4 ? 'Medium' : 'High'),

      'estimatedWaitMinutes': i * 6,

      'date': today,
      'createdAt': FieldValue.serverTimestamp(),
    };
  });

  for (int i = 0; i < tokens.length; i++) {
    await branchRef
        .collection('tokens')
        .doc('token_${branchRef.id}_$i')
        .set(tokens[i]);
  }
}

  // ─────────────────────────────
  // FULL BRANCH SETUP
  // ─────────────────────────────
  Future<void> setupBranch(
    DocumentReference storeRef,
    String branchId,
    String name,
    double lat,
    double lng,
    String address,
  ) async {
    final branchRef = storeRef.collection('branches').doc(branchId);

    await branchRef.set({
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'address': address,
    });

    await addCounters(branchRef);
    await addTimeSlots(branchRef);
    await addTokens(branchRef);
  }

  // ─────────────────────────────
  // SEED DATA
  // ─────────────────────────────
  Future<void> _seedData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = FirebaseFirestore.instance;

    try {
      messenger.showSnackBar(
        const SnackBar(content: Text("Seeding data... Please wait")),
      );

     // ───────── STORE 1: IMTIAZ ─────────
final store1 = db.collection('stores').doc('imtiaz_karachi');
await store1.set({'name': 'Imtiaz Super Market', 'location': 'Karachi'});

await setupBranch(
  store1,
  'clifton_branch',
  'Clifton Branch',
  24.8138,
  67.0300,
  'Block 5, Clifton',
);

await setupBranch(
  store1,
  'bahadurabad_branch',
  'Bahadurabad Branch',
  24.8715,
  67.0650,
  'Bahadurabad, Karachi',
);

await setupBranch(
  store1,
  'northnazimabad_branch',
  'North Nazimabad Branch',
  24.9560,
  67.0400,
  'North Nazimabad, Karachi',
);

// ───────── STORE 2: CARREFOUR ─────────
final store2 = db.collection('stores').doc('carrefour_karachi');
await store2.set({'name': 'Carrefour', 'location': 'Karachi'});

await setupBranch(
  store2,
  'dolmen_branch',
  'Dolmen Mall Branch',
  24.8142,
  67.0310,
  'Dolmen Mall Clifton',
);

await setupBranch(
  store2,
  'tariq_road_branch',
  'Tariq Road Branch',
  24.8723,
  67.0621,
  'Tariq Road, Karachi',
);

await setupBranch(
  store2,
  'hyderi_branch',
  'Hyderi Branch',
  24.9400,
  67.0500,
  'Hyderi, Karachi',
);

// ───────── STORE 3: METRO ─────────
final store3 = db.collection('stores').doc('metro_karachi');
await store3.set({'name': 'Metro Cash & Carry', 'location': 'Karachi'});

await setupBranch(
  store3,
  'saddar_branch',
  'Saddar Branch',
  24.8607,
  67.0011,
  'Saddar Karachi',
);

await setupBranch(
  store3,
  'korangi_branch',
  'Korangi Branch',
  24.8350,
  67.1350,
  'Korangi Industrial Area',
);

// ───────── STORE 4: AL-FATAH ─────────
final store4 = db.collection('stores').doc('alfatah_karachi');
await store4.set({'name': 'Al-Fatah', 'location': 'Karachi'});

await setupBranch(
  store4,
  'zamzama_branch',
  'Zamzama Branch',
  24.8050,
  67.0240,
  'Zamzama Clifton',
);

await setupBranch(
  store4,
  'clifton_express_branch',
  'Clifton Express Branch',
  24.8120,
  67.0280,
  'Clifton Block 2',
);

// ───────── STORE 5: CHASE UP ─────────
final store5 = db.collection('stores').doc('chaseup_karachi');
await store5.set({'name': 'Chase Up', 'location': 'Karachi'});

await setupBranch(
  store5,
  'gulshan_branch',
  'Gulshan Branch',
  24.9200,
  67.0900,
  'Gulshan-e-Iqbal',
);

await setupBranch(
  store5,
  'nazimabad_branch',
  'Nazimabad Branch',
  24.9500,
  67.0450,
  'Nazimabad Karachi',
);

await setupBranch(
  store5,
  'malir_branch',
  'Malir Branch',
  24.8820,
  67.1870,
  'Malir Karachi',
);

      messenger.showSnackBar(
        const SnackBar(
          content: Text("✅ All stores seeded successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navyBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storage, size: 64, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  "Seed Dummy Data",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Creates stores, branches, counters, slots, and tokens in Firestore",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _seedData(context),
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      "Seed Data",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: navyBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Go Back",
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}