// Example Usage: VisioLock++ Adaptive Transmission
//
// This file demonstrates how to use the new adaptive transmission features
// for single files and multi-file scenarios.

import 'dart:io';
import 'dart:typed_data';

import 'lib/models/channel_state.dart';
import 'lib/models/multi_file_frame.dart';
import 'lib/services/adaptive_encoding_selector_service.dart';
import 'lib/services/adaptive_transmission_system.dart';
import 'lib/services/channel_state_estimator_service.dart';
import 'lib/services/content_analyzer_service.dart';
import 'lib/services/enhanced_key_derivation_service.dart';
import 'lib/services/encryption_service.dart';
import 'lib/services/multi_file_framing_service.dart';

/// Example 1: Analyze a single file and get adaptive transmission plan
Future<void> exampleSingleFileAdaptiveTransmission() async {
  print('=== Example 1: Single File Adaptive Transmission ===\n');

  // File to transmit
  final sourceFile = File('path/to/document.pdf');

  // Step 1: Create adaptive transmission system
  final adaptiveSystem = AdaptiveTransmissionSystem();

  // Step 2: Estimate channel condition (optionally from measured audio)
  const channelEstimator = ChannelStateEstimatorService();
  final channelEstimate = ChannelStateEstimate(
    snrDb: 15.5,
    noiseLevel: 0.25,
  );

  // Step 3: Compute transmission plan
  final plan = await adaptiveSystem.computeTransmissionPlan(
    sourceFile,
    channelEstimate: channelEstimate,
  );

  // Step 4: Display results
  print('File: ${plan.fileMetadata.fileName}');
  print('Category: ${plan.fileMetadata.category}');
  print('Size: ${plan.fileMetadata.fileSize} bytes');
  print('\nChannel Condition: ${plan.channelEstimate.condition}');
  print('SNR: ${plan.channelEstimate.snrDb.toStringAsFixed(2)} dB');
  print('\nAdaptive Parameters:');
  print('- Encoding: ${plan.encodingStrategy}');
  print('- Coding: ${plan.codingScheme}');
  print('- Modulation: ${plan.modulationParameters}');
  print('- Expansion Ratio: ${plan.expectedExpansionRatio.toStringAsFixed(2)}x');
  print('- Optimization Score: ${plan.optimizationScore.toStringAsFixed(1)}/100');
  print('\nExpected Audio Size: ${plan.expectedAudioSizeBytes} bytes');
}

/// Example 2: Multi-file transmission with batch analysis
Future<void> exampleMultiFileAdaptiveTransmission() async {
  print('\n=== Example 2: Multi-File Adaptive Transmission ===\n');

  final files = <File>[
    File('path/to/image.png'),
    File('path/to/document.txt'),
    File('path/to/data.json'),
  ];

  final adaptiveSystem = AdaptiveTransmissionSystem();
  final framer = MultiFileFramingService();

  // Step 1: Analyze all files
  final aggregatedPlan = await adaptiveSystem.analyzeMultipleFiles(files);

  print('Files analyzed: ${aggregatedPlan.plans.length}');
  print('Total original size: ${aggregatedPlan.totalDataSize} bytes');
  print('Expected audio size: ${aggregatedPlan.expectedTotalAudioSize} bytes');
  print('Aggregate expansion: ${aggregatedPlan.aggregateExpansionRatio.toStringAsFixed(2)}x');
  print('Average optimization: ${aggregatedPlan.averageOptimizationScore.toStringAsFixed(1)}/100');
  print('Adaptive tuning recommended: ${aggregatedPlan.recommendAdaptiveChannelTuning}');

  // Step 2: Show individual file plans
  print('\n Individual File Plans:');
  for (final plan in aggregatedPlan.plans) {
    print('  - ${plan.fileMetadata.fileName}');
    print('    Strategy: ${plan.encodingStrategy}');
    print('    Expansion: ${plan.expectedExpansionRatio.toStringAsFixed(2)}x');
  }

  // Step 3: Create frames for transmission
  print('\nCreating transmission frames...');
  final frames = await framer.createFramesFromFiles(files);
  final summary = framer.summarizeFrames(frames);
  print(summary);
}

