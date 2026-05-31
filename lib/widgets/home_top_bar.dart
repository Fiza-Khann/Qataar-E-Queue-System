import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';

class HomeTopBar extends StatefulWidget {
  final bool showSearch;
  final List<Map<String, dynamic>>? searchItems;
  final String searchHint;
  final String Function(Map<String, dynamic>)? displayStringForOption;
  final void Function(Map<String, dynamic>)? onSearchSelected;

  const HomeTopBar({
    super.key,
    this.showSearch = false,
    this.searchItems,
    this.searchHint = "what are you looking for?",
    this.displayStringForOption,
    this.onSearchSelected,
  });

  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  String firestoreName = 'User';
  TextEditingController searchController = TextEditingController();

  final Color navyBlue = const Color(0xFF1C30A3);

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            firestoreName = userDoc['name'] ?? 'User';
          });
        }
      }
    }
  }

  String toTitleCase(String text) {
    return text
        .split(' ')
        .map((str) =>
    str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    String first = parts.isNotEmpty ? parts[0][0] : '';
    String second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C30A3), Color(0xFF3A4ED1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 45,
              ),
              PopupMenuButton(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) async {
                  if (value == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  } else if (value == 'logout') {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (Route<dynamic> route) => false,
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  child: Text(
                    _getInitials(firestoreName),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hi, ${toTitleCase(firestoreName)}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Time is Our First Priority',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          if (widget.showSearch && widget.searchItems != null) ...[
            const SizedBox(height: 12),
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                return widget.searchItems!.where((item) =>
                (item['name'] ?? '')
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()) ||
                    (item['location'] ?? '')
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: widget.displayStringForOption ??
                  (option) => '${option['name']} (${option['location']})',
              onSelected: (Map<String, dynamic> selection) {
                if (widget.onSearchSelected != null) {
                  widget.onSearchSelected!(selection);
                }
                searchController.clear();
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                searchController = controller;
                return StatefulBuilder(
                  builder: (context, setInnerState) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: controller.text.isNotEmpty ? Colors.black : Colors.grey,
                      ),
                      onChanged: (text) {
                        setInnerState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

