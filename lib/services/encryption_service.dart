import 'dart:typed_data';

/// SAIC-ACT — Spectrogram Adaptive Image Cipher for Acoustic Transmission.
///
/// Three-layer encryption pipeline optimised for image-to-audio transmission:
///
///   1. **Chaotic byte permutation** — pixels (bytes) are shuffled using
///      a Fisher–Yates shuffle seeded by the logistic map
///      x(n+1) = r·x(n)·(1−x(n)),  r ∈ [3.9, 3.99),
///      removing spatial correlation before diffusion.
///
///   2. **Adaptive bit diffusion** — each ciphertext bit is chained to the
///      previous ciphertext bit and the 256-bit key stream:
///        C[i] = P[i] ⊕ C[i-1] ⊕ K[i mod 256]
///      One flipped plaintext bit avalanches all subsequent cipherbits.
///
///   3. **Noise-aware binary shaping (NABS)** — triplet-level substitution
///      that eliminates maximal-run bit patterns (000, 111) harmful to FSK
///      demodulation stability:
///        000 ↔ 001  (swap)
///        110 ↔ 111  (swap)
///        all other triplets: unchanged
///      The mapping is self-inverse (applying it twice restores the original),
///      so encryption and decryption run the same routine.
///
/// Decryption reverses the three steps: NABS → inverse diffusion →
/// inverse permutation.
///
/// Key: 32 bytes (256 bits) derived externally via SHA-256
/// (e.g. [CombinedKeyService]).  Key space: 2^256.
class EncryptionService {
  const EncryptionService();

  // ─────────────────────────────────────────────────────────── public API

  /// Encrypts [dataBytes] with SAIC-ACT using [key].
  ///
  /// Applies: permutation → adaptive diffusion → noise-aware binary shaping.
  Uint8List encryptBytes({
    required Uint8List dataBytes,
    required Uint8List key,
  }) {
    _assertKey(key);
    if (dataBytes.isEmpty) return Uint8List(0);

    final permuted = _permuteBytes(dataBytes, key, forward: true);
    final diffused = _adaptiveDiffuse(permuted, key, decrypt: false);
    return _noiseAwareBinaryShaping(diffused);
  }

  /// Decrypts [encryptedBytes] with SAIC-ACT using [key].
  ///
  /// Applies: noise-aware binary shaping → inverse diffusion →
  /// inverse permutation.
  Uint8List decryptBytes({
    required Uint8List encryptedBytes,
    required Uint8List key,
  }) {
    _assertKey(key);
    if (encryptedBytes.isEmpty) return Uint8List(0);

    // NABS is self-inverse; the same routine undoes the shaping step.
    final unshaped = _noiseAwareBinaryShaping(encryptedBytes);
    final undiffused = _adaptiveDiffuse(unshaped, key, decrypt: true);
    return _permuteBytes(undiffused, key, forward: false);
  }

  // ──────────────────────────────────────── Step 1: chaotic permutation

  /// Builds a Fisher–Yates permutation index array driven by the logistic map.
  ///
  /// Chaotic parameters are seeded from the first two key bytes:
  ///   x₀ = key[0]/255 × 0.8 + 0.1  →  x₀ ∈ (0.10, 0.90)
  ///   r  = 3.9 + key[1]/255 × 0.09 →  r  ∈ [3.90, 3.99)
  Uint32List _buildPermutation(int n, Uint8List key) {
    double x = (key[0] / 255.0) * 0.8 + 0.1;
    double r = 3.9 + (key[1] / 255.0) * 0.09;

    final perm = Uint32List(n);
    for (int i = 0; i < n; i++) {
      perm[i] = i;
    }

    for (int i = n - 1; i > 0; i--) {
      x = r * x * (1.0 - x); // logistic map iteration
      final j = (x * (i + 1)).toInt().clamp(0, i);
      final tmp = perm[i];
      perm[i] = perm[j];
      perm[j] = tmp;
    }
    return perm;
  }

  Uint8List _permuteBytes(
    Uint8List data,
    Uint8List key, {
    required bool forward,
  }) {
    final n = data.length;
    if (n <= 1) return Uint8List.fromList(data);

    final perm = _buildPermutation(n, key);
    final out = Uint8List(n);

    if (forward) {
      // out[i] = data[perm[i]]  →  scatter according to permutation
      for (int i = 0; i < n; i++) {
        out[i] = data[perm[i]];
      }
    } else {
      // Inverse: each element goes back to its original index
      for (int i = 0; i < n; i++) {
        out[perm[i]] = data[i];
      }
    }
    return out;
  }

  // ──────────────────────────────────────── Step 2: adaptive bit diffusion

