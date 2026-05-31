import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminGroceryTokensScreen extends StatelessWidget {
  final String storeId;
  final String storeName;
  final String branchId;
  final String branchName;
  final String counterId;
  final String counterName;

  const AdminGroceryTokensScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.branchId,
    required this.branchName,
    required this.counterId,
    required this.counterName,
  });

  final Color navyBlue = const Color(0xFF1C30A3);

  Future<Map<String, Map<String, dynamic>>> _fetchTimeSlots() async {
    final slotsSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('branches')
        .doc(branchId)
        .collection('timeSlots')
        .get();

    final Map<String, Map<String, dynamic>> map = {};
    for (var doc in slotsSnap.docs) {
      map[doc.id] = doc.data();
    }
    return map;
  }

  String _formatDateTime(dynamic ts) {
    if (ts == null) return '--';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return DateFormat('MMM d, HH:mm').format(dt);
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final tokensRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('branches')
        .doc(branchId)
        .collection('tokens');

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _fetchTimeSlots(),
        builder: (context, slotsSnapshot) {
          final slotsMap = slotsSnapshot.data ?? {};

          return Column(
            children: [
              // Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1C30A3), Color(0xFF3A4ED1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.admin_panel_settings,
                              color: Colors.white, size: 28),
                          Expanded(
                            child: Text(
                              branchName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Counter: $counterName",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: tokensRef
                      .where('date', isEqualTo: today)
                      .orderBy('tokenNumber')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.deepPurple, strokeWidth: 2));
                    }

                    final allTokens = snapshot.data!.docs;

                    // Filter by counter
                    final tokens = allTokens
                        .where((doc) => doc['counterId'] == counterId)
                        .toList();

                    if (tokens.isEmpty) {
                      return const Center(
                        child: Text(
                          "No tokens yet for this counter",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      );
                    }

                    final serving = tokens
                        .where((doc) => doc['status'] == 'serving')
                        .toList();

                    var waiting = tokens
                        .where((doc) => doc['status'] == 'waiting')
                        .toList();

                    final served = tokens
                        .where((doc) => doc['status'] == 'served')
                        .toList();

                    final cancelled = tokens
                        .where((doc) => doc['status'] == 'cancelled')
                        .toList();

                    final missed = tokens
                        .where((doc) => doc['status'] == 'missed')
                        .toList(); 

// Sort waiting by priority (urgent > senior > normal) then slot startTime then queuePosition
                    waiting.sort((a, b) {
                      // Priority order: urgent > senior > normal
                      final aPri = (a['priority'] as String?) ?? 'normal';
                      final bPri = (b['priority'] as String?) ?? 'normal';
                      final priorityOrder = {'urgent': 0, 'senior': 1, 'normal': 2};
                      final aPriority = priorityOrder[aPri] ?? 2;
                      final bPriority = priorityOrder[bPri] ?? 2;
                      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
                      
                      final aSlot = slotsMap[a['slotId']] ?? {};
                      final bSlot = slotsMap[b['slotId']] ?? {};
                      final aTime = aSlot['startTime'] ?? '99:99';
                      final bTime = bSlot['startTime'] ?? '99:99';
                      final timeCmp = aTime.toString().compareTo(bTime.toString());
                      if (timeCmp != 0) return timeCmp;
                      final aPos = (a['queuePosition'] ?? 0) as int;
                      final bPos = (b['queuePosition'] ?? 0) as int;
                      return aPos.compareTo(bPos);
                    });

                    return Column(
                      children: [
                        // Current Serving
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C30A3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                serving.isNotEmpty
                                    ? "Now Serving"
                                    : "No one is being served",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                serving.isNotEmpty
                                    ? "${serving.first['tokenNumber']}"
                                    : "-",
                                style: GoogleFonts.poppins(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (serving.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Slot: ${_slotLabel(serving.first, slotsMap)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              ElevatedButton(
onPressed: () async {
                                  if (serving.isNotEmpty) {
                                    final currentDoc = serving.first;
                                    final tokenData = currentDoc.data() as Map<String, dynamic>;
                                    final slotId = tokenData['slotId'] as String?;
                                    
                                    print("🔧 DEBUG: Serving token ${currentDoc.id}, slotId: '$slotId'");

                                    final batch = FirebaseFirestore.instance.batch();

                                    batch.update(tokensRef.doc(currentDoc.id), {
                                      'status': 'served',
                                      'endTime': FieldValue.serverTimestamp(),
                                    });

                                    // Decrement slot booked count when token is served
                                    if (slotId != null && slotId.isNotEmpty) {
                                      final slotRef = FirebaseFirestore.instance
                                          .collection('stores')
                                          .doc(storeId)
                                          .collection('branches')
                                          .doc(branchId)
                                          .collection('timeSlots')
                                          .doc(slotId);
                                      batch.update(slotRef, {
                                        'bookedCount': FieldValue.increment(-1),
                                      });
                                      print("🔧 DEBUG: Will decrement bookedCount for slot: $slotId");
                                    } else {
                                      print("⚠️ WARNING: Token ${currentDoc.id} has no valid slotId - capacity not decremented");
                                    }

                                    try {
                                      await batch.commit();
                                      print("✅ SUCCESS: Serve batch committed for token ${currentDoc.id}");
                                    } catch (e) {
                                      print("❌ ERROR: Failed to commit serve batch: $e");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Serve failed: $e")),
                                      );
                                      return;
                                    }
                                  }

                                  if (waiting.isNotEmpty) {
                                    final nextDoc = waiting.first;
                                    try {
                                      await tokensRef.doc(nextDoc.id).update({
                                        'status': 'serving',
                                        'startTime': FieldValue.serverTimestamp(),
                                      });
                                      print("✅ SUCCESS: Next token ${nextDoc.id} set to serving with startTime"); 
                                      print("✅ SUCCESS: Next token ${nextDoc.id} set to serving");
                                    } catch (e) {
                                      print("❌ ERROR: Failed to promote next token: $e");
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                                child: Text(
                                  serving.isNotEmpty
                                      ? "Next Token"
                                      : "Start First Token",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                              if (serving.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: () => _showCancelDialog(
                                    context,
                                    serving.first,
                                    waiting,
                                  ),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  label: Text(
                                    "Cancel Serving Token",
                                    style: GoogleFonts.poppins(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              Text(
                                "Waiting List (${waiting.length})",
                                style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              ...waiting.map((doc) {
                                final token = doc.data() as Map<String, dynamic>;
                                final slot = slotsMap[token['slotId']] ?? {};
                                return Card(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    leading: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${token['queuePosition'] ?? 0}",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: navyBlue,
                                          ),
                                        ),
                                        Text(
                                          "Q#",
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      "Token ${token['tokenNumber']}",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(
                                          "Slot: ${slot['startTime'] ?? '--:--'} - ${slot['endTime'] ?? '--:--'}"
                                          "  |  Items: ${token['numberOfItems'] ?? 0}",
                                          style: const TextStyle(
                                              color: Colors.black87, fontSize: 10),
                                        ),
                                        Text(
                                          "Booked: ${_formatDateTime(token['createdAt'])}"
                                          "  |  Est. Wait: ${token['estimatedWaitMinutes'] ?? 0} min",
                                          style: const TextStyle(
                                              color: Colors.black54, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _priorityColor(token['priority']),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            (token['priority'] ?? 'normal').toString().toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () => _showCancelDialog(
                                            context,
                                            doc,
                                            waiting,
                                          ),
                                          tooltip: "Cancel Token",
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                              const SizedBox(height: 12),

                              ExpansionTile(
                                backgroundColor: Colors.grey.shade200,
                                title: Text(
                                  "Served History (${served.length})",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                children: served.isEmpty
                                    ? [
                                        const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Text(
                                            "No served tokens yet",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        )
                                      ]
                                    : served.map((doc) {
                                        final token = doc.data() as Map<String, dynamic>;
                                        final slot = slotsMap[token['slotId']] ?? {};
                                        return ListTile(
                                          leading: const Icon(Icons.check_circle,
                                              color: Colors.green, size: 16),
                                          title: Text(
                                            "Token ${token['tokenNumber']}",
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          subtitle: Text(
                                            "Slot: ${slot['startTime'] ?? '--:--'} - ${slot['endTime'] ?? '--:--'}"
                                            "  |  Served: ${_formatDateTime(token['endTime'])}",
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      }).toList(),
                              ),

                              ExpansionTile(
                                backgroundColor: Colors.red.shade50,
                                title: Text(
                                  "Cancelled History (${cancelled.length})",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                children: cancelled.isEmpty
                                    ? [
                                        const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Text(
                                            "No cancelled tokens yet",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        )
                                      ]
                                    : cancelled.map((doc) {
                                        final token = doc.data() as Map<String, dynamic>;
                                        final slot = slotsMap[token['slotId']] ?? {};
                                        return ListTile(
                                          leading: const Icon(Icons.cancel,
                                              color: Colors.redAccent, size: 16),
                                          title: Text(
                                            "Token ${token['tokenNumber']}",
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          subtitle: Text(
                                            "Slot: ${slot['startTime'] ?? '--:--'} - ${slot['endTime'] ?? '--:--'}"
                                            "  |  Cancelled: ${_formatDateTime(token['cancelledAt'])}",
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    DocumentSnapshot tokenDoc,
    List<DocumentSnapshot> waitingTokens,
  ) {
    final token = tokenDoc.data() as Map<String, dynamic>;
    final tokenNumber = token['tokenNumber'] ?? '---';
    final status = token['status'] ?? 'waiting';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Cancel Token?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to cancel Token $tokenNumber (${status.toUpperCase()})? This action cannot be undone.",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              "No, Keep It",
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cancelToken(context, tokenDoc, waitingTokens);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Yes, Cancel",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

Future<void> _cancelToken(
    BuildContext context,
    DocumentSnapshot tokenDoc,
    List<DocumentSnapshot> waitingTokens,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = tokenDoc.data() as Map<String, dynamic>;
      final slotId = token['slotId'] as String?;
      final wasServing = token['status'] == 'serving';
      
      print("🔧 DEBUG: Cancelling token ${tokenDoc.id}, slotId: '$slotId'");

      final batch = FirebaseFirestore.instance.batch();

      // Update token status to cancelled
      batch.update(tokenDoc.reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Decrement slot booked count
      if (slotId != null && slotId.isNotEmpty) {
        final slotRef = FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('branches')
            .doc(branchId)
            .collection('timeSlots')
            .doc(slotId);
        batch.update(slotRef, {
          'bookedCount': FieldValue.increment(-1),
        });
        print("🔧 DEBUG: Will decrement bookedCount for slot: $slotId (cancel)");
      } else {
        print("⚠️ WARNING: Cancel token ${tokenDoc.id} has no valid slotId");
      }

      // If serving was cancelled, auto-promote next waiting token
      if (wasServing && waitingTokens.isNotEmpty) {
        final nextDoc = waitingTokens.first;
        batch.update(nextDoc.reference, {
          'status': 'serving',
          'startTime': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print("✅ SUCCESS: Cancel batch committed for token ${tokenDoc.id}");

      messenger.showSnackBar(
        const SnackBar(content: Text("Token cancelled successfully")),
      );
    } catch (e) {
      print("❌ ERROR: Failed to cancel token ${tokenDoc.id}: $e");
      messenger.showSnackBar(
        SnackBar(content: Text("Failed to cancel token: $e")),
      );
    }
  }

  String _slotLabel(DocumentSnapshot doc, Map<String, Map<String, dynamic>> slotsMap) {
    final token = doc.data() as Map<String, dynamic>;
    final slot = slotsMap[token['slotId']] ?? {};
    return "${slot['startTime'] ?? '--:--'} - ${slot['endTime'] ?? '--:--'}";
  }

Color _priorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'senior':
        return Colors.amber;
      case 'high':
        return Colors.redAccent;
      case 'normal':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }
}

