import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qataar/services/auth_service.dart';
import 'admin_home_page.dart';
import 'category_selection_screen.dart';
import 'daily_counter.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String uid;
  final String email;

  const OtpVerifyScreen({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final otpController = TextEditingController();
  bool isLoading = false;
  bool otpSent = true;
  String? errorMsg;

  Future<void> _sendOtp() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    final result = await AuthService.sendEmailOtp(widget.uid, widget.email);
    setState(() {
      isLoading = false;
      otpSent = result['success'] ?? false;
      if (!otpSent) errorMsg = result['error'] ?? 'Failed to send OTP';
    });
  }

  Future<void> _verifyOtp() async {
    // Temporarily bypass OTP/2FA for testing
    const bool debugBypass2FA = false;

    if (debugBypass2FA) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
        '2fa_verified': true,
        'last_login': FieldValue.serverTimestamp(),
      });

      _navigateBasedOnRole();
      return;
    }

    if (otpController.text.length != 6) return;

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    final result = await AuthService.verifyEmailOtp(
        widget.uid, otpController.text.trim());

    setState(() {
      isLoading = false;
    });

    if (result['success'] == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
        '2fa_verified': true,
        'last_login': FieldValue.serverTimestamp(),
      });

      _navigateBasedOnRole();
    } else {
      errorMsg = result['message'] ?? 'Invalid OTP';
    }
  }

  Future<void> _navigateBasedOnRole() async {
    await DailyCounter.getCounter();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    final role = userData['role'] ?? 'user';

    if (role == 'admin') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminHomePage()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const CategorySelectionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 45),
                Image.asset("assets/logo_blue.png", height: 65),
                const SizedBox(height: 32),
                Text(
                  "Enter Code",
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Enter the 6-digit code sent to ${widget.email}",
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  obscureText: true,
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  onChanged: (value) {
                    if (value.length > 6) {
                      otpController.text = value.substring(0, 6);
                      otpController.selection = TextSelection.fromPosition(
                        TextPosition(offset: otpController.text.length),
                      );
                    }
                    if (errorMsg != null && value.isNotEmpty) {
                      setState(() {
                        errorMsg = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 6-digit code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF1C30A3), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),

                const SizedBox(height: 16),

                if (errorMsg != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMsg!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: isLoading || otpController.text.length != 6
                        ? null
                        : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C30A3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            "Verify OTP",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: isLoading ? null : _sendOtp,
                  child: Text(
                    "Resend OTP",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C30A3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }
}