/// Example 3: Adaptive channel-based parameter selection
Future<void> exampleChannelAdaptation() async {
  print('\n=== Example 3: Real-Time Channel Adaptation ===\n');

  final adaptiveSystem = AdaptiveTransmissionSystem();

  // Simulate different channel conditions and get recommendations
  final snrValues = [25.0, 15.0, 8.0]; // Good, Medium, Poor

  for (final snr in snrValues) {
    final recommendation =
        adaptiveSystem.getChannelAdaptationRecommendation(snr);

    print('SNR: ${snr.toStringAsFixed(1)} dB');
    print('Condition: ${recommendation.current.condition}');
    print('Coding: ${recommendation.codingScheme.scheme}');
    print('Repetition: ${recommendation.codingScheme.repetitionFactor}x');
    print('Modulation: ${recommendation.modulationParameters.modulationType}');
    print('Est. BER: ${(recommendation.bitErrorRateEstimate * 100).toStringAsFixed(2)}%');
    print('---');
  }
}

/// Example 4: Content analysis and encoding selection
Future<void> exampleContentAwareness() async {
  print('\n=== Example 4: Content-Aware Encoding Selection ===\n');

  final analyzer = ContentAnalyzerService();
  final selector = AdaptiveEncodingSelectorService();

  // Analyze different file types
  final imageFile = File('path/to/photo.jpg');
  final textFile = File('path/to/document.txt');
  final binaryFile = File('path/to/data.bin');

  for (final file in [imageFile, textFile, binaryFile]) {
    if (!await file.exists()) continue;

    final metadata = await analyzer.analyzeFile(file);
    final channelState =
        ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.3);
    final strategy = selector.selectStrategy(metadata, channelState);
    final params = selector.configureEncodingParameters(strategy, channelState);
    final expansion = selector.estimateExpansionRatio(
      metadata,
      strategy,
      channelState.isMedium ? 2 : 1,
    );

    print('File: ${metadata.fileName}');
    print('Category: ${metadata.category}');
    print('Size: ${metadata.fileSize} bytes');
    print('Entropy: ${analyzer.calculateEntropy(await file.readAsBytes()).toStringAsFixed(2)} bits');
    print('Selected Strategy: $strategy');
    print('Parameters: $params');
    print('Expected Expansion: ${expansion.toStringAsFixed(2)}x');
    print('---\n');
  }
}

/// Example 5: Enhanced encryption with key derivation and quality check
Future<void> exampleEnhancedEncryption() async {
  print('\n=== Example 5: Enhanced Encryption ===\n');

  const String userPassword = 'MyStrongPassword123!';
  const String userEmail = 'user@example.com';
  final deviceId = 'device_abc123';

  // Step 1: Derive enhanced key
  final key = EnhancedKeyDerivationService.deriveKeyFromPassword(
    password: userPassword,
    email: userEmail,
    iterations: 3,
  );
  print('Derived key: ${key.take(8).toList().join(',')}... (showing first 8 bytes)');

  // Step 2: Create salt for encryption
  final salt = EnhancedKeyDerivationService._generateSalt();

  // Step 3: Encrypt data
  final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
  final encryption = EnhancedEncryptionService(encryptionRounds: 2);
  final encrypted = encryption.encryptBytesWithSalt(
    dataBytes: plaintext,
    key: key,
    salt: salt,
  );
  print('\nEncrypted ${plaintext.length} bytes → ${encrypted.length} bytes');

  // Step 4: Evaluate encryption quality
  final quality = encryption.evaluateEncryptionQuality(
    plaintext,
    key,
    testSamples: 10,
  );
  print('\nEncryption Quality Report:');
  print(quality);

  // Step 5: Multi-factor key derivation
  final bioKey = Uint8List.fromList(
    'biometric_fingerprint_data_12345678'.codeUnits,
  );
  final multiFactorKey = EnhancedKeyDerivationService.deriveMultiFactorKey(
    biometricKey: bioKey,
    pin: '1234',
    deviceId: deviceId,
  );
  print('\nMulti-factor key derived: ${multiFactorKey.length} bytes');
}

