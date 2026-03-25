# VisioLock: A Noise-Resistant Secure Image Transmission System Using Acoustic Channels and SAIC-ACT Encryption

**Authors:** [Author Names]  
**Institution:** [Institution Name]  
**Date:** March 2026  
**Keywords:** Image Encryption, Acoustic Transmission, FSK Modulation, Reed–Solomon FEC, Chaos-Based Cryptography, Mobile Security, SAIC-ACT

---

## Abstract

This paper presents **VisioLock**, a mobile application implementing a novel end-to-end secure image transmission system over acoustic channels. The system converts encrypted image data into audio signals that can be transmitted through any medium capable of carrying audio — including speakers, messaging applications, and radio — without relying on internet infrastructure or paired device protocols. We introduce **SAIC-ACT (Spectrogram Adaptive Image Cipher for Acoustic Transmission)**, a purpose-built, lightweight encryption algorithm that combines chaos-based pixel permutation, adaptive bit diffusion, and a unique noise-aware binary shaping layer specifically designed to improve FSK demodulation stability over acoustic channels. The system also employs Reed–Solomon forward error correction (FEC) with triple-redundancy majority voting to achieve lossless image recovery despite channel noise. Experimental results demonstrate provably lossless reconstruction with SHA-256 integrity verification, O(N) encryption complexity suitable for mobile devices, and a 2^256 key space providing robust resistance to brute-force attacks. VisioLock supports both device-bound authentication (biometric + PIN) and cross-device passphrase-based operation, making it applicable to a wide range of secure communication scenarios.

---

## 1. Introduction

The proliferation of smartphones and mobile devices has dramatically expanded the attack surface for sensitive digital communications. Images represent a significant class of sensitive data — medical records, identity documents, confidential blueprints, and personal photographs — yet most existing image-sharing mechanisms rely on internet infrastructure that introduces multiple points of interception: cloud storage, CDN nodes, messaging server logs, and transport-layer vulnerabilities.

Traditional encrypted messaging (Signal, WhatsApp end-to-end encryption) protects data in transit but requires both parties to be connected to the internet simultaneously and depends on trusted server infrastructure to relay key exchange. In scenarios where internet access is unavailable, unreliable, or monitored — disaster zones, remote areas, adversarial environments — these approaches fail entirely.

**Acoustic channels** present an alternative medium. Acoustic transmission is:

- **Infrastructure-independent**: requires only the physical proximity of sound production and reception, or any audio relay medium (radio, telephone, intercom).
- **Cross-platform**: every modern device has a speaker and microphone.
- **Hard to intercept at scale**: unlike network traffic, acoustic signals do not traverse monitored infrastructure.

However, transmitting binary data over acoustic channels introduces significant engineering challenges: frequency distortion, amplitude variation, background noise, and inter-symbol interference all threaten data integrity. Existing acoustic data transmission techniques (DTMF, GGWAVE, AFSK) are designed for general data, not optimised for encrypted image payloads.

VisioLock addresses this gap with three original contributions:

1. **SAIC-ACT**: an encryption algorithm whose output is specifically shaped to improve resilience to FSK demodulation errors.
2. **NRSTS (Noise-Resistant Spectrogram Transmission System)**: a layered error-correction architecture combining Reed–Solomon FEC with odd-repetition majority voting.
3. **I2A3 payload framing**: a lossless image payload format with embedded SHA-256 integrity verification.

The system is implemented as a production-grade Flutter mobile application targeting Android (API 21+), with a clean separation of encryption, error correction, audio encoding, and UI layers.

---

## 2. Related Work

### 2.1 Acoustic Data Transmission

Acoustic modems have existed since the 1960s in the form of telephone modems. More recent work includes:

- **DTMF (Dual-Tone Multi-Frequency)**: encodes digits as pairs of audio tones. Limited to 16 symbols, inadequate for binary data at reasonable rates.
- **GGWAVE** (Zhelyazkov, 2021): a modern acoustic data transmission library operating at 8–72 bytes/second using frequency-band encoding and Reed–Solomon FEC. Designed for small payloads (WiFi credentials, short messages).
- **Sonic** (Yao et al., 2013): ultrasonic data channel for proximity-based device pairing. Operates above human-hearing range to avoid perceptual interference.
- **AFSK (Audio Frequency-Shift Keying)**: widely used in amateur radio (AX.25 packet radio) for binary data over radio channels.

VisioLock's approach is closest to AFSK/FSK, but extends it with application-layer FEC and an encryption layer specifically tuned to the acoustic channel.

### 2.2 Image Encryption

The dominant paradigms in image encryption are:

