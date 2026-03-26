# VisioLock++ Quick Reference Guide

**For maximum speed, use this guide!**

---

## 🎯 Path A: Online AI (API-Based)

### Setup (5 minutes)
```powershell
cd e:\selfwere cross media platform\model_for_visolock

# Start the server (keep this terminal open)
python app.py
```

### In Your App
```dart
import 'package:visiolock_nextgen/services/ai_transmission_service.dart';

// Get AI recommendation
final config = await AiTransmissionService.getOptimalConfiguration(
  fileType: 'image',           // or: audio, video, text
  fileSizeKb: 2048.0,          // file size in KB
  snr: 20.0,                   // signal-to-noise ratio in dB
  noiseLevel: 0.1,             // 0.0 (perfect) to 1.0 (horrible)
);

print(config['encoding']);     // e.g., 'AES-256'
print(config['coding']);       // e.g., 'RS'
print(config['modulation']);   // e.g., '64-QAM'
```

**Pros**: Easy, updates without rebuilding app  
**Cons**: Needs network, slower (100-200ms)

---

## 🚀 Path B: Offline AI (TFLite - Best for Production)

### Step 1: Generate Model (First Time Only)
```powershell
cd e:\selfwere cross media platform\model_for_visolock

# Install TensorFlow (one-time)
pip install tensorflow

# Train the model
python train_tflite_model.py
```

**Output:**
```
✓ Test Accuracy: 92.34%
✓ Model size: 145.32 KB

// Dart config values (copy these):
final List<String> targetClasses = [
  'AES-128+RS+16-QAM',  // index 0
  'AES-128+RS+64-QAM',  // index 1
  ...
];

final double meanFileSize = 2500.0;
final double meanSnr = 17.5;
...
```

### Step 2: Copy Model to Assets
```powershell
# Create folder
mkdir assets\models

# Copy model file
copy "e:\selfwere cross media platform\model_for_visolock\adaptive_model.tflite" "assets\models\"
```

### Step 3: Update Configuration
Edit [lib/services/offline_transmission_ai.dart](lib/services/offline_transmission_ai.dart):
- Replace `targetClasses` list (copy from Python output)
- Replace `fileTypes` list (copy from Python output)
- Replace scaler parameters: `meanFileSize`, `scaleFileSize`, `meanSnr`, `scaleSnr`, `meanNoise`, `scaleNoise`

### Step 4: Initialize in App
```dart
// In main.dart, call at startup:
final ai = OfflineTransmissionAI();
await ai.loadModel();  // Loads from assets
```

### Step 5: Use in Your App
```dart
import 'package:visiolock_nextgen/services/offline_transmission_ai.dart';

final ai = OfflineTransmissionAI();

// Get AI recommendation (NO INTERNET NEEDED!)
final config = ai.predictConfig(
  fileType: 'image',           // or: audio, video, text
  fileSizeKb: 2048.0,          // file size in KB
  snr: 20.0,                   // signal-to-noise ratio in dB  
  noiseLevel: 0.1,             // 0.0 (perfect) to 1.0 (horrible)
);

print(config['encoding']);     // e.g., 'AES-256'
print(config['coding']);       // e.g., 'RS'
print(config['modulation']);   // e.g., '64-QAM'
print(config['confidence']);   // e.g., '0.95'
```

**Pros**: Zero network dependency, fastest (10-50ms), best privacy  
**Cons**: Model bundled with app, needs retraining to update

---

## 📖 Complete Integration Example

### Full Sender Screen Example
```dart
import 'package:flutter/material.dart';
import 'package:visiolock_nextgen/services/offline_transmission_ai.dart';
import 'package:visiolock_nextgen/services/channel_state_estimator_service.dart';

class SenderScreen extends StatefulWidget {
  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  String? selectedFile;
  Map<String, dynamic>? aiConfig;
  bool isAnalyzing = false;

  Future<void> analyzeAndTransmit() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() => isAnalyzing = true);

    try {
      // Step 1: Estimate channel conditions
      final channelEstimator = ChannelStateEstimatorService();
      final channelInfo = await channelEstimator.estimateChannelState();

      final snr = channelInfo['snr'] as double? ?? 20.0;
      final noiseLevel = channelInfo['noise_level'] as double? ?? 0.1;

      // Step 2: Get file info
      final fileSize = 2048.0; // Get from file system
      final fileType = 'image'; // Detect from extension

      // Step 3: Get AI recommendation
      final ai = OfflineTransmissionAI();
      final config = ai.predictConfig(
        fileType: fileType,
        fileSizeKb: fileSize,
        snr: snr,
        noiseLevel: noiseLevel,
      );

      setState(() => aiConfig = config);

      // Step 4: Show recommendation
      _showConfigDialog(config, snr, noiseLevel);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isAnalyzing = false);
    }
  }

  void _showConfigDialog(
    Map<String, dynamic> config,
    double snr,
    double noise,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Recommendation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('File: $selectedFile'),
            const SizedBox(height: 10),
            Text('Channel: SNR=${snr.toStringAsFixed(1)}dB, Noise=$noise'),
            const SizedBox(height: 20),
            Text('🎯 Recommended Configuration:'),
            const SizedBox(height: 10),
            Text('Encoding: ${config['encoding']}'),
            Text('Coding: ${config['coding']}'),
            Text('Modulation: ${config['modulation']}'),
            Text(
              'Confidence: ${(double.parse(config['confidence'] ?? '0') * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _startTransmission(config);
            },
            child: const Text('Transmit'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTransmission(Map<String, dynamic> config) async {
    // Implement transmission with recommended config
    debugPrint('Starting transmission with: $config');
    // ... transmission logic ...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send File')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isAnalyzing ? null : () {
                // File picker logic
                setState(() => selectedFile = 'sample.jpg');
              },
              child: Text(selectedFile ?? 'Select File'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isAnalyzing ? null : analyzeAndTransmit,
              child: isAnalyzing
                  ? const CircularProgressIndicator()
                  : const Text('Analyze & Transmit'),
            ),
            if (aiConfig != null) ...[
              const SizedBox(height: 30),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Current Configuration:'),
                      Text('Encoding: ${aiConfig!['encoding']}'),
                      Text('Coding: ${aiConfig!['coding']}'),
                      Text('Modulation: ${aiConfig!['modulation']}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## 🔧 Common Tasks

### Check if Offline Model is Loaded
```dart
final ai = OfflineTransmissionAI();
if (ai.isModelLoaded) {
  print('✅ Model ready');
} else {
  print('❌ Model not loaded, call await ai.loadModel()');
}
```

### Get Model Info (for debugging)
```dart
final ai = OfflineTransmissionAI();
ai.printModelInfo();
// Output: Classes: 12, File Types: 5, ...
```

### Batch Predictions
```dart
final ai = OfflineTransmissionAI();

