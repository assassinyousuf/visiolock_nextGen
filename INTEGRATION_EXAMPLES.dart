import 'package:visiolock_nextgen/services/ai_transmission_service.dart';
import 'package:visiolock_nextgen/services/adaptive_transmission_system.dart';
import 'package:visiolock_nextgen/services/channel_state_estimator_service.dart';

/// Example Integration: Using AI Transmission Service in Sender Screen
/// 
/// This example demonstrates how to integrate the AI model for adaptive
/// transmission parameter selection in your actual application screens.

Future<void> exampleSenderIntegration({
  required String fileType,
  required double fileSizeKb,
  required Function applyTransmissionConfig,
}) async {
  try {
    print('🔄 Analyzing transmission requirements...');

    // Step 1: Estimate channel conditions
    final channelEstimator = ChannelStateEstimatorService();
    final channelEstimate = await channelEstimator.estimateChannelState(
      referenceSamples: 100,
    );
    
    final snr = channelEstimate['snr'] as double? ?? 20.0;
    final noiseLevel = channelEstimate['noise_level'] as double? ?? 0.1;

    print('📊 Channel Estimate: SNR=$snr dB, Noise Level=$noiseLevel');

    // Step 2: Check if AI server is available
    final isServerAvailable = await AiTransmissionService.isServerAvailable();
    
    if (isServerAvailable) {
      print('✅ AI Server is available');

      // Step 3a: Get recommendation from AI model
      final aiConfig = await AiTransmissionService.getOptimalConfiguration(
        fileType: fileType,
        fileSizeKb: fileSizeKb,
        snr: snr,
        noiseLevel: noiseLevel,
      );

      print('🎯 AI Recommendation:');
      print('   Encoding: ${aiConfig['encoding']}');
      print('   Coding: ${aiConfig['coding']}');
      print('   Modulation: ${aiConfig['modulation']}');
      print('   Source: ${aiConfig['source']}');

      // Step 4: Apply the AI-recommended configuration
      await applyTransmissionConfig(aiConfig);
    } else {
      print('⚠️ AI Server unavailable, using fallback logic');

      // Step 3b: Fallback to rule-based logic
      final adaptiveSystem = AdaptiveTransmissionSystem();
      final fallbackConfig = await adaptiveSystem.selectOptimalConfiguration(
        filesize: fileSizeKb.toInt(),
        contentType: fileType,
        channelQuality: snr,
      );

      print('📋 Fallback Configuration:');
      print('   Encoding: ${fallbackConfig['encryption']}');
      print('   Coding: ${fallbackConfig['fecMethod']}');
      print('   Modulation: ${fallbackConfig['modulationScheme']}');

      // Convert to format expected by transmission pipeline
      final config = {
        'encoding': fallbackConfig['encryption'],
        'coding': fallbackConfig['fecMethod'],
        'modulation': fallbackConfig['modulationScheme'],
        'source': 'fallback_rule_based',
      };

      await applyTransmissionConfig(config);
    }
  } catch (e) {
    print('❌ Error during configuration selection: $e');
    rethrow;
  }
}

/// Example 2: Batch Configuration Prediction
/// 
/// Useful for pre-computing optimal parameters for different scenarios
Future<void> exampleBatchPrediction() async {
  final scenarios = [
    {
      'file_type': 'image',
      'file_size_kb': 2048.0,
      'snr': 20.0,
      'noise_level': 0.1,
    },
    {
      'file_type': 'video',
      'file_size_kb': 5000.0,
      'snr': 15.0,
      'noise_level': 0.3,
    },
    {
      'file_type': 'audio',
      'file_size_kb': 512.0,
      'snr': 25.0,
      'noise_level': 0.05,
    },
  ];

  try {
    print('🔄 Predicting configurations for multiple scenarios...');

    final results = await AiTransmissionService.getBatchConfigurations(
      scenarios: scenarios,
    );

    print('✅ Batch prediction complete:');
    results.forEach((key, config) {
      print('  $key → ${config['encoding']} + ${config['coding']} + ${config['modulation']}');
    });
  } catch (e) {
    print('❌ Batch prediction failed: $e');
  }
}