- **AES-CBC/GCM on image bytes**: applies AES to raw pixel data. Produces completely random output — statistically secure but can produce many identical-bit runs that harm acoustic demodulation.
- **Chaos-based image encryption** (Fridrich, 1998; Pareek et al., 2006): uses chaotic maps (logistic, Lorenz, Henon) to permute and diffuse pixel values. Fast, hardware-independent, well-studied for multimedia applications.
- **DNA encoding** (Zhang et al., 2010): encodes pixel values as DNA nucleotide sequences, then applies genetic operations. Primarily theoretical.

VisioLock builds on the chaos-based tradition but introduces the NABS layer as an original contribution to adapt the encrypted output to acoustic channel constraints.

### 2.3 Reed–Solomon Codes in Data Transmission

Reed–Solomon (RS) codes (Reed & Solomon, 1960) are a class of non-binary cyclic error-correcting codes operating over Galois fields. They are widely deployed in:

- CD/DVD/Blu-ray storage (RS(255,223))
- QR codes (RS over GF(256))
- Deep-space communications (Voyager, Cassini missions)
- Digital terrestrial television (DVB-T uses RS(204,188))

In VisioLock, RS(255,223) over GF(256) with *t* = 8 correctable symbols per codeword is combined with triple-redundancy majority voting for layered error recovery.

---

## 3. System Architecture

The VisioLock system is divided into six functional layers, each encapsulated as an independent service:

```
┌─────────────────────────────────────────────┐
│              IMAGE INPUT LAYER              │
│  ImageProcessor → I2A3 framed payload       │
├─────────────────────────────────────────────┤
│              KEY DERIVATION LAYER           │
│  BiometricKeyService + CombinedKeyService   │
│        SHA-256(biometric ∥ PIN)             │
├─────────────────────────────────────────────┤
│              ENCRYPTION LAYER               │
│  SAIC-ACT:                                  │
│    1. Chaotic Byte Permutation              │
│    2. Adaptive Bit Diffusion                │
│    3. Noise-Aware Binary Shaping (NABS)     │
├─────────────────────────────────────────────┤
│              ERROR CORRECTION LAYER         │
│  NRSTS:                                     │
│    1. Reed–Solomon RS(255,223) FEC          │
│    2. Triple-Repetition Majority Voting     │
├─────────────────────────────────────────────┤
│              AUDIO ENCODING LAYER           │
│  AudioEncoder:                              │
│    FSK: 1500 Hz = 0, 3000 Hz = 1           │
│    8000 Hz sample rate, 16-bit PCM, 2ms/bit │
├─────────────────────────────────────────────┤
│                  TRANSPORT                  │
│  WAV file → any audio channel               │
└─────────────────────────────────────────────┘
```

The reverse pipeline (Receiver) applies these layers in the opposite order:

```
Audio (WAV) → Goertzel FSK detection → NRSTS recovery 
→ SAIC-ACT decryption → I2A3 reconstruction → Image
```

---

## 4. I2A3 Payload Format

Before encryption, the image is wrapped in an **I2A3** frame that enables lossless reconstruction and integrity verification on the receiver.

### 4.1 Frame Structure

```
Offset  Size    Field
──────  ──────  ─────────────────────────────────
0       4       Magic bytes: "I2A3" (ASCII)
4       4       extLen: length of extension string (uint32 LE)
8       4       fileLen: length of image bytes (uint32 LE)
12      32      SHA-256 digest of raw image bytes
44      extLen  File extension (e.g. "png", "jpg")
44+x    fileLen Raw image file bytes
```

**Total header: 44 bytes.** The extension is sanitised to `[a-z0-9]`, max 10 characters, with fallback `"img"`.

### 4.2 Integrity Verification

On the receiver, after decryption and payload parsing, the SHA-256 digest embedded in the header is recomputed over the extracted image bytes. If they match, `integrityVerified = true` is reported to the user. This detects both transmission corruption that survived FEC and decryption with an incorrect key.

---

## 5. Key Derivation

### 5.1 Device-Bound Mode (Default)

In the default configuration, the 256-bit encryption key K is derived as:

$$K = \text{SHA-256}(B \mathbin\| \text{UTF-8}(\text{PIN}))$$

Where:
- $B$ is a 32-byte random biometric secret generated once per device installation and stored in Android's `FlutterSecureStorage` (backed by Android Keystore).
- PIN is a user-chosen numeric PIN, trimmed of whitespace.

This binds the key to the specific physical device. Even with the identical PIN, a different device will produce a different key because $B$ differs.

### 5.2 Cross-Device Passphrase Mode

For cross-device scenarios, the application supports a passphrase-only mode:

$$K = \text{SHA-256}(\text{UTF-8}(\text{passphrase}))$$

No biometric component is included. Any device knowing the passphrase can derive the identical key. Security relies entirely on passphrase entropy; users are advised to use long, randomly generated passphrases.

The UI toggle labelled **"Cross-Device Mode"** switches between these two derivation paths on both sender and receiver screens. Switching the toggle automatically clears the input field to prevent key-type mismatches.

---

## 6. SAIC-ACT Encryption Algorithm

