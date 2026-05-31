import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'dart:convert';

import 'grocery_token_screen.dart';
import 'grocery_my_token_screen.dart';
import '../enums/priority_level.dart';

class GrocerySuggestedSlotsScreen extends StatefulWidget {
  final String storeId;
  final String branchId;
  final String branchName;
  final int numberOfItems;
  final String preferredSlotId;
  final PriorityLevel priority;

  const GrocerySuggestedSlotsScreen({
    super.key,
    required this.storeId,
    required this.branchId,
    required this.branchName,
    required this.numberOfItems,
    required this.preferredSlotId,
    required this.priority,
  });

  @override
  State<GrocerySuggestedSlotsScreen> createState() =>
      _GrocerySuggestedSlotsScreenState();
}

class _GrocerySuggestedSlotsScreenState
    extends State<GrocerySuggestedSlotsScreen> {
  final Color navyBlue = const Color(0xFF1C30A3);

  bool _isNavigating = false;

  @override
  void dispose() {
    _isNavigating = false;
    super.dispose();
  }

  String get storeId => widget.storeId;
  String get branchId => widget.branchId;
  String get branchName => widget.branchName;
  int get numberOfItems => widget.numberOfItems;
  String get preferredSlotId => widget.preferredSlotId;
  PriorityLevel get priority => widget.priority;

  Color _getCongestionColor(String congestion) {
    switch (congestion) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
    }
    return Colors.grey;
  }

  Widget _slotInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _extractTokens(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Map<String, dynamic> _calculateSmartSlotsSync(
    List<Map<String, dynamic>> slots,
    List<QueryDocumentSnapshot> counters,
    List<Map<String, dynamic>> tokensList,
  ) {
    List<Map<String, dynamic>> results = [];

    // ~30 seconds per item average checkout time
    final avgTimePerItemSec = 30;
    final estimatedServiceTimeSec = numberOfItems * avgTimePerItemSec;

    for (var slot in slots) {
      final slotId = slot['id'] as String;
      final capacity = (slot['capacity'] ?? 20) as int;
      final bookedCount = (slot['bookedCount'] ?? 0) as int;
      final startTime = slot['startTime'] ?? '--:--';
      final endTime = slot['endTime'] ?? '--:--';

      // Count tokens for this slot
      final slotTokens = tokensList
          .where((t) => (t['slotId'] ?? '') == slotId)
          .toList();
      final slotTokenCount = slotTokens.length;

      // Available capacity
      final currentBooked = slotTokenCount;
      final currentAvailable = capacity - currentBooked;
      if (currentAvailable <= 0) continue;

      // Estimate wait time (global)
      final estimatedWaitMin = (slotTokenCount * estimatedServiceTimeSec / 60)
          .ceil();

      // Congestion level
      final ratio = currentBooked / capacity;
      String congestion;
      if (ratio < 0.4) {
        congestion = 'Low';
      } else if (ratio < 0.8) {
        congestion = 'Medium';
      } else {
        congestion = 'High';
      }

      // Priority score: lower is better
      int preferredBonus = (slotId == preferredSlotId) ? -10 : 0;
      double score = ratio * 20 + estimatedWaitMin * 0.5 + preferredBonus;

      final baseSlotData = {
        'slotId': slotId,
        'startTime': startTime,
        'endTime': endTime,
        'capacity': capacity,
        'bookedCount': bookedCount,
        'currentBooked': currentBooked,
        'currentAvailable': currentAvailable,
        'estimatedWaitMin': estimatedWaitMin,
        'congestion': congestion,
        'score': score,
        'slotTokenCount': slotTokenCount,
      };

      if (slotId == preferredSlotId && counters.isNotEmpty) {
        // Expand preferred slot into one card per counter
        for (var counterDoc in counters) {
          final counterId = counterDoc.id;
          final counterData = counterDoc.data() as Map<String, dynamic>? ?? {};
          final counterName = counterData['name'] ?? 'Counter $counterId';

          final counterSlotTokens = tokensList
              .where(
                (t) =>
                    (t['slotId'] ?? '') == slotId &&
                    (t['counterId'] ?? '') == counterId,
              )
              .toList();
          final counterTokenCount = counterSlotTokens.length;
          final counterEstimatedWaitMin =
              (counterTokenCount * estimatedServiceTimeSec / 60).ceil();

          // Slightly adjust score per counter so less-busy counters appear first
          double counterScore = score + counterTokenCount * 0.3;

          results.add({
            ...baseSlotData,
            'counterId': counterId,
            'counterName': counterName,
            'counterTokenCount': counterTokenCount,
            'counterEstimatedWaitMin': counterEstimatedWaitMin,
            'score': counterScore,
            'isCounterSpecific': true,
          });
        }
      } else {
        // Non-preferred slots: single entry (auto-assign counter later)
        results.add({...baseSlotData, 'isCounterSpecific': false});
      }
    }

    // Sort by score (best first)
    results.sort(
      (a, b) => (a['score'] as double).compareTo(b['score'] as double),
    );

    return {'slots': results, 'counters': counters};
  }

  Future<void> _bookToken(
    BuildContext context,
    Map<String, dynamic> slot, {
    String? specificCounterId,
  }) async {
    // Prevent double-taps/racing navigation
    if (_isNavigating) return;

    debugPrint(
      '🧾 Grocery _bookToken START mounted=${context.mounted} slotId=${slot['slotId']} specificCounterId=$specificCounterId',
    );
    if (!context.mounted) {
      debugPrint('🧾 Grocery _bookToken EXIT: context not mounted');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final branchRef = db
          .collection('stores')
          .doc(storeId)
          .collection('branches')
          .doc(branchId);
      final tokensRef = branchRef.collection('tokens');
      final slotRef = branchRef.collection('timeSlots').doc(slot['slotId']);

      String assignedCounterId;

      if (specificCounterId != null && specificCounterId.isNotEmpty) {
        assignedCounterId = specificCounterId;
      } else {
        // Auto-assign to counter with least tokens
        final countersSnap = await branchRef
            .collection('counters')
            .where('isActive', isEqualTo: true)
            .get();

        if (countersSnap.docs.isEmpty) {
          if (context.mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text("No active counters available")),
            );
          }
          return;
        }

        assignedCounterId = countersSnap.docs.first.id;
        int minTokens = 9999;
        for (var c in countersSnap.docs) {
          final countSnap = await tokensRef
              .where('counterId', isEqualTo: c.id)
              .where('status', whereIn: ['waiting', 'serving'])
              .count()
              .get();
          final count = countSnap.count ?? 0;
          if (count < minTokens) {
            minTokens = count;
            assignedCounterId = c.id;
          }
        }
      }

      // Calculate queue position for this counter
      final counterTokensSnap = await tokensRef
          .where('counterId', isEqualTo: assignedCounterId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('queuePosition', descending: true)
          .limit(1)
          .get();

      int queuePosition = 1;
      if (counterTokensSnap.docs.isNotEmpty) {
        final data =
            counterTokensSnap.docs.first.data() as Map<String, dynamic>;
        final lastQueue = data['queuePosition'] ?? 0;
        queuePosition = (lastQueue ?? 0) + 1;
      }

      // Generate token number
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final tokenCountSnap = await tokensRef
          .where('date', isEqualTo: todayStr)
          .count()
          .get();
      final tokenCount = tokenCountSnap.count ?? 0;
      final tokenNumber = 'QTR-${1001 + tokenCount}';

      // Priority from user selection
      final priorityString = switch (priority) {
        PriorityLevel.urgent => 'urgent',
        PriorityLevel.senior => 'senior',
        PriorityLevel.regular => 'normal',
      };

      // Create token
      final newTokenRef = tokensRef.doc();
      final estimatedWaitMin =
          (slot['counterEstimatedWaitMin'] as int?) ??
          (slot['estimatedWaitMin'] as int?) ??
          0;

      final slotStartRaw = slot['startTime'] ?? slot['start'];
      final slotEndRaw = slot['endTime'] ?? slot['end'];

      debugPrint(
        '🛒 Book slotId=${slot['slotId']} startTime=${slot['startTime']} endTime=${slot['endTime']} start=${slot['start']} end=${slot['end']}',
      );
      debugPrint('🛒 Using slotStartRaw=$slotStartRaw slotEndRaw=$slotEndRaw');

      final slotStartTime = (slotStartRaw ?? '--:--').toString();
      final slotEndTime = (slotEndRaw ?? '--:--').toString();

      print(
        "🔧 DEBUG: Starting booking transaction for slot: ${slot['slotId']}",
      );

      await db.runTransaction((tx) async {
        // Get slot for capacity check (still needed for UI validation)
        final slotDoc = await tx.get(slotRef);
        final slotData = slotDoc.data() as Map<String, dynamic>? ?? {};
        final currentBooked = slotData['bookedCount'] as int? ?? 0;
        final capacity = slotData['capacity'] as int? ?? 20;

        print(
          "🔧 DEBUG: Slot ${slot['slotId']} currentBooked=$currentBooked, capacity=$capacity",
        );

        if (currentBooked >= capacity) {
          throw Exception(
            "Slot ${slot['slotId']} is now full ($currentBooked/$capacity). Please select another slot.",
          );
        }

        // Create token
        tx.set(newTokenRef, {
          'userId': user.uid,
          'tokenNumber': tokenNumber,
          'numberOfItems': numberOfItems,
          'slotId': slot['slotId'],
          'slotStartTime': slotStartTime,
          'slotEndTime': slotEndTime,
          // backward-compat for older screens/docs
          'slotStart': slotStartTime,
          'slotEnd': slotEndTime,
          'counterId': assignedCounterId,
          'status': 'waiting',
          'queuePosition': queuePosition,
          'priority': priorityString,
          'congestionLevel': slot['congestion'],
          'estimatedWaitMinutes': estimatedWaitMin,
          'date': todayStr,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Atomic increment bookedCount
        tx.update(slotRef, {'bookedCount': FieldValue.increment(1)});

        print(
          "🔧 DEBUG: Transaction committed successfully for slot: ${slot['slotId']}",
        );
      });

      // 🔔 Call backend so it can send "Grocery Token Booked!" notification
      // ===============================
      // 🚀 NAVIGATION + BACKGROUND TASKS
      // ===============================

      final tokenId = newTokenRef.id;

      // NAVIGATE IMMEDIATELY (DO NOT WAIT FOR NETWORK CALLS)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GroceryTokenScreen(
              storeId: storeId,
              branchId: branchId,
              tokenId: tokenId,
            ),
          ),
        );
      }

      debugPrint('🧭 NAV: navigated instantly tokenId=$tokenId');

      // BACKGROUND TASK (DO NOT BLOCK UI)
      Future(() async {
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();

          if (fcmToken != null && fcmToken.isNotEmpty) {
            await http.post(
              Uri.parse('$API_BASE_URL/grocery/notify'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': user.uid,
                'storeId': storeId,
                'branchId': branchId,
                'slotId': slot['slotId'],
                'counterId': assignedCounterId,
                'numberOfItems': numberOfItems,
                'fcmToken': fcmToken,
              }),
            );
          }
        } catch (e) {
          debugPrint('❌ background notify failed: $e');
        }
      });
      debugPrint('🧭 NAV: navigation completed for tokenId=${newTokenRef.id}');

      // SnackBar after route change.
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Token booked successfully!")),
        );
      }

      debugPrint(
        '✅ Grocery booked. tokenId=${newTokenRef.id} path=${newTokenRef.path} storeId=$storeId branchId=$branchId',
      );
    } catch (e, st) {
      // Print full exception + stack trace to understand why navigation is interrupted
      debugPrint('❌ Booking flow failed: $e');
      debugPrintStack(stackTrace: st);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Booking failed: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Image.asset('assets/logo.png', height: 32),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GroceryMyTokenScreen(storeId: storeId, branchId: branchId),
          ),
        ),
        backgroundColor: navyBlue,
        icon: const Icon(Icons.confirmation_number, color: Colors.white),
        label: Text(
          "My Token",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('branches')
            .doc(branchId)
            .collection('timeSlots')
            .orderBy('startTime')
            .snapshots(),
        builder: (context, slotsSnapshot) {
          if (slotsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (slotsSnapshot.hasError) {
            return Center(
              child: Text(
                "Error loading slots: ${slotsSnapshot.error}",
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            );
          }

          final slotsDocs = slotsSnapshot.data?.docs ?? [];
          if (slotsDocs.isEmpty) {
            return Center(
              child: Text(
                "No time slots configured for today.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // Extract slots data
          final slots = slotsDocs
              .map(
                (doc) => <String, dynamic>{
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                },
              )
              .toList();

          // Live data for counters and tokens
          final db = FirebaseFirestore.instance;
          final branchRef = db
              .collection('stores')
              .doc(storeId)
              .collection('branches')
              .doc(branchId);
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);

          return FutureBuilder<Map<String, dynamic>>(
            future:
                Future.wait([
                  branchRef
                      .collection('counters')
                      .where('isActive', isEqualTo: true)
                      .get(),
                  branchRef
                      .collection('tokens')
                      .where('date', isEqualTo: todayStr)
                      .where('status', whereIn: const ['waiting', 'serving'])
                      .get(),
                ]).then((results) {
                  final countersSnap = results[0] as QuerySnapshot;
                  final tokensSnap = results[1] as QuerySnapshot;
                  final counters = countersSnap.docs;
                  final tokensList = _extractTokens(tokensSnap);
                  return _calculateSmartSlotsSync(slots, counters, tokensList);
                }),
            builder: (context, computationSnapshot) {
              if (computationSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (computationSnapshot.hasError) {
                return Center(
                  child: Text(
                    "Error computing slots: ${computationSnapshot.error}",
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                );
              }

              final data =
                  computationSnapshot.data as Map<String, dynamic>? ??
                  {'slots': <Map<String, dynamic>>[]};
              final computedSlots = data['slots'] as List<Map<String, dynamic>>;
              if (computedSlots.isEmpty) {
                return Center(
                  child: Text(
                    "No available slots for today.",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1C30A3), Color(0xFF3A4ED1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Suggested Time Slots",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$branchName  |  $numberOfItems items",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Live updates • Preferred slot shown per counter. Others auto-assign.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        // Trigger rebuild via setState if needed, but StreamBuilder handles live updates
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: computedSlots.length,
                        itemBuilder: (context, index) {
                          final slot = computedSlots[index];
                          final isPreferred = slot['slotId'] == preferredSlotId;
                          final isCounterSpecific =
                              slot['isCounterSpecific'] == true;
                          final counterName = slot['counterName'] as String?;
                          final counterEstimatedWaitMin =
                              (slot['counterEstimatedWaitMin'] as int?) ??
                              (slot['estimatedWaitMin'] as int?) ??
                              0;

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: isPreferred
                                    ? Border.all(color: Colors.amber, width: 2)
                                    : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Counter name chip (for preferred slots)
                                    if (isCounterSpecific &&
                                        counterName != null) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: navyBlue.withAlpha(
                                            54,
                                          ), // 21% opacity ~0x15*4=54
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: navyBlue.withAlpha(
                                              130,
                                            ), // 51% ~0x33*4
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.storefront,
                                              size: 18,
                                              color: navyBlue,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Counter: ",
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                counterName,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: navyBlue,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "Queue: ${slot['counterTokenCount'] ?? 0}",
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              color: Color(0xFF1C30A3),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "${slot['startTime']} - ${slot['endTime']}",
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (isPreferred) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  "Preferred",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.amber.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getCongestionColor(
                                              (slot['congestion'] as String?) ??
                                                  'Low',
                                            ).withAlpha(98), // ~38%
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            (slot['congestion'] as String?) ??
                                                'Low',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getCongestionColor(
                                                (slot['congestion']
                                                        as String?) ??
                                                    'Low',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _slotInfo(
                                            "Current Queue",
                                            "${slot['currentBooked']}/${slot['capacity']}",
                                            Icons.people_outline,
                                          ),
                                        ),
                                        Expanded(
                                          child: _slotInfo(
                                            "Est. Wait",
                                            "$counterEstimatedWaitMin min",
                                            Icons.timer_outlined,
                                          ),
                                        ),
                                        Expanded(
                                          child: _slotInfo(
                                            "Spots Left",
                                            "${slot['currentAvailable']}",
                                            Icons.check_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 42,
                                      child: ElevatedButton(
                                        onPressed: () => _bookToken(
                                          context,
                                          slot,
                                          specificCounterId: isCounterSpecific
                                              ? (slot['counterId'] as String?)
                                              : null,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: navyBlue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          isCounterSpecific &&
                                                  counterName != null
                                              ? "Book $counterName"
                                              : "Book This Slot",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
