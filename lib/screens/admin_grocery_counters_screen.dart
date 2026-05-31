import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_grocery_tokens_screen.dart';

class AdminGroceryCountersScreen extends StatelessWidget {
  final String storeId;
  final String storeName;
  final String branchId;
  final String branchName;

  const AdminGroceryCountersScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.branchId,
    required this.branchName,
  });

  final Color navyBlue = const Color(0xFF1C30A3);

  Future<void> _addCounter(BuildContext context) async {
    final nameController = TextEditingController();
    bool isActive = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            "Add Counter",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Counter Name",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        isActive = value ?? true;
                      });
                    },
                  ),
                  Text(
                    "Active",
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final counterRef = FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .collection('branches')
                      .doc(branchId)
                      .collection('counters')
                      .doc();

                  await counterRef.set({
                    'name': name,
                    'isActive': isActive,
                  });

                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
              child: Text("Add", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCounter(
    BuildContext context,
    String counterId,
    Map<String, dynamic> currentData,
  ) async {
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    bool isActive = currentData['isActive'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            "Edit Counter",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Counter Name",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        isActive = value ?? true;
                      });
                    },
                  ),
                  Text(
                    "Active",
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .collection('branches')
                      .doc(branchId)
                      .collection('counters')
                      .doc(counterId)
                      .update({
                    'name': name,
                    'isActive': isActive,
                  });

                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
              child: Text("Save", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCounter(BuildContext context, String counterId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Delete Counter?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "This will delete the counter. Existing tokens will not be affected.",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('branches')
          .doc(branchId)
          .collection('counters')
          .doc(counterId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: Text(
          "Counters: $branchName",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _addCounter(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('branches')
            .doc(branchId)
            .collection('counters')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1C30A3)));
          }

          final counters = snapshot.data!.docs;
          if (counters.isEmpty) {
            return Center(
              child: Text(
                "No counters found",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: counters.length,
            itemBuilder: (context, index) {
              final counter = counters[index];
              final data = counter.data() as Map<String, dynamic>;
              final counterId = counter.id;
              final isActive = data['isActive'] ?? true;

              return Card(
                color: isActive ? navyBlue : Colors.grey.shade400,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(
                    isActive ? Icons.check_circle : Icons.cancel,
                    color: Colors.white,
                    size: 28,
                  ),
                  title: Text(
                    data['name'] ?? "Unnamed Counter",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    isActive ? "Active" : "Inactive",
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                        onPressed: () => _editCounter(context, counterId, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteCounter(context, counterId),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminGroceryTokensScreen(
                                storeId: storeId,
                                storeName: storeName,
                                branchId: branchId,
                                branchName: branchName,
                                counterId: counterId,
                                counterName: data['name'] ?? 'Unnamed Counter',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          "Tokens",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

