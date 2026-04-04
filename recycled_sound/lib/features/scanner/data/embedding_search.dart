import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// On-device CLIP embedding search engine.
///
/// Loads pre-computed 512-dimensional CLIP embeddings from a binary asset
/// and performs cosine similarity search against a query vector.
///
/// Binary format (little-endian):
///   [uint32 entry_count] [uint32 dims]
///   [entry_count * dims float32 values, row-major]
///
/// Performance: ~1,927 dot products of 512 floats = ~1M multiply-adds,
/// typically <50ms on any modern phone.
class EmbeddingSearch {
  EmbeddingSearch._();

  late final int _entryCount;
  late final int _dims;

  /// Row-major embedding matrix: _entryCount rows x _dims columns.
  late final Float32List _embeddings;

  bool _loaded = false;

  /// Whether the embeddings have been loaded from the asset bundle.
  bool get isLoaded => _loaded;

  /// Number of image embeddings in the database.
  int get entryCount => _entryCount;

  /// Embedding dimensionality (expected: 512 for CLIP ViT-B/32).
  int get dims => _dims;

  /// Singleton instance — embeddings are loaded once and cached.
  static final EmbeddingSearch instance = EmbeddingSearch._();

  /// Load embeddings from the bundled binary asset.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> loadFromAsset({String assetPath = 'assets/device_db.bin'}) async {
    if (_loaded) return;

    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    // Read header: entry_count (uint32 LE) + dims (uint32 LE)
    final header = bytes.buffer.asByteData(byteData.offsetInBytes);
    _entryCount = header.getUint32(0, Endian.little);
    _dims = header.getUint32(4, Endian.little);

    // Read embedding data starting after 8-byte header
    final dataOffset = byteData.offsetInBytes + 8;
    final dataLength = _entryCount * _dims;
    _embeddings = bytes.buffer.asFloat32List(dataOffset, dataLength);

    _loaded = true;
  }

  /// Find the top-K most similar embeddings to [queryVector].
  ///
  /// The query vector should be L2-normalised (as produced by CLIP encoding).
  /// Since all stored embeddings are also L2-normalised, cosine similarity
  /// reduces to a simple dot product.
  ///
  /// Returns results sorted by descending similarity score.
  List<SimilarityResult> findSimilar(
    Float32List queryVector, {
    int topK = 5,
  }) {
    if (!_loaded) return const [];
    assert(queryVector.length == _dims, 'Query must be $_dims-dimensional');

    // Compute dot product against every stored embedding
    final scores = Float32List(_entryCount);
    for (var i = 0; i < _entryCount; i++) {
      final offset = i * _dims;
      var dot = 0.0;
      for (var j = 0; j < _dims; j++) {
        dot += queryVector[j] * _embeddings[offset + j];
      }
      scores[i] = dot;
    }

    // Find top-K by partial sort
    final indices = List<int>.generate(_entryCount, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    final k = topK.clamp(0, _entryCount);
    return [
      for (var i = 0; i < k; i++)
        SimilarityResult(
          embeddingIndex: indices[i],
          score: scores[indices[i]],
        ),
    ];
  }
}

/// A single similarity search result.
class SimilarityResult {
  const SimilarityResult({
    required this.embeddingIndex,
    required this.score,
  });

  /// Index into the embedding database (maps to catalog's embeddingIndex).
  final int embeddingIndex;

  /// Cosine similarity score (dot product of L2-normalised vectors).
  /// Range: -1.0 to 1.0, where 1.0 = identical.
  final double score;

  @override
  String toString() => 'SimilarityResult(index=$embeddingIndex, score=${score.toStringAsFixed(4)})';
}
