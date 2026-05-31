import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'branch_map_screen.dart';
import 'grocery_my_token_screen.dart';
import 'grocery_store_list_screen.dart';
import '../services/qr_service.dart';
import '../services/route_service.dart';

class GroceryTokenScreen extends StatefulWidget {
  final String storeId;
  final String branchId;
  final String tokenId;

  const GroceryTokenScreen({
    super.key,
    required this.storeId,
    required this.branchId,
    required this.tokenId,
  });

  @override
  State<GroceryTokenScreen> createState() => _GroceryTokenScreenState();
}

class _GroceryTokenScreenState extends State<GroceryTokenScreen> {
  final Color navyBlue = const Color(0xFF1C30A3);

  Position? _currentPosition;
  int? _routeTimeSeconds;
  bool _disposed = false;
  NavigatorState? _navigator;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_disposed) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("Location permission denied");
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Failed to get current location: $e");
    }
  }

  Future<void> _fetchRouteTime(double branchLat, double branchLng) async {
    if (_disposed) return;
    try {
      if (_currentPosition == null) {
        await _getCurrentLocation();
      }

      if (_currentPosition != null) {
        _routeTimeSeconds = await RouteService.getRouteDuration(
          _currentPosition!.longitude,
          _currentPosition!.latitude,
          branchLng,
          branchLat,
        );
        print("Fetched route time: $_routeTimeSeconds seconds");
      } else {
        print("No current position available for route calculation");
      }
    } catch (e) {
      print("Failed to fetch route time: $e");
    }
  }

@override
  Widget build(BuildContext context) {
    debugPrint('📥 GroceryTokenScreen build tokenRef=${'stores/${widget.storeId}/branches/${widget.branchId}/tokens/${widget.tokenId}'}');
    final tokenRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('branches')
        .doc(widget.branchId)
        .collection('tokens')
        .doc(widget.tokenId);

    final branchRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('branches')
        .doc(widget.branchId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const GroceryStoreListScreen(),
          ),
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: navyBlue,
        body: SafeArea(
              child: StreamBuilder<DocumentSnapshot>(
            stream: tokenRef.snapshots(),
            builder: (context, snapshot) {
              // Wait until token doc exists; Firestore may need a moment after booking.
if (!snapshot.hasData || !snapshot.data!.exists) {
                debugPrint('⏳ GroceryTokenScreen waiting: hasData=${snapshot.hasData} exists=${snapshot.hasData ? snapshot.data!.exists : 'n/a'} tokenId=${widget.tokenId}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Token is being prepared…',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'If this takes too long, go back and try booking again.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }



final tokenDoc = snapshot.data!;
              debugPrint('✅ GroceryTokenScreen tokenDoc exists path=${tokenDoc.reference.path} id=${tokenDoc.id}');
              final token = tokenDoc.data() as Map<String, dynamic>;
              final tokenNumber = token['tokenNumber'] ?? '---';
              final queuePosition = token['queuePosition'] ?? 0;
final status = token['status'] ?? 'waiting';
              debugPrint('🎟️ GroceryTokenScreen tokenNumber=$tokenNumber status=$status slotId=${token['slotId']} slotStart=${token['slotStartTime'] ?? token['slotStart']}');
              final numberOfItems = token['numberOfItems'] ?? 0;
              final estimatedWaitMinutes = token['estimatedWaitMinutes'] ?? 0;
              final slotStartTime = token['slotStartTime'] ?? '--:--';
              final slotEndTime = token['slotEndTime'] ?? '--:--';

              return StreamBuilder<DocumentSnapshot>(
                stream: branchRef.snapshots(),
                builder: (context, branchSnap) {
                  Map<String, dynamic>? branchData;
                  double? branchLat;
                  double? branchLng;

                  if (branchSnap.hasData && branchSnap.data!.exists) {
                    branchData = branchSnap.data!.data() as Map<String, dynamic>;

                    // Support GeoPoint location field
                    final geoPoint = branchData['location'];
                    if (geoPoint != null && geoPoint is GeoPoint) {
                      branchLat = geoPoint.latitude;
                      branchLng = geoPoint.longitude;
                    } else {
                      // Support separate latitude/longitude fields
                      branchLat = (branchData['latitude'] as num?)?.toDouble();
                      branchLng = (branchData['longitude'] as num?)?.toDouble();
                    }

                    // Auto-fetch route time when branch data is available
                    if (branchLat != null &&
                        branchLng != null &&
                        _routeTimeSeconds == null) {
                      _fetchRouteTime(branchLat, branchLng);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Token Generated!",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Your grocery shopping token has been created",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Token Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                "TOKEN NUMBER",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$tokenNumber",
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: navyBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              _infoRow("Queue Position", "$queuePosition"),
                              _infoRow("Items Count", "$numberOfItems"),
                              _infoRow("Status", _capitalize(status)),
                              _infoRow(
                                "Est. Wait Time",
                                "~$estimatedWaitMinutes min",
                              ),
                              _infoRow(
                                "Time Slot",
                                "$slotStartTime - $slotEndTime",
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 6),
                              Text(
                                "Show this QR to admin",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              QrImageView(
                                data: QrService.buildGroceryQrData(
                                  storeId: widget.storeId,
                                  branchId: widget.branchId,
                                  docId: widget.tokenId,
                                  tokenNumber: "$tokenNumber",
                                ),
                                version: QrVersions.auto,
                                size: 90,
                                backgroundColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroceryMyTokenScreen(
                                    storeId: widget.storeId,
                                    branchId: widget.branchId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.dashboard_outlined, size: 20),
                            label: Text(
                              "View Live Dashboard",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: navyBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // View Map Button
                        if (branchLat != null && branchLng != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              // Get current location if not already fetched
                              if (_currentPosition == null) {
                                await _getCurrentLocation();
                              }

                              if (_currentPosition != null) {
                                // Fetch route duration
                                _routeTimeSeconds =
                                    await RouteService.getRouteDuration(
                                  _currentPosition!.longitude,
                                  _currentPosition!.latitude,
                                  branchLng!,
                                  branchLat!,
                                );
                              }

                              if (!context.mounted) return;
                              _navigator!.push(
                                MaterialPageRoute(
                                  builder: (_) => BranchMapScreen(
                                    latitude: branchLat!,
                                    longitude: branchLng!,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map, size: 20),
                            label: const Text("View Map",
                                style: TextStyle(fontSize: 14)),
                          ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GroceryStoreListScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          child: Text(
                            "Back to Home",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

