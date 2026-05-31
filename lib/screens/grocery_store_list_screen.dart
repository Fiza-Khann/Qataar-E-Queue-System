import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/home_top_bar.dart';
import 'grocery_branch_list_screen.dart';
import 'grocery_my_token_screen.dart';

class GroceryStoreListScreen extends StatelessWidget {
  const GroceryStoreListScreen({super.key});

  final Color navyBlue = const Color(0xFF1C30A3);

  @override
  Widget build(BuildContext context) {
    final storesRef = FirebaseFirestore.instance.collection('stores');

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GroceryMyTokenScreen(
                storeId: '',
                branchId: '',
              ),
            ),
          );
        },
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HomeTopBar(),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: storesRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Something went wrong",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No stores available.",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  );
                }

                final stores = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    final data = store.data() as Map<String, dynamic>;

                    return Card(
                      color: navyBlue,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.store_mall_directory,
                          color: Colors.white,
                          size: 32,
                        ),
                        title: Text(
                          data['name'] ?? 'Unnamed Store',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          data['location'] ?? 'Unknown Location',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroceryBranchListScreen(
                                storeId: store.id,
                                storeName: data['name'] ?? 'Store',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
