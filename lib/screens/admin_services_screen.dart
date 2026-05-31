import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_panel.dart';

class AdminServicesScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  final String branchId;
  final String branchName;

  const AdminServicesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.branchId,
    required this.branchName,
  });

  final Color navyBlue = const Color(0xFF1C30A3);

  Future<void> _addService(BuildContext context) async {
    final nameController = TextEditingController();
    final avgTimeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Add Service",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: "Service Name",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avgTimeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Avg Service Time (seconds)",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              final avgTime =
                  int.tryParse(avgTimeController.text.trim()) ?? 180;

              if (name.isNotEmpty) {
                final serviceRef = FirebaseFirestore.instance
                    .collection('categories')
                    .doc(categoryId)
                    .collection('branches')
                    .doc(branchId)
                    .collection('services')
                    .doc();

                await serviceRef.set({
                  'name': name,
                  'avgServiceTimeSec': avgTime,
                  'recentDurations': [],
                  'currentToken': 0,
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: navyBlue,
            ),
            child: Text(
              "Add",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editService(
    BuildContext context,
    String serviceId,
    Map<String, dynamic> currentData,
  ) async {
    final nameController =
        TextEditingController(text: currentData['name'] ?? '');

    final avgTimeController = TextEditingController(
      text: (currentData['avgServiceTimeSec'] ?? '').toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Edit Service",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: "Service Name",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avgTimeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Avg Service Time (seconds)",
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              final avgTime =
                  int.tryParse(avgTimeController.text.trim()) ?? 180;

              if (name.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('categories')
                    .doc(categoryId)
                    .collection('branches')
                    .doc(branchId)
                    .collection('services')
                    .doc(serviceId)
                    .update({
                  'name': name,
                  'avgServiceTimeSec': avgTime,
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: navyBlue,
            ),
            child: Text(
              "Save",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(
    BuildContext context,
    String serviceId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Delete Service?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "This will delete the service and all its token data cannot be recovered. This action cannot be undone.",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
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
          .collection('services')
          .doc(serviceId)
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
          "Services: $branchName",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _addService(context),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .doc(categoryId)
            .collection('branches')
            .doc(branchId)
            .collection('services')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1C30A3),
              ),
            );
          }

          final services = snapshot.data!.docs;

          if (services.isEmpty) {
            return Center(
              child: Text(
                "No services found",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final data =
                  service.data() as Map<String, dynamic>;
              final serviceId = service.id;

              return Card(
                color: navyBlue,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.miscellaneous_services,
                    color: Colors.white,
                    size: 28,
                  ),
                  title: Text(
                    data['name'] ?? "Unnamed Service",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    "Avg Time: ${data['avgServiceTimeSec'] ?? 'N/A'} sec",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),

                  // FIXED TRAILING
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () => _editService(
                          context,
                          serviceId,
                          data,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _deleteService(context, serviceId),
                      ),
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminPanel(
                                  categoryId: categoryId,
                                  branchId: branchId,
                                  serviceId: serviceId,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Tokens",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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