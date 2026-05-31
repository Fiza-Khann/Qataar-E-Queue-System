import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_grocery_counters_screen.dart';

class AdminGroceryBranchesScreen extends StatelessWidget {
  final String storeId;
  final String storeName;

  const AdminGroceryBranchesScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final Color navyBlue = const Color(0xFF1C30A3);

  Future<void> _addBranch(BuildContext context) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Add Branch",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: "Branch Name",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                hintText: "Location",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
              final location = locationController.text.trim();
              if (name.isNotEmpty) {
                final branchRef = FirebaseFirestore.instance
                    .collection('stores')
                    .doc(storeId)
                    .collection('branches')
                    .doc();

                await branchRef.set({
                  'name': name,
                  'location': location,
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
            child: Text("Add", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _editBranch(
    BuildContext context,
    String branchId,
    Map<String, dynamic> currentData,
  ) async {
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    final locationController = TextEditingController(text: currentData['location'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Edit Branch",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: "Branch Name",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                hintText: "Location",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
              final location = locationController.text.trim();

              if (name.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('stores')
                    .doc(storeId)
                    .collection('branches')
                    .doc(branchId)
                    .update({
                  'name': name,
                  'location': location,
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
            child: Text("Save", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBranch(BuildContext context, String branchId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Delete Branch?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "This will delete the branch and all its tokens and time slots. This action cannot be undone.",
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
          "Branches: $storeName",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _addBranch(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('branches')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1C30A3)));
          }

          final branches = snapshot.data!.docs;
          if (branches.isEmpty) {
            return Center(
              child: Text(
                "No branches found",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            );
          }

          final today = DateTime.now().toIso8601String().substring(0, 10);

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: branches.length,
            itemBuilder: (context, index) {
              final branch = branches[index];
              final data = branch.data() as Map<String, dynamic>;
              final branchId = branch.id;

              return Card(
                color: navyBlue,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .collection('branches')
                      .doc(branchId)
                      .collection('tokens')
                      .where('date', isEqualTo: today)
                      .snapshots(),
                  builder: (context, tokenSnapshot) {
                    int activeCount = 0;
                    if (tokenSnapshot.hasData) {
                      for (var doc in tokenSnapshot.data!.docs) {
                        final status = doc['status'] as String?;
                        if (status == 'waiting' || status == 'serving') {
                          activeCount++;
                        }
                      }
                    }

                    return ListTile(
                      leading: const Icon(Icons.apartment, color: Colors.white, size: 28),
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Give branch name all remaining space, and keep it from being squeezed by the active badge.
                          Expanded(
                            child: Text(
                              data['name'] ?? "Unnamed Branch",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          if (activeCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "$activeCount",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['location'] ?? "",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                          ),
                          if (activeCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                "No active tokens",
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                      trailing: LayoutBuilder(
                        builder: (context, constraints) {
                          return ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                  onPressed: () => _editBranch(context, branchId, data),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteBranch(context, branchId),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: FittedBox(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AdminGroceryCountersScreen(
                                              storeId: storeId,
                                              storeName: storeName,
                                              branchId: branchId,
                                              branchName: data['name'] ?? 'Unnamed Branch',
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          "Counters",
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