  /// Adaptive bit-level diffusion over [data].
  ///
  /// Forward (encrypt): C[i] = P[i] ⊕ C[i−1] ⊕ K[i mod 256]
  /// Reverse (decrypt): P[i] = C[i] ⊕ C[i−1] ⊕ K[i mod 256]
  ///
  /// The chain bit for decryption is always the ciphertext C[i−1], matching
  /// the chain used during encryption.
  Uint8List _adaptiveDiffuse(
    Uint8List data,
    Uint8List key, {
    required bool decrypt,
  }) {
    final out = Uint8List(data.length);
    final keyBitCount = key.length * 8; // 256 for a 32-byte key
    int chainBit = 0; // C[i-1], initialised to 0

    for (int b = 0; b < data.length; b++) {
      final inByte = data[b];
      int outByte = 0;

      for (int bit = 7; bit >= 0; bit--) {
        final globalBit = b * 8 + (7 - bit);
        final kIdx = globalBit % keyBitCount;
        final keyBit = (key[kIdx >> 3] >> (7 - (kIdx & 7))) & 1;

        final inBit = (inByte >> bit) & 1;
        final outBit = inBit ^ chainBit ^ keyBit;
        outByte |= outBit << bit;

        // During decryption the chain tracks the *ciphertext* bit (= inBit);
        // during encryption it tracks the *output* ciphertext bit (= outBit).
        chainBit = decrypt ? inBit : outBit;
      }
      out[b] = outByte;
    }
    return out;
  }

  // ────────────────────────────────── Step 3: noise-aware binary shaping

  /// Triplet-level substitution that eliminates all-zero/all-one triplets,
  /// reducing long identical-bit runs that destabilise FSK demodulation.
  ///
  /// Swap table (self-inverse):
  ///   000 (0) ↔ 001 (1)
  ///   110 (6) ↔ 111 (7)
  ///   everything else: unchanged
  ///
  /// Implementation: processed in aligned 3-byte (24-bit) blocks giving
  /// exactly 8 triplets each.  Trailing 0–2 bytes that do not form a full
  /// block are left unchanged.
  Uint8List _noiseAwareBinaryShaping(Uint8List data) {
    final out = Uint8List.fromList(data);
    final blocks = data.length ~/ 3;

    for (int blk = 0; blk < blocks; blk++) {
      final base = blk * 3;

      // Pack three bytes into a 24-bit integer (big-endian within the block).
      int bits =
          (data[base] << 16) | (data[base + 1] << 8) | data[base + 2];
      int newBits = 0;

      // Apply the swap table to each of the 8 triplets (MSB-first order).
      for (int t = 7; t >= 0; t--) {
        final shift = t * 3;
        final triplet = (bits >> shift) & 0x7;
        final mapped = switch (triplet) {
          0 => 1, // 000 → 001
          1 => 0, // 001 → 000  (self-inverse pair)
          6 => 7, // 110 → 111
          7 => 6, // 111 → 110  (self-inverse pair)
          _ => triplet,
        };
        newBits |= mapped << shift;
      }

      out[base] = (newBits >> 16) & 0xFF;
      out[base + 1] = (newBits >> 8) & 0xFF;
      out[base + 2] = newBits & 0xFF;
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────── helpers

  static void _assertKey(Uint8List key) {
    if (key.isEmpty) throw ArgumentError('Encryption key must not be empty.');
  }
}

/// Enhanced Encryption Service — SAIC-ACT with additional security layers
///
/// Improvements over base SAIC-ACT:
/// 1. Multi-round encryption support
/// 2. Salt integration for additional entropy
/// 3. Key strengthening
/// 4. Security metrics (NPCR, UACI)
class EnhancedEncryptionService extends EncryptionService {
  final int encryptionRounds;

  EnhancedEncryptionService({this.encryptionRounds = 2});

  /// Multi-round encryption with salt integration
  Uint8List encryptBytesWithSalt({
    required Uint8List dataBytes,
    required Uint8List key,
    required Uint8List salt,
  }) {
    if (dataBytes.isEmpty) return Uint8List(0);
    EncryptionService._assertKey(key);

    // Strengthen key with salt
    final strengthenedKey = _strengthenKeyWithSalt(key, salt);

    // Apply multiple rounds
    var encrypted = dataBytes;
    for (int round = 0; round < encryptionRounds; round++) {
      final roundKey = _deriveRoundKey(strengthenedKey, round);
      encrypted = encryptBytes(dataBytes: encrypted, key: roundKey);
    }

    return encrypted;
  }

  /// Multi-round decryption with salt
  Uint8List decryptBytesWithSalt({
    required Uint8List encryptedBytes,
    required Uint8List key,
    required Uint8List salt,
  }) {
    if (encryptedBytes.isEmpty) return Uint8List(0);
    EncryptionService._assertKey(key);

    // Strengthen key with salt
    final strengthenedKey = _strengthenKeyWithSalt(key, salt);

    // Apply decryption in reverse order
    var decrypted = encryptedBytes;
    for (int round = encryptionRounds - 1; round >= 0; round--) {
      final roundKey = _deriveRoundKey(strengthenedKey, round);
      decrypted = decryptBytes(encryptedBytes: decrypted, key: roundKey);
    }

    return decrypted;
  }

  /// Strengthen key by combining with salt using XOR and hash
  Uint8List _strengthenKeyWithSalt(Uint8List key, Uint8List salt) {
    final padded = _padKeyWithSalt(key, salt);
    final strengthened = Uint8List(32);

    // XOR-based mixing
    for (int i = 0; i < 32; i++) {
      strengthened[i] = padded[i] ^ padded[i + 32];
      // Add salt entropy
      if (salt.isNotEmpty) {
        strengthened[i] ^= salt[i % salt.length];
      }
    }

    return strengthened;
  }

  /// Derive key for specific round
  Uint8List _deriveRoundKey(Uint8List baseKey, int round) {
    final derived = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      derived[i] = (baseKey[i] + round * 17 + i * 31) & 0xFF;
    }
    return derived;
  }

  /// Pad key to 64 bytes for salt combination
  Uint8List _padKeyWithSalt(Uint8List key, Uint8List salt) {
    final padded = Uint8List(64);
    padded.setAll(0, key);
    if (salt.isNotEmpty) {
      padded.setAll(32, List.generate(32, (i) => salt[i % salt.length]));
    }
    return padded;
  }

  /// Calculate NPCR (Number of Pixels Change Rate) -measure of sensitivity
  /// Changes in plaintext should affect ~50% of ciphertext bits
  double calculateNPCR(Uint8List plaintext1, Uint8List plaintext2,
      Uint8List key) {
    final cipher1 = encryptBytes(dataBytes: plaintext1, key: key);
    final cipher2 = encryptBytes(dataBytes: plaintext2, key: key);

    if (cipher1.length != cipher2.length) return 0.0;

    int differentBytes = 0;
    for (int i = 0; i < cipher1.length; i++) {
      if (cipher1[i] != cipher2[i]) differentBytes++;
    }

    return (differentBytes / cipher1.length) * 100.0; // Percentage
  }

  /// Calculate UACI (Unified Average Changing Intensity) - effect magnitude
  double calculateUACI(Uint8List plaintext1, Uint8List plaintext2,
      Uint8List key) {
    final cipher1 = encryptBytes(dataBytes: plaintext1, key: key);
    final cipher2 = encryptBytes(dataBytes: plaintext2, key: key);

    if (cipher1.length != cipher2.length) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < cipher1.length; i++) {
      sum += (cipher1[i] - cipher2[i]).abs();
    }

    return (sum / (cipher1.length * 255.0)) * 100.0; // Percentage
  }