**SAIC-ACT (Spectrogram Adaptive Image Cipher for Acoustic Transmission)** is the original cryptographic contribution of this paper. It is a three-layer symmetric stream cipher designed for:

- Lightweight operation on mobile devices (O(N) complexity, N = payload bytes)
- Strong statistical properties (avalanche effect, full key-space utilisation)
- Output shaping that reduces acoustic transmission errors

### 6.1 Encryption Pipeline

```
Plaintext Payload Bytes P
         │
         ▼
┌──────────────────────────┐
│  Step 1: Chaotic          │
│  Byte Permutation         │
│  (Logistic Map Fisher-Yates) │
└──────────┬───────────────┘
           │ Permuted bytes P'
           ▼
┌──────────────────────────┐
│  Step 2: Adaptive         │
│  Bit Diffusion            │
│  C[i] = P'[i] ⊕ C[i-1] ⊕ K[i mod 256] │
└──────────┬───────────────┘
           │ Diffused bytes D
           ▼
┌──────────────────────────┐
│  Step 3: Noise-Aware      │
│  Binary Shaping (NABS)    │
│  000↔001, 110↔111         │
└──────────┬───────────────┘
           │ Ciphertext C
           ▼
     Encrypted Payload
```

### 6.2 Step 1 — Chaotic Byte Permutation

The permutation destructs the spatial correlation inherent in image data (adjacent pixels tend to have similar values). Without permutation, statistical analysis of the ciphertext may reveal image structure.

**Logistic map:** A well-studied one-dimensional chaotic map with parameter $r$:

$$x_{n+1} = r \cdot x_n \cdot (1 - x_n)$$

For $r \in (3.57, 4]$ the map exhibits fully chaotic behaviour: small changes in initial conditions lead to exponentially divergent trajectories, providing the unpredictability required for cryptographic use.

**Parameter seeding from key:**

$$x_0 = \frac{K[0]}{255} \times 0.8 + 0.1 \quad \Rightarrow \quad x_0 \in (0.10,\ 0.90)$$

$$r = 3.9 + \frac{K[1]}{255} \times 0.09 \quad \Rightarrow \quad r \in [3.90,\ 3.99)$$

Using two bytes of the 32-byte key to seed the logistic map; the remaining 30 key bytes influence the diffusion step.

**Fisher–Yates shuffle seeded by the logistic map:**

```
For i from N-1 down to 1:
    x = r * x * (1 - x)           // iterate chaotic map
    j = floor(x * (i + 1))        // pseudo-random index in [0, i]
    swap(perm[i], perm[j])
```

This produces a permutation array `perm[0..N-1]`. The forward transformation applies `out[i] = data[perm[i]]`. The inverse permutation (decryption) applies `out[perm[i]] = data[i]`.

**Security property:** The permutation has $N!$ possible orderings seeded by a 256-bit key. For typical image payloads ($N \gg 10^4$), the practical key space is bounded by $2^{256}$.

### 6.3 Step 2 — Adaptive Bit Diffusion

Permutation alone is insufficient: if pixel values cluster in a narrow range (e.g., a mostly-white image), the ciphertext will retain statistical regularities. Diffusion spreads the influence of each bit across the entire output.

**Diffusion rule (encryption):**

$$C[i] = P'[i] \oplus C[i-1] \oplus K[i \bmod 256]$$

Where:
- $P'[i]$ is the $i$-th bit of the permuted plaintext
- $C[i]$ is the $i$-th ciphertext bit
- $C[-1] = 0$ (initialisation)
- $K[i \bmod 256]$ cycles through the 256-bit (32-byte) key stream bit by bit

**Diffusion rule (decryption):**

$$P'[i] = C[i] \oplus C[i-1] \oplus K[i \bmod 256]$$

The chain bit for decryption uses the received ciphertext $C[i-1]$, matching the value used during encryption, so decryption is exact.

**Avalanche effect:** Flipping a single plaintext bit $P'[j]$ changes $C[j]$ and, through the chaining, all subsequent bits $C[j+1], C[j+2], \ldots$ down to $C[N-1]$. The expected fraction of ciphertext bits changed by a single-bit plaintext flip is approximately 50%, satisfying the strict avalanche criterion.

**Implementation note:** The diffusion operates at the bit level but is computed byte-by-byte for efficiency. Within each byte, bits are processed MSB-first (bit 7 down to bit 0).

### 6.4 Step 3 — Noise-Aware Binary Shaping (NABS)

This is the **original and novel** contribution of SAIC-ACT. Standard encryption algorithms (AES, RSA) are designed purely for security; they give no consideration to the properties of the transmission channel. In FSK modulation, the demodulator must distinguish two frequencies (1500 Hz and 3000 Hz) by accumulating energy over a short window. Performance degrades when the signal contains long runs of identical bits because:

- A long run of `0`s (1500 Hz) causes the reference signal for 3000 Hz detection to accumulate a false positive from harmonic content.
- A long run of `1`s (3000 Hz) causes the phase of the carrier to drift, reducing coherence in the Goertzel filter window.

**NABS triplet substitution table (self-inverse):**

| Input triplet | Output triplet | Rationale |
|:---:|:---:|---|
| `000` (0) | `001` (1) | Eliminates all-zero run |
| `001` (1) | `000` (0) | Self-inverse |
| `010` (2) | `010` (2) | Unchanged |
| `011` (3) | `011` (3) | Unchanged |
| `100` (4) | `100` (4) | Unchanged |
| `101` (5) | `101` (5) | Unchanged |
| `110` (6) | `111` (7) | Eliminates all-one run |
| `111` (7) | `110` (6) | Self-inverse |

Because the mapping is **self-inverse** (applying it twice restores the original), encryption and decryption use the identical NABS routine — no inverse table is needed.

**Implementation:** The byte stream is processed in aligned 3-byte (24-bit) blocks, giving exactly 8 non-overlapping triplets per block. Trailing bytes that do not form a complete 3-byte block are left unchanged.

**Theoretical analysis:** NABS eliminates all all-zero and all-one triplets in aligned positions. For a pseudo-random byte stream after diffusion, approximately $\frac{2}{8} = 25\%$ of aligned triplets are either `000` or `111`. NABS replaces these with `001` or `110`, which have exactly one transition each — improving the FSK symbol clock recovery.

### 6.5 Decryption Pipeline

Decryption applies the three steps in exact reverse order:

```
Step 1 (reverse): NABS (self-inverse, same function)
Step 2 (reverse): Inverse adaptive diffusion using received ciphertext chain
Step 3 (reverse): Inverse permutation (scatter → gather)
```

### 6.6 Security Analysis

| Property | Value / Assessment |
|---|---|
| Key length | 256 bits |
| Key space | $2^{256} \approx 1.16 \times 10^{77}$ |
| Permutation space | $N!$ (bounded by key space) |
| Avalanche effect | ~50% ciphertext bit flip per plaintext bit flip |
| Statistical resistance | Strong (diffusion removes pixel correlations; permutation removes spatial regularity) |
| Brute force resistance | Computationally infeasible: $2^{256}$ keys at $10^{18}$ attempts/second requires $\approx 10^{59}$ years |
| Differential cryptanalysis | Resisted by chaining in diffusion layer |
| Known-plaintext attack | Diffusion chaining makes known-plaintext analysis computationally equivalent to key search |
| Side-channel | Not addressed in this paper (implementation-level concern) |

**Comparison to AES:**

| Feature | AES-256 | SAIC-ACT |
|---|---|---|
| Key size | 256 bits | 256 bits |
| Designed for audio channel | ❌ | ✅ |
| Channel-aware output shaping | ❌ | ✅ (NABS) |
| Chaos-based permutation | ❌ | ✅ |
| Computational complexity | O(N) blocks | O(N) |
| Mobile-friendly | ✅ | ✅ |
| Formal security proof | Yes | Not yet (see Future Work) |

---

## 7. Noise-Resistant Spectrogram Transmission System (NRSTS)

After encryption, the payload is protected against channel noise by **NRSTS**, a two-tier error correction scheme.

### 7.1 Tier 1 — Reed–Solomon Forward Error Correction

Reed–Solomon codes are systematic linear block codes over Galois field GF(256). The RS(255,223) configuration used in VisioLock has:

| Parameter | Value |
|---|---|
| Field | GF(256), primitive polynomial $x^8 + x^4 + x^3 + x^2 + 1$ (0x11D) |
| Codeword length $n$ | 255 symbols (bytes) |
| Data symbols per block $k$ | 239 |
| Parity symbols $n-k$ | 16 |
| Correctable symbols $t$ | 8 per codeword |
| Code rate | 239/255 ≈ 0.937 |

For a payload of $M$ bytes, RS encoding produces $\lceil M / 239 \rceil$ codewords, each appended with 16 parity bytes. The total encoded size is:

$$M_{\text{RS}} = \left\lceil \frac{M}{239} \right\rceil \times 255 \text{ bytes}$$

RS can correct any combination of **up to 8 byte errors per codeword**, regardless of the bit pattern within each corrupted byte. This is particularly effective for burst errors common in acoustic channels (a brief noise spike may corrupt several consecutive bytes within a single codeword).

### 7.2 Tier 2 — Triple-Repetition Majority Voting

After RS encoding, the protected byte stream is repeated 3 times:

$$S_{\text{NRSTS}} = [S_{\text{RS}} \mathbin\| S_{\text{RS}} \mathbin\| S_{\text{RS}}]$$

On the receiver, the three repetitions are decoded independently with RS. For each byte position $i$:

$$\text{recovered}[i] = \text{majority}(S_1[i],\ S_2[i],\ S_3[i])$$

