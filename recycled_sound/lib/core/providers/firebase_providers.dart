import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scanner/data/scanner_repository.dart';

/// Provides the scanner repository.
///
/// When Firebase is configured, this will also provide:
/// - FirebaseAuth.instance
/// - FirebaseFirestore.instance
/// - FirebaseStorage.instance
final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository();
});
