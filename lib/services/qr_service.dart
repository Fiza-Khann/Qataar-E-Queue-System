import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class QrService {
  static String buildGroceryQrData({
    required String storeId,
    required String branchId,
    required String docId,
    required String tokenNumber,
  }) {
    final data = {
      'type': 'grocery',
      'storeId': storeId,
      'branchId': branchId,
      'docId': docId,
      'tokenNumber': tokenNumber,
    };
    return jsonEncode(data);
  }

  static Map<String, dynamic>? parseQrData(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['type'] == null || decoded['docId'] == null) {
        return null;
      }
      return decoded;
    } catch (e) {
      return null;
    }
  }

  static Future<String> markTokenServed(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final docId = (data['docId'] as String?)?.trim();

    if (type == null || docId == null || docId.isEmpty) {
      return 'Invalid QR data';
    }

    if (type != 'grocery') {
      return 'Invalid token type';
    }

    try {
      final storeId = (data['storeId'] as String?)?.trim();
      final branchId = (data['branchId'] as String?)?.trim();
      if (storeId == null || storeId.isEmpty || branchId == null || branchId.isEmpty) {
        return 'Missing store or branch in QR data';
      }

      final docRef = FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('branches')
          .doc(branchId)
          .collection('tokens')
          .doc(docId);

      final snap = await docRef.get();
      if (!snap.exists) return 'Token not found';

      final tokenData = snap.data() as Map<String, dynamic>;
      final status = tokenData['status'] as String? ?? '';
      final slotId = tokenData['slotId'] as String?;

      if (status == 'served') return 'Token already served';

      final batch = FirebaseFirestore.instance.batch();

      batch.update(docRef, {
        'status': 'served',
        'endTime': FieldValue.serverTimestamp(),
      });

      // Decrement slot booked count when token is served
      if (slotId != null && slotId.isNotEmpty) {
        final slotRef = FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('branches')
            .doc(branchId)
            .collection('timeSlots')
            .doc(slotId);
        batch.update(slotRef, {
          'bookedCount': FieldValue.increment(-1),
        });
      }

      await batch.commit();

      return 'Token marked as served';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