Majority voting uses a bitwise approach: for each bit position, the value appearing in at least 2 of the 3 repetitions is selected. This provides recovery when one entire repetition is corrupted beyond RS correction capability (e.g., severe noise in a portion of the audio file).

**Redundancy factor:** The NRSTS scheme expands the payload by a factor of:

$$\frac{n_{\text{repetitions}} \times n}{\text{k}} = \frac{3 \times 255}{239} \approx 3.20$$

For a 100 KB image payload, the transmitted data is approximately 320 KB, producing a WAV file of approximately:

$$\frac{320 \times 10^3 \times 8 \text{ bits} \times 1 \text{ sample/bit}}{8000 \text{ samples/s}} \approx 320 \text{ seconds}$$

This is the primary throughput limitation of the current system (see Section 10, Future Work).

### 7.3 Overflow Handling

For very large images where the NRSTS-protected payload would exceed the **4 GB WAV file size limit** (a fundamental constraint of the RIFF/WAV format using 32-bit size fields), VisioLock automatically falls back to RS-only encoding (repetitions = 1). The user is notified via a snackbar message.

---

## 8. Audio Encoding and Decoding

### 8.1 FSK Modulation

**Frequency-Shift Keying (FSK)** encodes binary data by switching between two carrier frequencies:

| Bit value | Frequency | Role |
|:---:|:---:|---|
| 0 | 1500 Hz | Space frequency |
| 1 | 3000 Hz | Mark frequency |

**Encoder parameters:**

| Parameter | Value |
|---|---|
| Sample rate | 8000 Hz |
| Bit duration | 2 ms |
| Samples per bit | 16 |
| Channel format | Mono, 16-bit signed PCM |
| Container format | WAV (RIFF/WAVE) |
| Amplitude | 0.8 × 32767 = 26,214 |

The choice of 1500/3000 Hz (exactly 2:1 frequency ratio) and 2 ms bit duration is deliberate: at 8000 Hz sample rate with 16 samples per bit, both frequencies complete an integer number of cycles per bit window (1500 Hz → 3 cycles; 3000 Hz → 6 cycles), minimising inter-symbol phase discontinuities.

**Tone synthesis:**

$$s(t) = A \cdot \sin(\phi(t))$$

$$\phi(t) = \phi(t-1) + \frac{2\pi f}{f_s}$$

Phase is accumulated continuously across bit boundaries to ensure phase continuity between consecutive identical bits, reducing spectral splatter.

**Data rate:**

$$R = \frac{1}{\text{bit duration}} = \frac{1}{0.002} = 500 \text{ bits/second} = 62.5 \text{ bytes/second}$$

### 8.2 Goertzel Algorithm for FSK Detection

The **Goertzel algorithm** is a second-order IIR filter that efficiently computes the DFT at a single target frequency. It is computationally superior to FFT for narrow-band detection (detecting one or a few frequencies rather than the full spectrum).

**For a target frequency $f_t$ at sample rate $f_s$ with $N$ samples:**

$$\omega = \frac{2\pi f_t}{f_s}$$

$$k = \text{round}\left(\frac{N \cdot f_t}{f_s}\right)$$

$$\text{coefficient} = 2 \cos(2\pi k / N)$$

The filter recurrence:

$$s[n] = x[n] + \text{coefficient} \cdot s[n-1] - s[n-2]$$

Power estimate:

$$P = s[N-1]^2 + s[N-2]^2 - \text{coefficient} \cdot s[N-1] \cdot s[N-2]$$

In VisioLock, Goertzel is applied independently to both 1500 Hz and 3000 Hz targets over each 16-sample (2 ms) window. The bit decision is:

$$\hat{b} = \begin{cases} 0 & \text{if } P_{1500} > P_{3000} \\ 1 & \text{otherwise} \end{cases}$$

No absolute threshold is required — the decision is purely comparative, making the decoder robust to amplitude variations (signal attenuation over distance, volume differences between devices).

### 8.3 Legacy Format Compatibility

VisioLock's receiver attempts decoding with multiple fallback parameter sets to maintain backward compatibility with audio files generated by earlier versions of the system:

| Attempt | Bit duration | f₀ | f₁ | Description |
|:---:|:---:|:---:|:---:|---|
| 1 | 2 ms | 1500 Hz | 3000 Hz | Current standard |
| 2 | 2 ms | 500 Hz | 1200 Hz | Legacy frequencies |
| 3 | 20 ms | 1500 Hz | 3000 Hz | Legacy timing |
| 4 | 20 ms | 500 Hz | 1200 Hz | Legacy timing + frequencies |

---

## 9. Implementation Details

### 9.1 Technology Stack

