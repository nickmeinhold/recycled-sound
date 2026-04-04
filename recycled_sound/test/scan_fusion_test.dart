import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recycled_sound/features/scanner/data/device_catalog.dart';
import 'package:recycled_sound/features/scanner/data/embedding_search.dart';
import 'package:recycled_sound/features/scanner/data/scan_fusion.dart';

void main() {
  group('ScanFusion', () {
    late ScanFusion fusion;

    setUp(() {
      fusion = ScanFusion(
        embeddingSearch: EmbeddingSearch.instance,
        deviceCatalog: DeviceCatalog.instance,
      );
    });

    test('builds result from Vision API only when no CLIP matches', () {
      // With no loaded embeddings, CLIP search returns empty → vision-only path
      // We need loaded assets for real search, so test the vision-only fallback
      final result = fusion.fuse(
        clipEmbedding: Float32List(512), // zero vector → no matches
        visionResult: {
          'rawOcrText': 'phonak audeo',
          'rawLabels': ['hearing aid', 'behind the ear'],
          'brand': {'value': 'Phonak', 'confidence': 85},
          'model': {'value': 'Audéo', 'confidence': 70},
        },
        imageUrl: 'https://example.com/test.jpg',
        scanId: 'test-001',
      );

      // Should fall back to vision-only since EmbeddingSearch isn't loaded
      // (assertion disabled in test mode, returns empty results)
      expect(result.scanId, 'test-001');
      expect(result.imageUrl, 'https://example.com/test.jpg');
      // Brand should come from OCR detection
      expect(result.brand.value, isNotEmpty);
      expect(result.rawLabels, hasLength(2));
    });

    test('confidence matrix produces expected ranges', () {
      // Verify the confidence scoring logic described in the plan:
      // CLIP high + OCR confirms → brand 95%, model 90%, specs 75%
      // CLIP high + no OCR → brand 85%, model 80%, specs 70%
      // OCR only → brand 80%, model 40%, specs 30%
      // Neither → brand 20%, model 15%, specs 10%

      // We can't easily inject mock search results without the full pipeline,
      // but we verify the vision-only fallback confidence:
      final result = fusion.fuse(
        clipEmbedding: Float32List(512),
        visionResult: {
          'rawOcrText': '',
          'rawLabels': <String>[],
        },
        imageUrl: '',
        scanId: 'test-002',
      );

      // No signals at all → lowest confidence
      expect(result.brand.confidence, lessThanOrEqualTo(30));
      expect(result.model.confidence, lessThanOrEqualTo(20));
      expect(result.year.confidence, lessThanOrEqualTo(15));
    });

    test('type inference from labels works correctly', () {
      final result = fusion.fuse(
        clipEmbedding: Float32List(512),
        visionResult: {
          'rawOcrText': '',
          'rawLabels': ['hearing aid', 'behind the ear', 'medical device'],
        },
        imageUrl: '',
        scanId: 'test-003',
      );

      expect(result.type.value, contains('BTE'));
    });
  });
}
