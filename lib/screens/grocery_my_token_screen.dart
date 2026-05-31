import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'branch_map_screen.dart';
import '../services/qr_service.dart';
import '../services/route_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'grocery_store_list_screen.dart';

class GroceryMyTokenScreen extends StatefulWidget {
  final String storeId;
  final String branchId;

  const GroceryMyTokenScreen({
    super.key,
    required this.storeId,
    required this.branchId,
  });

  @override
  State<GroceryMyTokenScreen> createState() => _GroceryMyTokenScreenState();
}

class _GroceryMyTokenScreenState extends State<GroceryMyTokenScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int? _lastAppliedDuration;
  Duration _remaining = Duration.zero;
  Position? _currentPosition;
  int? _routeTimeSeconds;
  bool _notificationSent = false;
  bool _disposed = false;
  NavigatorState? _navigator;

  final Color navyBlue = const Color(0xFF1C30A3);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
  }

  @override
  void dispose() {
    _disposed = true;
    _animController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_disposed) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission denied');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Failed to get current location: $e');
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
        print('Fetched route time: $_routeTimeSeconds seconds');
      } else {
        print('No current position available for route calculation');
      }
    } catch (e) {
      print('Failed to fetch route time: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (widget.storeId.isEmpty || widget.branchId.isEmpty) {
      return _buildAllStoresTokenView(uid);
    }

    final tokensRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('branches')
        .doc(widget.branchId)
        .collection('tokens');

    return _buildTokenView(tokensRef, uid);
  }

  Widget _buildAllStoresTokenView(String? uid) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C30A3), Color(0xFF3F51B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'My Grocery Token',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('tokens')
                      .where('userId', isEqualTo: uid)
                      .where('status', whereIn: ['waiting', 'serving', 'missed'])
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No active grocery token.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    }
                    return _buildTokenContent(snapshot.data!.docs.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenView(CollectionReference tokensRef, String? uid) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C30A3), Color(0xFF3F51B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'My Grocery Token',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: tokensRef
                      .where('userId', isEqualTo: uid)
                      .where('status', whereIn: ['waiting', 'serving', 'missed'])
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No active grocery token.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    }
                    return _buildTokenContent(snapshot.data!.docs.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenContent(DocumentSnapshot tokenDoc) {
    final token = tokenDoc.data() as Map<String, dynamic>;
    final tokenStatus = token['status'] ?? 'waiting';
    final tokenNumber = token['tokenNumber'] ?? '---';
    final queuePosition = token['queuePosition'] ?? 0;
    final counterId = token['counterId'] as String?;
    final numberOfItems = token['numberOfItems'] ?? 5;
    final slotStartTime = token['slotStartTime'] ?? '--:--';
    final slotEndTime = token['slotEndTime'] ?? '--:--';
    final estimatedWaitMinutes = (token['estimatedWaitMinutes'] ?? 0) as num;

    final pathSegments = tokenDoc.reference.path.split('/');
    final docStoreId = pathSegments.length > 1 ? pathSegments[1] : widget.storeId;
    final docBranchId = pathSegments.length > 3 ? pathSegments[3] : widget.branchId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .doc(docStoreId)
          .collection('branches')
          .doc(docBranchId)
          .snapshots(),
      builder: (context, branchSnap) {
        Map<String, dynamic>? branchData;
        if (branchSnap.hasData && branchSnap.data!.exists) {
          branchData = branchSnap.data!.data() as Map<String, dynamic>;

          final geoPoint = branchData['location'];
          if (geoPoint != null && geoPoint is GeoPoint && _routeTimeSeconds == null) {
            _fetchRouteTime(geoPoint.latitude, geoPoint.longitude);
          }
        }

        final estimatedSeconds = estimatedWaitMinutes.toInt() * 60;
        if (_routeTimeSeconds != null &&
            estimatedSeconds <= _routeTimeSeconds! &&
            !_notificationSent) {
          NotificationService.showTravelTimeNotification();
          _notificationSent = true;
        }

        return _buildTokenContentBody(
          tokenStatus: tokenStatus,
          tokenNumber: tokenNumber,
          queuePosition: queuePosition,
          counterId: counterId,
          numberOfItems: numberOfItems,
          slotStartTime: slotStartTime,
          slotEndTime: slotEndTime,
          estimatedWaitMinutes: estimatedWaitMinutes,
          tokenDoc: tokenDoc,
          docStoreId: docStoreId,
          docBranchId: docBranchId,
          branchData: branchData,
        );
      },
    );
  }

  Widget _buildTokenContentBody({
    required String tokenStatus,
    required dynamic tokenNumber,
    required int queuePosition,
    required String? counterId,
    required int numberOfItems,
    required String slotStartTime,
    required String slotEndTime,
    required num estimatedWaitMinutes,
    required DocumentSnapshot tokenDoc,
    required String docStoreId,
    required String docBranchId,
    required Map<String, dynamic>? branchData,
  }) {
    // Scrollable content to avoid RenderFlex overflow on small screens.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (tokenStatus == 'missed') ...[
              Icon(Icons.warning_amber,
                  color: Colors.orangeAccent[400], size: 48),
              const SizedBox(height: 12),
              Text(
                'Token Missed',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.orangeAccent[400],
                ),
              ),
              Text(
                (tokenDoc.data() as Map<String, dynamic>)['missedReason'] ??
                    'Auto-skipped due to timeout.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.replay, size: 18),
                label: Text(
                  'Rebook Token',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent[400]),
              ),
              const SizedBox(height: 24),
            ] else
              Text(
                tokenStatus == 'serving'
                    ? "It's your turn!"
                    : 'You will be called shortly',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

            const SizedBox(height: 12),

            _tokenCard('Token Number', '$tokenNumber'),
            _tokenCard('Queue Position', '$queuePosition', isHighlight: true),
            _tokenCard('Items Count', '$numberOfItems'),
            _tokenCard('Time Slot', '$slotStartTime - $slotEndTime'),
            _tokenCard('Status', _capitalize(tokenStatus)),
            _tokenCard('Est. Wait', '~${estimatedWaitMinutes.toInt()} min'),
            _tokenCard(
              'Congestion',
              (tokenDoc.data() as Map<String, dynamic>)['congestionLevel'] ??
                  'Normal',
            ),
            if (counterId != null) _tokenCard('Counter', '$counterId'),
            const SizedBox(height: 7),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Show this QR to admin',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  QrImageView(
                    data: QrService.buildGroceryQrData(
                      storeId: docStoreId,
                      branchId: docBranchId,
                      docId: tokenDoc.id,
                      tokenNumber: '$tokenNumber',
                    ),
                    version: QrVersions.auto,
                    size: 110,
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 7),

            // Make View Map optional
            if (branchData != null) ...[
              Builder(builder: (context) {
                double? branchLat;
                double? branchLng;

                final dynamic geoPoint = branchData!['location'];
                if (geoPoint is GeoPoint) {
                  branchLat = geoPoint.latitude;
                  branchLng = geoPoint.longitude;
                } else {
                  branchLat = (branchData!['latitude'] as num?)?.toDouble();
                  branchLng = (branchData!['longitude'] as num?)?.toDouble();
                }

                if (branchLat == null || branchLng == null) {
                  return const SizedBox.shrink();
                }

                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (_currentPosition == null) {
                      await _getCurrentLocation();
                    }

                    if (_currentPosition != null) {
                      _routeTimeSeconds = await RouteService.getRouteDuration(
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
                  label: const Text(
                    'View Map',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }),
              const SizedBox(height: 7),
            ],

            SizedBox(
  width: double.infinity,
  height: 44,
  child: ElevatedButton.icon(
    onPressed: () => _showCancelDialog(context, tokenDoc),
    icon: const Icon(Icons.cancel_outlined, color: Colors.white),
    label: Text(
      'Cancel Token',
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.redAccent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),
),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }


  void _showCancelDialog(BuildContext context, DocumentSnapshot tokenDoc) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Token?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to cancel your token? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'No, Keep It',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cancelToken(context, tokenDoc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Yes, Cancel',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelToken(BuildContext context, DocumentSnapshot tokenDoc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = tokenDoc.data() as Map<String, dynamic>;
      final slotId = token['slotId'] as String?;

      final batch = FirebaseFirestore.instance.batch();

      batch.update(tokenDoc.reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (slotId != null && slotId.isNotEmpty) {
        final slotRef = tokenDoc.reference.parent.parent!
            .collection('timeSlots')
            .doc(slotId);
        batch.update(slotRef, {
          'bookedCount': FieldValue.increment(-1),
        });
      }

      await batch.commit();

      messenger.showSnackBar(
        const SnackBar(content: Text('Token cancelled successfully')),
      );

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GroceryStoreListScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to cancel token: $e')),
      );
    }
  }

  Widget _tokenCard(String label, String value, {bool isHighlight = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.orangeAccent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isHighlight ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.white : Colors.black87,
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