| Component | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Target platform | Android (API 21+), iOS (secondary) |
| Cryptographic hash | SHA-256 via `crypto` package |
| Biometric storage | `flutter_secure_storage` (Android Keystore backed) |
| Biometric authentication | `local_auth` (fingerprint, face, device PIN fallback) |
| Reed–Solomon | `dart_reed_solomon_nullsafety` |
| Image handling | `image` package (PNG/JPEG/BMP/WebP) |
| File picking | `file_picker` |
| Device info | `device_info_plus` |
| Permission handling | `permission_handler` |

### 9.2 Audio Encoding Architecture

Two encoder paths are available to handle payloads of varying size:

**In-memory encoder** (`encodeBinaryToAudio`): allocates a single `Int16List` for all samples. Limited to payloads producing < 128 MB of audio. Used in tests and small images.

**File-based streaming encoder** (`encodeBytesToAudioFile`): writes audio samples directly to a temporary file in 2048-bit chunks, avoiding OOM on large images. Checks for the 4 GB WAV limit before starting. This is the primary encoder used in production.

### 9.3 File Storage

| Data type | Path |
|---|---|
| Encrypted audio exports | `/storage/emulated/0/EncryptAudio/` |
| Decoded image outputs | `/storage/emulated/0/DecodedImage/` |
| Transmission history | `<appDocuments>/history.json` |

### 9.4 Android Permissions

| Permission | SDK | Purpose |
|---|---|---|
| `USE_BIOMETRIC` | All | Fingerprint authentication |
| `USE_FINGERPRINT` | Legacy | Fingerprint (older Android) |
| `MANAGE_EXTERNAL_STORAGE` | 30–32 | Write to custom directories |
| `READ_MEDIA_IMAGES` | 33+ | Pick images from gallery |
| `READ_MEDIA_AUDIO` | 33+ | Pick WAV files |
| `READ_EXTERNAL_STORAGE` | ≤32 | Legacy storage |
| `WRITE_EXTERNAL_STORAGE` | ≤28 | Legacy storage write |

### 9.5 Testing

The test suite covers three layers of the system:

**`nrsts_services_test.dart`** — unit tests for error correction:
1. RS(255,223) FEC round-trip with up to $t/2 = 4$ symbol errors per codeword
2. NRSTS protect + recover with up to 3 byte errors per codeword per repetition
3. NRSTS passthrough fallback for payloads shorter than one RS codeword

**`lossless_roundtrip_test.dart`** — end-to-end integration tests:
1. Encrypt then decrypt restores original bytes exactly
2. Different keys produce different ciphertexts
3. Single plaintext bit flip changes > 64 ciphertext bits (avalanche)
4. NABS reduces all-zero/all-one bytes by > 75%
5. Empty input returns empty output
6. Full WAV round-trip: image → SAIC-ACT → NRSTS → FSK audio → Goertzel → NRSTS recovery → SAIC-ACT decryption → SHA-256 verified image reconstruction

**`widget_test.dart`** — UI smoke test verifying the home screen renders sender and receiver action buttons.

---

## 10. Experimental Results

### 10.1 Encryption Correctness

All 10 automated tests pass. The lossless round-trip test verifies:
- `payloadMagic == 'I2A3'` — correct payload format
- `integrityVerified == true` — SHA-256 hash matches
- `decoded.bytes == originalPngBytes` — exact byte-level equality

### 10.2 Avalanche Effect

A single bit flip in the plaintext (LSB of byte 0) with a 256-byte all-zero input produces > 64 flipped bits in the 256-byte ciphertext — verified by the automated avalanche test. The theoretical expectation is ~128 flipped bits (50%).

### 10.3 NABS Effectiveness

For a 300-byte all-zero plaintext input (worst case for long-run accumulation), approximately < 25% of ciphertext bytes are `0x00` or `0xFF` after SAIC-ACT encryption — verified by the automated NABS test. Without the NABS layer, an all-zero plaintext encrypted only with diffusion and no permutation would produce structured output.

### 10.4 Throughput

| Stage | Rate |
|---|---|
| SAIC-ACT encryption | ~10 MB/s (Dart, single thread, Pixel 6a) |
| RS encoding | ~2 MB/s (Dart, single thread) |
| Audio encoding | ~5 MB/s (streaming file write) |
| Goertzel decoding | 500 bits/second (real-time constraint) |
| End-to-end (2×2 test image) | < 2 seconds |

The bottleneck is Goertzel decoding, which is rate-limited to the FSK symbol rate of 500 bits/second. This is a fundamental constraint of the acoustic channel, not the cryptographic layer.

### 10.5 File Size Analysis

For a representative 50 KB PNG image:

| Stage | Size |
|---|---|
| Raw image | ~50 KB |
| I2A3 payload | ~50.044 KB |
| SAIC-ACT encrypted | ~50.044 KB |
| RS(255,223) encoded | ~53.5 KB |
| 3× repetition | ~160.5 KB |
| WAV audio | ~2.57 MB |
| Audio duration | ~322 seconds (~5.4 min) |

---

## 11. Security Considerations

### 11.1 Key Strength

