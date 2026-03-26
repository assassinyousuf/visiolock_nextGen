# Changelog

## [2.0.0] - 2026-03-26

### Added
- **AI-Optimized Adaptive Modulation**: Neural network-driven selection of modulation schemes (16-QAM, 8-PSK, BFSK) based on real-time channel analysis.
- **Multi-File Support (I2A3++ Protocol)**: Ability to batch multiple files (images, documents) into a single transmission stream.
- **Enhanced Security**: 
    - Hybrid encryption architecture (AES-256-GCM + SAIC-ACT).
    - Biometric-bound key derivation.
- **Noise-Resistant Spectrogram Transmission System (NRSTS 2.0)**: Adaptive error correction with dynamic Reed-Solomon rates.
- **New UI**: Updated configuration screens for sender and receiver.
- **Research Paper**: Included full academic paper documenting the VisioLock++ system.

### Changed
- Refactored core transmission engine to support pluggable modulation strategies.
- Updated `pubspec.yaml` dependencies for AI and cryptography support.
- Renamed android package to `com.example.visiolock_nextgen`.

### Fixed
- Improved resilience to background noise in public environments.
- Fixed framing issues in previous single-file transmission protocol.
