import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_services_screen.dart';

class AdminBranchesScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const AdminBranchesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  final Color navyBlue = const Color(0xFF1C30A3);

  Future<void> _addBranch(BuildContext context) async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final latController = TextEditingController();
    final longController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Add Branch",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  hintText: "Address",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  hintText: "City",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Latitude (e.g. 24.8138)",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: longController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Longitude (e.g. 67.0300)",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              final city = cityController.text.trim();
              final lat = double.tryParse(latController.text.trim()) ?? 0.0;
              final long = double.tryParse(longController.text.trim()) ?? 0.0;

              if (name.isNotEmpty && city.isNotEmpty) {
                final branchRef = FirebaseFirestore.instance
                    .collection('categories')
                    .doc(categoryId)
                    .collection('branches')
                    .doc();

                await branchRef.set({
                  'name': name,
                  'address': address,
                  'city': city,
                  'latitude': lat,
                  'longitude': long,
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
    final addressController = TextEditingController(text: currentData['address'] ?? '');
    final cityController = TextEditingController(text: currentData['city'] ?? '');
    final latController = TextEditingController(text: (currentData['latitude'] ?? '').toString());
    final longController = TextEditingController(text: (currentData['longitude'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Edit Branch",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  hintText: "Address",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  hintText: "City",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Latitude",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: longController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Longitude",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              final city = cityController.text.trim();
              final lat = double.tryParse(latController.text.trim()) ?? 0.0;
              final long = double.tryParse(longController.text.trim()) ?? 0.0;

              if (name.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('categories')
                    .doc(categoryId)
                    .collection('branches')
                    .doc(branchId)
                    .update({
                  'name': name,
                  'address': address,
                  'city': city,
                  'latitude': lat,
                  'longitude': long,
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
          "This will delete the branch and all its services. This action cannot be undone.",
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
          .collection('categories')
          .doc(categoryId)
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
          "Branches: ${categoryName.isNotEmpty ? categoryName[0].toUpperCase() + categoryName.substring(1).toLowerCase() : categoryName}",
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
            .collection('categories')
            .doc(categoryId)
            .collection('branches')
            .snapshots(),
        builder: (context, branchSnapshot) {
          if (!branchSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1C30A3)));
          }

          final branches = branchSnapshot.data!.docs;
          if (branches.isEmpty) {
            return Center(
              child: Text(
                "No branches found",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            );
          }

          final today = DateTime.now().toIso8601String().substring(0, 10);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tokens')
                .doc(today)
                .collection('bookings')
                .where('categoryId', isEqualTo: categoryId)
                .snapshots(),
            builder: (context, tokenSnapshot) {
              final Map<String, int> activeTokenCounts = {};
              if (tokenSnapshot.hasData) {
                for (var doc in tokenSnapshot.data!.docs) {
                  final status = doc['status'] as String?;
                  if (status == 'booked' || status == 'serving') {
                    final bId = doc['branchId'] as String?;
                    if (bId != null) {
                      activeTokenCounts[bId] = (activeTokenCounts[bId] ?? 0) + 1;
                    }
                  }
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: branches.length,
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  final data = branch.data() as Map<String, dynamic>;
                  final branchId = branch.id;
                  final activeCount = activeTokenCounts[branchId] ?? 0;

                  return Card(
                    color: navyBlue,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.apartment, color: Colors.white, size: 28),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['name'] ?? "Unnamed Branch",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (activeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Active: $activeCount",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: navyBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['address'] ?? "",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                          ),
                          Text(
                            data['city'] ?? "",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                          ),
                          if (activeCount == 0)
                            Text(
                              "No active tokens",
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                            onPressed: () => _editBranch(context, branchId, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteBranch(context, branchId),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminServicesScreen(
                              categoryId: categoryId,
                              categoryName: categoryName,
                              branchId: branchId,
                              branchName: data['name'] ?? "Unnamed Branch",
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