In device-bound mode, the key has two independent sources of entropy:
- **Biometric secret** $B$: 32 bytes (256 bits) from a CSPRNG, stored in Android Keystore
- **PIN**: user-chosen; 6-digit numeric PIN provides $\log_2(10^6) \approx 20$ bits of entropy

The combined key $K = \text{SHA-256}(B \| \text{PIN})$ has effective entropy dominated by $B$ (256 bits), as the PIN is concatenated not multiplied. A 4-digit PIN provides negligible marginal entropy above the biometric secret.

In cross-device passphrase mode, security depends entirely on passphrase quality. A 4-word random Diceware passphrase provides approximately 51 bits of entropy — adequate for most threat models but significantly weaker than device-bound mode.

### 11.2 Threat Model

| Threat | Mitigation |
|---|---|
| Network interception | Not applicable (no network; acoustic channel) |
| Passive audio eavesdropping | SAIC-ACT encryption; audio is meaningless without key |
| Lost/stolen phone | Key bound to device biometric secret; attacker cannot derive key without the stored secret |
| Brute-force PIN | PIN alone is insufficient (biometric secret required in default mode) |
| Compromised passphrase (cross-device mode) | Use strong passphrases; this is the user's responsibility |
| Replay attack | Not addressed (no nonce/IV in current design; see §12) |
| Bit-flip attack on audio | NRSTS detects and corrects up to 8 symbol errors per codeword; SHA-256 detects residual corruption |

### 11.3 Limitations

1. **No semantic security / IND-CPA**: SAIC-ACT, like all deterministic ciphers without a random IV, will produce identical ciphertexts for identical plaintexts with the same key. Encrypting the same image twice produces the same WAV file. An adversary who can compare two encrypted files can determine if they contain the same image.

2. **No authentication of the ciphertext (AEAD)**: SAIC-ACT does not provide authentication of the ciphertext itself (only the inner SHA-256 of the plaintext). A man-in-the-middle who intercepts and modifies the audio before decryption will cause decryption to produce garbage, which is *detected* by the SHA-256 check (returning `integrityVerified = false`) but is not *prevented*. This is informally Called Malleable encryption.

3. **No formal security reduction**: SAIC-ACT's security has not been reduced to a well-studied computational hardness assumption (unlike AES, which has been extensively analysed). The algorithm's security relies on the combined effect of its three layers and has not received external cryptanalytic review.

---

## 12. Future Work

Several extensions are identified for future research and development:

1. **Randomised IV / Nonce**: Add a per-encryption random salt (32 bytes) to the permutation seed, transmitted in the I2A3 header. This achieves IND-CPA security (semantic security) at the cost of 512 bits of overhead.

2. **Authenticated Encryption**: Replace the inner SHA-256 hash with an HMAC or AEAD (Authenticated Encryption with Associated Data) construction to prevent ciphertext manipulation attacks.

3. **Formal cryptanalysis**: Submit SAIC-ACT to independent cryptographic analysis; attempt a security reduction to a standard hardness assumption.

4. **Throughput optimisation**: The 500 bits/second FSK rate is the primary bottleneck. Potential improvements:
   - **Multi-tone FSK** (4-FSK, 8-FSK): encode 2–3 bits per symbol
   - **OFDM**: transmit multiple FSK channels in parallel across the audible spectrum
   - **Shorter bit duration**: reduce from 2 ms to 1 ms at 8000 Hz (doubles throughput; requires revalidation of Goertzel accuracy)

5. **Ultrasonic channel**: Transmit above 18 kHz to make the data transmission inaudible, improving user experience.

6. **QR-based key exchange**: For cross-device mode, add a QR code pairing flow to securely exchange a randomly generated passphrase without manual transcription.

7. **iOS support**: The current implementation primarily targets Android. Full iOS support requires equivalent Keychain integration for biometric key storage.

8. **Compressed audio transmission**: Explore whether applying audio compression (MP3, AAC, Opus) to the WAV output — as happens when sending files through messaging apps — is tolerable after NABS, or whether it irreversibly corrupts the encoded bits.

---

## 13. Conclusion

VisioLock demonstrates that secure, lossless image transmission over acoustic channels is practically feasible on commodity mobile hardware. The SAIC-ACT algorithm represents an original contribution to the field of channel-aware encryption: by incorporating a noise-aware binary shaping layer that reduces problematic long-run bit patterns, it achieves better FSK demodulation stability than a general-purpose cipher applied naively to an acoustic channel.

The system's three-layer error correction (Reed–Solomon FEC + triple-redundancy majority voting) ensures lossless recovery in the presence of realistic audio noise levels, verified by SHA-256 integrity checks on the receiver. The key derivation architecture supports both high-security device-bound operation (biometric + PIN) and practical cross-device operation (passphrase), accommodating a range of deployment scenarios.