final scenarios = [
  {'fileType': 'image', 'fileSizeKb': 2048.0, 'snr': 20.0, 'noiseLevel': 0.1},
  {'fileType': 'video', 'fileSizeKb': 5000.0, 'snr': 15.0, 'noiseLevel': 0.3},
];

final results = await ai.batchPredict(scenarios: scenarios);
for (var result in results) {
  print('${result['fileType']}: ${result['prediction']}');
}
```

### Fallback Logic
```dart
final ai = OfflineTransmissionAI();

Map<String, dynamic> config;

if (ai.isModelLoaded) {
  config = ai.predictConfig(...);  // Use AI
} else {
  // Use rule-based fallback
  config = {
    'encoding': 'AES-128',
    'coding': 'RS',
    'modulation': '16-QAM',
    'source': 'fallback',
  };
}
```

### Cleanup (on app exit)
```dart
@override
void dispose() {
  OfflineTransmissionAI().dispose();  // Release resources
  super.dispose();
}
```

---

## 🐛 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| `Failed to load TFLite model` | 1. Check `assets/models/adaptive_model.tflite` exists 2. Run `flutter clean` 3. Check `pubspec.yaml` has the asset |
| `Invalid file type index` | Update `fileTypes` list in offline_transmission_ai.dart (copy from Python) |
| `Wrong predictions` | Verify `targetClasses` list matches Python output exactly |
| `API timeout` | Increase timeout in `ai_transmission_service.dart` (line: `const Duration(seconds: 10)`) |
| `Can't connect to API server` | Android emulator: use `10.0.2.2`, physical device: use machine IP |

---

## 📊 Comparison Table

| Feature | Online API | Offline TFLite |
|---------|-----------|----------------|
| Setup time | 2 min | 10 min (first time) |
| Inference time | 100-200ms | 10-50ms |
| Network needed | ✅ Yes | ❌ No |
| Model updates | ✅ Easy (no rebuild) | ❌ Needs rebuild |
| Model accuracy | 80%+ | 85%+ |
| Privacy | ⚠️ Data sent | ✅ Local only |
| Server needed | ✅ Yes | ❌ No |
| Recommended for | Testing, multi-user | Production, offline |

---

## 💡 Best Practices

### 1. Initialize AI Early
```dart
// In main() or app startup
final ai = OfflineTransmissionAI();
await ai.loadModel();
```

### 2. Always Include Fallback
```dart
try {
  final config = OfflineTransmissionAI().predictConfig(...);
} catch (e) {
  // Fallback to default
  final config = {'encoding': 'AES-128', 'coding': 'RS', 'modulation': '16-QAM'};
}
```

### 3. Cache Recommendations for Same Conditions
```dart
final configCache = <String, Map<String, dynamic>>{};

Map<String, dynamic> getCachedConfig(String key) {
  if (configCache.containsKey(key)) {
    return configCache[key]!;  // Return cached
  }
  
  final config = ai.predictConfig(...);
  configCache[key] = config;
  return config;
}
```

### 4. Monitor Confidence Scores
```dart
final config = ai.predictConfig(...);
final confidence = double.parse(config['confidence'] ?? '0');

if (confidence < 0.7) {
  print('⚠️ Low confidence (${confidence}), consider manual override');
}
```

### 5. Log Everything
```dart
debugPrint('Input: fileType=$fileType, size=$fileSizeKb, snr=$snr, noise=$noiseLevel');
debugPrint('Output: $config');
```

---

## 🚀 Next Steps

- [ ] Choose **Path A (API)** or **Path B (TFLite)**
- [ ] Follow setup steps above
- [ ] Test with sample values
- [ ] Integrate into your screens
- [ ] Test with real files
- [ ] Build and deploy!

---

**📚 For more detail, see:**
- [AI_INTEGRATION_GUIDE.md](AI_INTEGRATION_GUIDE.md) - Full API guid
- [OFFLINE_AI_GUIDE.md](OFFLINE_AI_GUIDE.md) - Full TFLite guide
- [COMPLETE_IMPLEMENTATION_SUMMARY.md](COMPLETE_IMPLEMENTATION_SUMMARY.md) - Big picture

**Done! 🎉**