/// Example 3: Configuration with Explicit Fallback
/// 
/// Demonstrates using getConfigurationWithFallback for maximum reliability
Future<void> exampleWithExplicitFallback() async {
  try {
    final config = await AiTransmissionService.getConfigurationWithFallback(
      fileType: 'image',
      fileSizeKb: 2048.0,
      snr: 20.0,
      noiseLevel: 0.1,
      fallbackFunction: () async {
        // This function is called if AI API fails
        // Implement your rule-based fallback logic here
        
        print('⚠️ Executing fallback function...');
        
        // Example rule-based logic
        return {
          'encoding': 'AES-128',
          'coding': 'RS',
          'modulation': '16-QAM',
          'reason': 'rule_based_fallback',
        };
      },
    );

    print('Configuration selected:');
    print('  Encoding: ${config['encoding']}');
    print('  Source: ${config['source']}');
  } catch (e) {
    print('❌ Configuration failed even with fallback: $e');
  }
}

/// Example 4: Monitoring and Diagnostics
/// 
/// Shows how to monitor AI service health and performance
Future<void> exampleMonitoring() async {
  try {
    // Check server health
    print('🔍 Checking AI service health...');
    final isHealthy = await AiTransmissionService.isServerAvailable();
    
    if (isHealthy) {
      print('✅ AI Service: HEALTHY');
      
      // Measure prediction latency
      final stopwatch = Stopwatch()..start();
      
      final config = await AiTransmissionService.getOptimalConfiguration(
        fileType: 'image',
        fileSizeKb: 1024.0,
        snr: 20.0,
        noiseLevel: 0.1,
      );
      
      stopwatch.stop();
      print('⏱️ Prediction latency: ${stopwatch.elapsedMilliseconds}ms');
      print('📊 Configuration: $config');
    } else {
      print('❌ AI Service: UNAVAILABLE');
    }
  } catch (e) {
    print('❌ Monitoring error: $e');
  }
}

/// Example 5: Real-Time Adaptation
/// 
/// Demonstrates real-time channel monitoring and parameter adjustment
class RealtimeAdaptationExample {
  static Future<void> monitorAndAdapt() async {
    final channelEstimator = ChannelStateEstimatorService();
    
    // Simulate continuous monitoring
    for (int i = 0; i < 5; i++) {
      print('\n📡 Monitoring iteration $i');
      
      try {
        // Continuously estimate channel state
        final estimate = await channelEstimator.estimateChannelState(
          referenceSamples: 50,
        );
        
        final snr = estimate['snr'] as double? ?? 20.0;
        final noiseLevel = estimate['noise_level'] as double? ?? 0.1;
        
        print('  SNR: $snr dB, Noise: $noiseLevel');

        // Get current optimal configuration based on channel state
        final config = await AiTransmissionService.getOptimalConfiguration(
          fileType: 'image',
          fileSizeKb: 1024.0,
          snr: snr,
          noiseLevel: noiseLevel,
        );
        
        print('  Recommended: ${config['encoding']} + ${config['coding']} + ${config['modulation']}');
        
        // In real application, apply configuration if significant change detected
      } catch (e) {
        print('  ⚠️ Error: $e');
      }

      // Wait before next check (would be much longer in real app)
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}

/// Example 6: Performance Optimization
/// 
/// Shows caching and optimization strategies
class PerformanceOptimizationExample {
  static final _configCache = <String, Map<String, dynamic>>{};
  
  static Future<Map<String, dynamic>> getCachedConfiguration({
    required String fileType,
    required double fileSizeKb,
    required double snr,
    required double noiseLevel,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    final cacheKey = '${fileType}_${fileSizeKb}_${snr}_$noiseLevel';
    
    // Check cache
    if (_configCache.containsKey(cacheKey)) {
      print('💾 Using cached configuration');
      return _configCache[cacheKey]!;
    }
    
    // Fetch from API
    print('🔄 Fetching fresh configuration from AI');
    final config = await AiTransmissionService.getOptimalConfiguration(
      fileType: fileType,
      fileSizeKb: fileSizeKb,
      snr: snr,
      noiseLevel: noiseLevel,
    );
    
    // Cache result
    _configCache[cacheKey] = config;
    
    // Clear cache after duration
    Future.delayed(cacheDuration, () {
      _configCache.remove(cacheKey);
      print('🗑️ Cache entry expired: $cacheKey');
    });
    
    return config;
  }
}

void main() {
  print('=== VisioLock++ AI Transmission Service Examples ===\n');
  print('This file contains integration examples for using the AI service.');
  print('Use these as templates for your actual application code.\n');
  print('Examples:');
  print('1. exampleSenderIntegration() - Basic integration flow');
  print('2. exampleBatchPrediction() - Batch predictions');
  print('3. exampleWithExplicitFallback() - With explicit fallback');
  print('4. exampleMonitoring() - Health monitoring');
  print('5. RealtimeAdaptationExample.monitorAndAdapt() - Real-time adaptation');
  print('6. PerformanceOptimizationExample.getCachedConfiguration() - Caching');
}
