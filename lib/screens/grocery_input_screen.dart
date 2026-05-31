import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../enums/priority_level.dart';
import 'grocery_suggested_slots_screen.dart' as slots_screen;
import 'grocery_my_token_screen.dart';

// enum PriorityLevel { regular, senior, urgent } - use import from lib/enums/priority_level.dart

class GroceryInputScreen extends StatefulWidget {
  final String storeId;
  final String branchId;
  final String branchName;

  const GroceryInputScreen({
    super.key,
    required this.storeId,
    required this.branchId,
    required this.branchName,
  });

  @override
  State<GroceryInputScreen> createState() => _GroceryInputScreenState();
}

class _GroceryInputScreenState extends State<GroceryInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemsController = TextEditingController();
  String? _selectedSlotId;
  PriorityLevel _selectedPriority = PriorityLevel.regular;
  bool _isLoadingPriority = true;

final Color navyBlue = const Color(0xFF1C30A3);

  @override
  void initState() {
    super.initState();
    _loadUserPriority();
  }

  Future<void> _loadUserPriority() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final priorityStr = userDoc['priority'] as String? ?? 'normal';
          setState(() {
            _selectedPriority = _convertToPriorityLevel(priorityStr);
            _isLoadingPriority = false;
          });
        } else {
          setState(() {
            _isLoadingPriority = false;
          });
        }
      } else {
        setState(() {
          _isLoadingPriority = false;
        });
      }
    } catch (e) {
      print('Error loading priority: $e');
      setState(() {
        _isLoadingPriority = false;
      });
    }
  }

  PriorityLevel _convertToPriorityLevel(String priority) {
    switch (priority) {
      case 'urgent':
        return PriorityLevel.urgent;
      case 'senior':
        return PriorityLevel.senior;
      default:
        return PriorityLevel.regular;
    }
  }

  @override
  void dispose() {
    _itemsController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _computeLiveSlots() async {
    final db = FirebaseFirestore.instance;
    final branchRef = db.collection('stores').doc(widget.storeId).collection('branches').doc(widget.branchId);
    final slotsRef = branchRef.collection('timeSlots');
    final tokensRef = branchRef.collection('tokens');
    
    // Get slots
    final slotsSnapshot = await slotsRef.orderBy('startTime').get();
    final slots = slotsSnapshot.docs.map((doc) => {
      'slotId': doc.id,
      ...doc.data() as Map<String, dynamic>,
    }).toList();

    // Get today's live tokens
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final tokensSnapshot = await tokensRef
        .where('date', isEqualTo: todayStr)
        .where('status', whereIn: ['waiting', 'serving'])
        .get();
    final tokensList = tokensSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    // Compute live availability (reuse suggested screen logic)
    final computedSlots = <Map<String, dynamic>>[];
    for (var slot in slots) {
      final slotId = slot['slotId'] as String;
      final capacity = (slot['capacity'] ?? 20) as int;
      
      // Live token count for this slot
      final slotTokens = tokensList.where((t) => (t['slotId'] ?? '') == slotId).toList();
      final liveBooked = slotTokens.length;
      final liveAvailable = capacity - liveBooked;
      
      computedSlots.add({
        'slotId': slotId,
        'startTime': slot['startTime'] ?? '--:--',
        'endTime': slot['endTime'] ?? '--:--',
        'capacity': capacity,
        'currentAvailable': liveAvailable,
      });
    }

    return {'slots': computedSlots};
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
      floatingActionButton: _ViewMyTokenButton(
        storeId: widget.storeId,
        branchId: widget.branchId,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Shopping Details",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.branchName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Approx number of items
              Text(
                "Approximate Number of Items",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _itemsController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter number of items";
                  }
                  final n = int.tryParse(value);
                  if (n == null || n < 1) {
                    return "Enter a valid number (minimum 1)";
                  }
                  if (n > 200) {
                    return "Maximum 200 items allowed";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: "e.g. 10, 20, 35",
                  prefixIcon: const Icon(Icons.shopping_basket_outlined),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
const SizedBox(height: 24),

              // Priority Selection
              Text(
                "Priority Level",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<PriorityLevel>(
                  value: _selectedPriority,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  hint: Text(
                    "Select priority",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  icon: const Icon(Icons.flag, color: Color(0xFF1C30A3)),
                  items: PriorityLevel.values.map((priority) {
                    String label;
                    IconData icon;
                    Color color;
                    switch (priority) {
                      case PriorityLevel.urgent:
                        label = 'Urgent - I need quick service';
                        icon = Icons.priority_high;
                        color = Colors.red;
                        break;
                      case PriorityLevel.senior:
                        label = 'Senior/Citizen - Priority';
                        icon = Icons.elderly;
                        color = Colors.orange;
                        break;
                      case PriorityLevel.regular:
                      default:
                        label = 'Regular - Standard queue';
                        icon = Icons.person;
                        color = Colors.blue;
                    }
                    return DropdownMenuItem<PriorityLevel>(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPriority = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Senior and Urgent users get priority in queue",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Preferred time slot - DROPDOWN MENU
              Text(
                "Preferred Time Slot",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: _computeLiveSlots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        "Error loading live slots: ${snapshot.error}",
                        style: GoogleFonts.poppins(color: Colors.red),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Text(
                        "No time slots available.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      );
                    }

                    final data = snapshot.data!;
                    final slotsWithLiveData = data['slots'] as List<Map<String, dynamic>>;
                    if (slotsWithLiveData.isEmpty) {
                      return Text(
                        "No available time slots.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedSlotId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        hint: Text(
                          "Select a time slot",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        icon: const Icon(Icons.access_time, color: Color(0xFF1C30A3)),
                        items: slotsWithLiveData.map((slotData) {
                          final slotId = slotData['slotId'] as String;
                          final start = slotData['startTime'] ?? '--:--';
                          final end = slotData['endTime'] ?? '--:--';
                          final capacity = slotData['capacity'] as int;
                          final currentAvailable = slotData['currentAvailable'] as int;
                          final isFull = currentAvailable <= 0;

                          return DropdownMenuItem<String>(
                            value: slotId,
                            enabled: !isFull,
                            child: Row(
                              children: [
                                Icon(
                                  isFull ? Icons.block : Icons.check_circle_outline,
                                  size: 18,
                                  color: isFull ? Colors.red : Colors.green,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "$start - $end",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: isFull ? Colors.grey : Colors.black87,
                                      decoration: isFull ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  isFull
                                      ? "FULL"
                                      : "$currentAvailable avail",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isFull
                                        ? Colors.red
                                        : currentAvailable <= 3
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSlotId = value;
                          });
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Text(
                "Slots marked FULL are not selectable",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Find Best Slots",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
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
  }

  Future<void> _proceed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final numberOfItems = int.parse(_itemsController.text);
    final preferredSlotId = _selectedSlotId ?? '';

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => slots_screen.GrocerySuggestedSlotsScreen(
            storeId: widget.storeId,
            branchId: widget.branchId,
            branchName: widget.branchName,
            numberOfItems: numberOfItems,
            preferredSlotId: preferredSlotId,
            priority: _selectedPriority,
          ),
        ),
      );
    }
  }
}

/// Floating action button to view current grocery token
class _ViewMyTokenButton extends StatelessWidget {
  final String storeId;
  final String branchId;

  const _ViewMyTokenButton({
    required this.storeId,
    required this.branchId,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroceryMyTokenScreen(
              storeId: storeId,
              branchId: branchId,
            ),
          ),
        );
      },
      backgroundColor: const Color(0xFF1C30A3),
      icon: const Icon(Icons.confirmation_number, color: Colors.white),
      label: Text(
        "My Token",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
