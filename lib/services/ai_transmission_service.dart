import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Handles real-time API calls to the VisioLock++ AI transmission model server
/// Provides adaptive parameter selection based on channel conditions and file properties
class AiTransmissionService {
  /// Base URL for the Flask API server
  /// For physical devices: http://192.168.x.x:5000
  /// For Android emulator: http://10.0.2.2:5000
  /// For iOS simulator: http://localhost:5000
  static const String apiUrl = 'http://127.0.0.1:5000';

  /// Alternative URL for Android emulator
  static const String androidEmulatorUrl = 'http://10.0.2.2:5000';

  /// Request timeout duration
  static const Duration timeoutDuration = Duration(seconds: 10);

  /// Whether to use fallback logic if API is unavailable
  static const bool useFallback = true;

  /// Get the appropriate API URL based on platform
  static String getApiUrl() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator uses 10.0.2.2 to access host machine localhost
      // Physical devices would use the actual server IP
      return androidEmulatorUrl;
    }
    return apiUrl;
  }

  /// Check if the AI model API server is available
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse('${getApiUrl()}/health'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ AI Server unavailable: $e');
      return false;
    }
  }

  /// Get optimal transmission configuration from AI model
  /// 
  /// Parameters:
  /// - fileType: Type of file being transmitted (image, audio, video, text)
  /// - fileSizeKb: Size of file in kilobytes
  /// - snr: Signal-to-Noise Ratio in dB (higher = better channel quality)
  /// - noiseLevel: Normalized noise level (0.0 = no noise, 1.0 = maximum noise)
  ///
  /// Returns: Map with keys 'encoding', 'coding', 'modulation'
  static Future<Map<String, dynamic>> getOptimalConfiguration({
    required String fileType,
    required double fileSizeKb,
    required double snr,
    required double noiseLevel,
  }) async {
    try {
      // Validate inputs
      if (fileSizeKb < 0) {
        throw ArgumentError('fileSizeKb must be non-negative');
      }
      if (noiseLevel < 0 || noiseLevel > 1) {
        throw ArgumentError('noiseLevel must be between 0 and 1');
      }

      // Prepare request payload
      final payload = {
        'file_type': fileType.toLowerCase(),
        'file_size_kb': fileSizeKb,
        'snr': snr,
        'noise_level': noiseLevel,
      };

      debugPrint('🔄 Requesting AI configuration: $payload');

      // Make HTTP request to Flask API
      final response = await http
          .post(
            Uri.parse('${getApiUrl()}/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeoutDuration);

      // Parse response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final config = {
            'encoding': data['encoding'] as String,
            'coding': data['coding'] as String,
            'modulation': data['modulation'] as String,
            'source': data['source'] ?? 'ai_model',
          };

          debugPrint('✅ AI Configuration received: $config');
          return config;
        } else {
          final error = data['error'] ?? 'Unknown error';
          debugPrint('❌ API returned error: $error');
          throw Exception('AI API error: $error');
        }
      } else {
        debugPrint(
            '❌ API error: ${response.statusCode} - ${response.body}');
        throw Exception(
            'API error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('⏱️ AI API request timed out');
      rethrow;
    } on http.ClientException catch (e) {
      debugPrint('🔌 Network error: $e');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error in getOptimalConfiguration: $e');
      rethrow;
    }
  }

  /// Get configuration with fallback to rule-based logic
  /// 
  /// If AI API is unavailable, returns a sensible default configuration
  /// based on channel conditions
  static Future<Map<String, dynamic>> getConfigurationWithFallback({
    required String fileType,
    required double fileSizeKb,
    required double snr,
    required double noiseLevel,
    required Function fallbackFunction,
  }) async {
    try {
      return await getOptimalConfiguration(
        fileType: fileType,
        fileSizeKb: fileSizeKb,
        snr: snr,
        noiseLevel: noiseLevel,
      );
    } catch (e) {
      debugPrint('⚠️ AI API failed, using fallback: $e');

      if (useFallback) {
        try {
          final fallbackConfig = await fallbackFunction();
          debugPrint('✅ Fallback configuration used: $fallbackConfig');
          return {
            ...fallbackConfig,
            'source': 'fallback_rule_based',
            'note': 'AI server unavailable, using rule-based fallback',
          };
        } catch (fallbackError) {
          debugPrint('❌ Fallback also failed: $fallbackError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Batch get configurations for multiple scenarios
  /// Useful for pre-computing optimal parameters for different channel conditions
  static Future<Map<String, Map<String, dynamic>>>
      getBatchConfigurations({
    required List<Map<String, dynamic>> scenarios,
  }) async {
    final results = <String, Map<String, dynamic>>{};

    for (final scenario in scenarios) {
      try {
        final config = await getOptimalConfiguration(
          fileType: scenario['file_type'] as String? ?? 'image',
          fileSizeKb: scenario['file_size_kb'] as double? ?? 100.0,
          snr: scenario['snr'] as double? ?? 20.0,
          noiseLevel: scenario['noise_level'] as double? ?? 0.1,
        );

        final key = '${scenario['file_type']}_'
            '${scenario['file_size_kb']}_'
            '${scenario['snr']}_'
            '${scenario['noise_level']}';

        results[key] = config;
      } catch (e) {
        debugPrint('⚠️ Batch request failed for scenario $scenario: $e');
      }
    }

    return results;
  }
}