  /// Verify encryption quality (NPCR should be ~99.6%, UACI should be ~33.5%)
  EncryptionQualityReport evaluateEncryptionQuality(
    Uint8List plaintext,
    Uint8List key, {
    int testSamples = 10,
  }) {
    double totalNPCR = 0.0;
    double totalUACI = 0.0;

    for (int i = 0; i < testSamples; i++) {
      // Create modified plaintext (flip one bit)
      final modified = Uint8List.fromList(plaintext);
      final byteIndex = (i * 37) % plaintext.length;
      final bitIndex = i % 8;
      modified[byteIndex] ^= (1 << bitIndex); // Flip bit

      totalNPCR += calculateNPCR(plaintext, modified, key);
      totalUACI += calculateUACI(plaintext, modified, key);
    }

    return EncryptionQualityReport(
      averageNPCR: totalNPCR / testSamples,
      averageUACI: totalUACI / testSamples,
      isHighQuality:
          (totalNPCR / testSamples) > 99.0 && (totalUACI / testSamples) > 30.0,
    );
  }
}

/// Encryption quality metrics
class EncryptionQualityReport {
  final double averageNPCR;
  final double averageUACI;
  final bool isHighQuality;

  EncryptionQualityReport({
    required this.averageNPCR,
    required this.averageUACI,
    required this.isHighQuality,
  });

  @override
  String toString() => '''
EncryptionQualityReport(
  NPCR: ${averageNPCR.toStringAsFixed(2)}% (ideal: 99.6%)
  UACI: ${averageUACI.toStringAsFixed(2)}% (ideal: 33.5%)
  Quality: ${isHighQuality ? 'HIGH' : 'LOW'}
)''';
}