/// Example 6: Multi-file frame serialization and transmission
Future<void> exampleMultiFileFrames() async {
  print('\n=== Example 6: Multi-File Frame Handling ===\n');

  final framer = MultiFileFramingService();

  // Create sample files
  final file1 = File('temp_file1.txt');
  final file2 = File('temp_file2.txt');
  await file1.writeAsString('File 1 content');
  await file2.writeAsString('File 2 content');

  try {
    // Step 1: Create frames
    final frames = await framer.createFramesFromFiles([file1, file2]);
    print('Created ${frames.length} frames');

    // Step 2: Validate frame sequence
    final isValid = framer.validateFrameSequence(frames);
    print('Frame sequence valid: $isValid');

    // Step 3: Serialize for transmission
    final serialized = framer.serializeFrames(frames);
    print('Serialized size: ${serialized.length} bytes');

    // Step 4: Simulate transmission and deserialize
    final deserialized = framer.deserializeFrames(serialized);
    print('Deserialized ${deserialized.length} frames');

    // Step 5: Reconstruct files
    final outputDir = 'output_files';
    await Directory(outputDir).create(recursive: true);
    final reconstructed =
        await framer.reconstructFilesFromFrames(deserialized, outputDir);
    print('Reconstructed ${reconstructed.length} files to $outputDir');

    // Step 6: Summary
    final summary = framer.summarizeFrames(frames);
    print('\n$summary');
  } finally {
    // Cleanup
    await file1.delete();
    await file2.delete();
  }
}

/// Example 7: Complete end-to-end workflow
Future<void> exampleCompleteWorkflow() async {
  print('\n=== Example 7: Complete End-to-End Workflow ===\n');

  // Setup
  final sourceFiles = <File>[
    File('path/to/file1.pdf'),
    File('path/to/file2.txt'),
  ];

  const userPassword = 'SecurePassword123';
  const userEmail = 'sender@example.com';

  // Step 1: Analyze files
  print('Step 1: Analyzing files...');
  final adaptiveSystem = AdaptiveTransmissionSystem();
  final analysis =
      await adaptiveSystem.analyzeMultipleFiles(sourceFiles);
  print('Total size: ${analysis.totalDataSize} bytes');
  print('Expected audio: ${analysis.expectedTotalAudioSize} bytes');

  // Step 2: Derive encryption key
  print('\nStep 2: Deriving encryption key...');
  final key = EnhancedKeyDerivationService.deriveKeyFromPassword(
    password: userPassword,
    email: userEmail,
  );

  // Step 3: Create multi-file frames
  print('\nStep 3: Creating transmission frames...');
  final framer = MultiFileFramingService();
  final frames = await framer.createFramesFromFiles(sourceFiles);
  print('Created ${frames.length} frames');

  // Step 4: Encrypt frames (each frame individually)
  print('\nStep 4: Encrypting frames...');
  final encryption = EnhancedEncryptionService();
  final encryptedFrames = <MultiFileFrame>[];
  for (final frame in frames) {
    final encrypted = encryption.encryptBytes(
      dataBytes: frame.fileData,
      key: key,
    );
    encryptedFrames.add(
      MultiFileFrame(
        fileIndex: frame.fileIndex,
        fileCount: frame.fileCount,
        fileName: frame.fileName,
        fileSize: frame.fileSize,
        fileData: encrypted,
      ),
    );
  }

  // Step 5: Serialize for transmission
  print('\nStep 5: Serializing for transmission...');
  final serialized = framer.serializeFrames(encryptedFrames);
  print('Total transmission size: ${serialized.length} bytes');

  print('\n✓ Workflow complete!');
  print('Ready to transmit ${serialized.length} bytes via audio');
}

/// Main entry point
Future<void> main() async {
  try {
    await exampleSingleFileAdaptiveTransmission();
    await exampleMultiFileAdaptiveTransmission();
    await exampleChannelAdaptation();
    await exampleContentAwareness();
    await exampleEnhancedEncryption();
    await exampleMultiFileFrames();
    await exampleCompleteWorkflow();

    print('\n✓ All examples completed successfully!');
  } catch (e) {
    print('Error: $e');
  }
}
