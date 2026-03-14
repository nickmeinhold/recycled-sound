import '../providers/scanner_providers.dart';
import 'models/scan_result.dart';

/// Repository for the hearing aid scanner feature.
///
/// In the MVP, returns mock data. When Firebase is configured, this will:
/// 1. Upload the image to Firebase Storage
/// 2. Call the `analyzeHearingAid` Cloud Function
/// 3. Return the parsed result
/// 4. Submit corrections to the `scans/{scanId}/corrections` subcollection
class ScannerRepository {
  /// Analyze a hearing aid photo.
  ///
  /// [imagePath] is the local file path from the camera/gallery.
  Future<ScanResult> analyzeImage(String imagePath) async {
    // TODO: Wire up Firebase Storage upload + Cloud Function call
    //
    // final ref = FirebaseStorage.instance
    //     .ref('scans/${FirebaseAuth.instance.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    // await ref.putFile(File(imagePath));
    // final imageUrl = await ref.getDownloadURL();
    //
    // final callable = FirebaseFunctions.instance.httpsCallable('analyzeHearingAid');
    // final result = await callable.call({'imageUrl': imageUrl, 'userId': uid});
    // return ScanResult.fromJson(result.data);

    // Simulate network delay
    await Future<void>.delayed(const Duration(seconds: 3));
    return ScanResult.mock();
  }

  /// Submit corrections for a completed scan.
  Future<void> submitCorrections({
    required String scanId,
    required List<Correction> corrections,
    required String userId,
    required String userRole,
  }) async {
    // TODO: Wire up Firestore
    //
    // final batch = FirebaseFirestore.instance.batch();
    // for (final correction in corrections) {
    //   final ref = FirebaseFirestore.instance
    //       .collection('scans')
    //       .doc(scanId)
    //       .collection('corrections')
    //       .doc();
    //   batch.set(ref, {
    //     ...correction.toJson(),
    //     'correctedBy': userId,
    //     'correctedByRole': userRole,
    //   });
    // }
    // await batch.commit();

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  /// Create a device in the register from a scan result.
  Future<String> addToRegister(ScanResult result) async {
    // TODO: Wire up Firestore
    //
    // final ref = FirebaseFirestore.instance.collection('devices').doc();
    // await ref.set({
    //   'brand': result.brand.value,
    //   'model': result.model.value,
    //   'type': result.type.value,
    //   ...
    //   'qaStatus': 'pending_qa',
    //   'status': 'donated',
    //   'scanId': result.scanId,
    //   'createdAt': FieldValue.serverTimestamp(),
    // });
    // return ref.id;

    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'mock-device-id';
  }
}
