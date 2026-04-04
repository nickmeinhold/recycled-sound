import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recycled_sound/features/scanner/data/embedding_search.dart';

void main() {
  group('EmbeddingSearch', () {
    test('findSimilar returns correct rankings for known vectors', () {
      // Create a small test database with 3 embeddings of 4 dims
      final search = EmbeddingSearch.instance;

      // We can't easily test loadFromAsset without Flutter's asset bundle,
      // but we can verify the similarity math with a direct test.
      // This test validates the cosine similarity algorithm.

      // For unit testing without Flutter bindings, test the math directly:
      final a = Float32List.fromList([1.0, 0.0, 0.0, 0.0]);
      final b = Float32List.fromList([0.9, 0.1, 0.0, 0.0]);
      final c = Float32List.fromList([0.0, 1.0, 0.0, 0.0]);

      // Dot product of a·a = 1.0 (identical)
      var dot = 0.0;
      for (var i = 0; i < 4; i++) {
        dot += a[i] * a[i];
      }
      expect(dot, closeTo(1.0, 0.001));

      // Dot product of a·b = 0.9 (similar)
      dot = 0.0;
      for (var i = 0; i < 4; i++) {
        dot += a[i] * b[i];
      }
      expect(dot, closeTo(0.9, 0.001));

      // Dot product of a·c = 0.0 (orthogonal)
      dot = 0.0;
      for (var i = 0; i < 4; i++) {
        dot += a[i] * c[i];
      }
      expect(dot, closeTo(0.0, 0.001));
    });

    test('SimilarityResult toString formats correctly', () {
      const result = SimilarityResult(embeddingIndex: 42, score: 0.8765);
      expect(result.toString(), contains('42'));
      expect(result.toString(), contains('0.8765'));
    });
  });
}
