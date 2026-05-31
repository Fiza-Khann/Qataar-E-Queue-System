import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_panel.dart';
import 'admin_categories_screen.dart';
import 'admin_grocery_screen.dart';
import 'admin_grocery_counters_screen.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> allItems = [];
  String firestoreName = "Admin";

  @override
  void initState() {
    super.initState();
    _loadAllItems();
    _loadAdminNameIfAny();
  }

  Future<void> _loadAdminNameIfAny() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['name'] != null) {
            setState(() {
              firestoreName = data['name'];
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAllItems() async {
    try {
      // Fetch all branches in one query, but do NOT fetch nested services.
      // Services will be fetched on-demand when a category branch is selected.
      final branchSnapshot =
          await FirebaseFirestore.instance.collectionGroup('branches').get();
      final List<Map<String, dynamic>> items = [];

      for (var branchDoc in branchSnapshot.docs) {
        final branchData = branchDoc.data();
        final branchName = branchData['name'] ?? "Branch";
        final parentDoc = branchDoc.reference.parent.parent;

        if (parentDoc == null) continue;
        final parentPath = parentDoc.path;

        if (parentPath.startsWith('categories/')) {
          final categoryId = parentDoc.id;
          items.add({
            'id': branchDoc.id,
            'name': branchName,
            'categoryId': categoryId,
            'branchId': branchDoc.id,
            'branchName': branchName,
            'type': 'category',
          });
        } else if (parentPath.startsWith('stores/')) {
          final storeId = parentDoc.id;
          final storeSnap = await parentDoc.get();
          final storeName = storeSnap.exists
              ? (storeSnap.data()?['name'] ?? 'Store')
              : 'Store';

          items.add({
            'id': branchDoc.id,
            'name': branchName,
            'storeId': storeId,
            'storeName': storeName,
            'branchId': branchDoc.id,
            'branchName': branchName,
            'type': 'grocery',
          });
        }
      }

      setState(() => allItems = items);
    } catch (e) {
      debugPrint("Error loading items: $e");
    }
  }

  Future<void> _showServicePicker(
    BuildContext context,
    Map<String, dynamic> branchItem,
  ) async {
    final categoryId = branchItem['categoryId'] as String;
    final branchId = branchItem['branchId'] as String;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            "Select Service",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .doc(categoryId)
                  .collection('branches')
                  .doc(branchId)
                  .collection('services')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = snapshot.data!.docs;
                if (services.isEmpty) {
                  return const Text("No services found for this branch.");
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final serviceData = service.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(
                        serviceData['name'] ?? 'Unnamed Service',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminPanel(
                              categoryId: categoryId,
                              branchId: branchId,
                              serviceId: service.id,
                            ),
                          ),
                        ).then((_) => _searchController.clear());
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    String first =
        parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
    String second =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  void _navigateToManage(BuildContext context, Map<String, dynamic> item) {
    if (item['type'] == 'grocery') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminGroceryCountersScreen(
            storeId: item['storeId'],
            storeName: item['storeName'],
            branchId: item['branchId'],
            branchName: item['branchName'],
          ),
        ),
      ).then((_) => _searchController.clear());
    } else {
      // For category branches, show service picker on-demand
      _showServicePicker(context, item);
    }
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha(76),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(38),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 30),
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1C30A3),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/logo.png', height: 40),
                    PopupMenuButton(
                      offset: const Offset(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) async {
                        if (value == 'logout') {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
                              (Route<dynamic> route) => false,
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'logout',
                          child: Text('Logout'),
                        ),
                      ],
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 16,
                        child: Text(
                          _getInitials(firestoreName),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (textEditingValue) {
                    final text = textEditingValue.text.trim();
                    if (text.isEmpty) return const Iterable.empty();
                    final lower = text.toLowerCase();
                    return allItems.where((item) {
                      final name =
                          (item['name'] ?? '').toString().toLowerCase();
                      final branch =
                          (item['branchName'] ?? '').toString().toLowerCase();
                      final store =
                          (item['storeName'] ?? '').toString().toLowerCase();
                      return name.contains(lower) ||
                          branch.contains(lower) ||
                          store.contains(lower);
                    }).take(10);
                  },
                  displayStringForOption: (option) {
                    if (option['type'] == 'grocery') {
                      return '${option['storeName']} > ${option['branchName']}';
                    }
                    return '${option['branchName']}';
                  },
                  onSelected: (selection) {
                    if (context.mounted) {
                      _navigateToManage(context, selection);
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                    _searchController.text = controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: controller.text.isNotEmpty
                            ? Colors.black
                            : Colors.grey,
                      ),
                      decoration: InputDecoration(
                        hintText: "Quick search branch...",
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Dashboard Cards
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Admin Dashboard",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C30A3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Manage your platform",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildDashboardCard(
                    context: context,
                    icon: Icons.folder,
                    title: "Manage Services",
                    subtitle: "Add, edit, or delete services",
                    color: const Color(0xFF1C30A3),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminCategoriesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDashboardCard(
                    context: context,
                    icon: Icons.local_grocery_store,
                    title: "Manage Grocery",
                    subtitle: "Add, edit, or delete grocery stores and branches",
                    color: const Color(0xFF6C63FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminGroceryScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDashboardCard(
                    context: context,
                    icon: Icons.qr_code_scanner,
                    title: "Scan Grocery QR",
                    subtitle: "Scan customer QR to mark token served",
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