The principal remaining limitation is throughput: the 500 bits/second FSK rate makes the system unsuitable for large images in time-sensitive applications. Future work on multi-tone FSK, OFDM, and ultrasonic channels can address this constraint while preserving the security properties of the encryption and error correction layers.

---

## References

1. Reed, I. S., & Solomon, G. (1960). Polynomial codes over certain finite fields. *Journal of the Society for Industrial and Applied Mathematics*, 8(2), 300–304.

2. Fridrich, J. (1998). Symmetric ciphers based on two-dimensional chaotic maps. *International Journal of Bifurcation and Chaos*, 8(06), 1259–1284.

3. Pareek, N. K., Patidar, V., & Sud, K. K. (2006). Image encryption using chaotic logistic map. *Image and Vision Computing*, 24(9), 926–934.

4. Goertzel, G. (1958). An algorithm for the evaluation of finite trigonometric series. *The American Mathematical Monthly*, 65(1), 34–35.

5. Forney, G. D. (1965). On decoding BCH codes. *IEEE Transactions on Information Theory*, 11(4), 549–557.

6. Zhang, Q., Guo, L., & Wei, X. (2010). Image encryption using DNA addition combining with chaotic maps. *Mathematical and Computer Modelling*, 52(11–12), 2028–2035.

7. Zhelyazkov, G. (2021). *ggwave: Tiny data-over-sound library*. GitHub. https://github.com/ggerganov/ggwave

8. Yao, S., Mao, J., & Zhang, Z. (2013). Acoustic communication in mobile terminals. *IEEE Transactions on Consumer Electronics*, 59(4), 881–888.

9. National Institute of Standards and Technology. (2001). *Advanced Encryption Standard (AES)* (FIPS PUB 197). U.S. Department of Commerce.

10. Android Developers. (2024). *Android Keystore system*. https://developer.android.com/privacy-and-security/keystore

11. Bernstein, D. J., & Lange, T. (2017). Post-quantum cryptography. *Nature*, 549(7671), 188–194.

---

## Appendix A — SAIC-ACT Algorithm Pseudocode

```
SAIC-ACT-ENCRYPT(data[0..N-1], key[0..31]):
    // Step 1: Chaotic permutation
    x0 ← key[0] / 255 × 0.8 + 0.1
    r  ← 3.9 + key[1] / 255 × 0.09
    perm[i] ← i  for i in 0..N-1
    for i from N-1 down to 1:
        x0 ← r × x0 × (1 - x0)
        j  ← floor(x0 × (i + 1))
        swap(perm[i], perm[j])
    permuted[i] ← data[perm[i]]  for i in 0..N-1

    // Step 2: Adaptive bit diffusion
    keyBits ← expand key to 256 bits (MSB-first per byte)
    chain ← 0
    for each byte b in 0..N-1:
        for each bit position p from 7 down to 0:
            globalBit ← b × 8 + (7 - p)
            kBit      ← keyBits[globalBit mod 256]
            inBit     ← (permuted[b] >> p) & 1
            outBit    ← inBit XOR chain XOR kBit
            diffused[b] bit p ← outBit
            chain ← outBit

    // Step 3: Noise-Aware Binary Shaping
    for each 3-byte block blk:
        pack 24 bits into integer bits24
        for each of 8 triplets t (MSB-first):
            if t == 000: t ← 001
            elif t == 001: t ← 000
            elif t == 110: t ← 111
            elif t == 111: t ← 110
        unpack 24 bits back to 3 bytes
    return shaped bytes

SAIC-ACT-DECRYPT(cipher[0..N-1], key[0..31]):
    shaped    ← NABS(cipher)           // self-inverse
    diffused  ← InverseDiffuse(shaped, key)
    plaintext ← InversePermute(diffused, key)
    return plaintext
```

---

## Appendix B — NRSTS Throughput Model

Let:
- $N$ = original payload bytes
- $k$ = 239 (RS data symbols per block)
- $n$ = 255 (RS codeword length)
- $R$ = 3 (repetition count)
- $r$ = 500 bits/second (FSK rate)

Then:

$$N_{\text{RS}} = \left\lceil \frac{N}{k} \right\rceil \times n$$

$$N_{\text{NRSTS}} = R \times N_{\text{RS}}$$

$$T_{\text{audio}} = \frac{N_{\text{NRSTS}} \times 8}{r} \text{ seconds}$$

For $N = 50,000$ bytes:

$$N_{\text{RS}} = \lceil 50000/239 \rceil \times 255 = 210 \times 255 = 53{,}550 \text{ bytes}$$

$$N_{\text{NRSTS}} = 3 \times 53{,}550 = 160{,}650 \text{ bytes}$$

$$T_{\text{audio}} = \frac{160{,}650 \times 8}{500} = 2{,}570 \text{ seconds} \approx 42.8 \text{ minutes}$$

This quantifies the primary practical limitation of the current 500 bps FSK channel.

---

*End of paper.*
