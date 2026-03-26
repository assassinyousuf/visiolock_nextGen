# VisioLock++ Complete Setup Guide

This guide walks you through setting up VisioLock++ with the AI-powered adaptive transmission system.

## Prerequisites

- **Flutter SDK**: 3.9.2 or higher
- **Dart SDK**: Included with Flutter
- **Python**: 3.8 or higher (for AI backend)
- **Android SDK** (for Android builds)
- **Git** (optional, for version control)

## Part 1: Flutter Application Setup

### Step 1: Install Flutter Dependencies

```bash
cd "e:\selfwere cross media platform"
flutter pub get
```

Expected output:
```
✓ Running "flutter pub get" in VisioLock++...
✓ 1234 packages resolved in 25 seconds
```

### Step 2: Verify Flutter Setup

```bash
flutter doctor
```

Ensure all checks pass (or address any warnings).

### Step 3: Run on Emulator/Device

**Android Emulator:**
```bash
flutter run
```

**Physical Android Device:**
1. Enable USB Debugging on device
2. Connect device via USB
3. Run: `flutter run -d <device_id>`

**iOS/macOS/Windows/Linux:**
Follow platform-specific instructions in Flutter documentation.

## Part 2: AI Model Backend Setup

### Step 1: Navigate to Model Directory

```bash
cd model_for_visolock
```

### Step 2: Create Virtual Environment (Recommended)

**On Windows:**
```bash
python -m venv venv
venv\Scripts\activate
```

**On macOS/Linux:**
```bash
python3 -m venv venv
source venv/bin/activate
```

### Step 3: Install Python Dependencies

```bash
pip install --upgrade pip
pip install flask joblib scikit-learn pandas numpy
```

Verify installation:
```bash
python -c "import flask, joblib, sklearn, pandas; print('✓ All dependencies installed')"
```

### Step 4: Verify Model File

Check that `adaptive_model.pkl` exists:

```bash
# Windows
if exist adaptive_model.pkl (echo Model file found)

# macOS/Linux
ls -l adaptive_model.pkl
```

If missing, retrain the model:
```bash
python train_model.py
```

### Step 5: Start the Flask API Server

```bash
python app.py
```

Expected output:
```
 * Serving Flask app 'app'
 * Debug mode: off
WARNING: This is a development server. Do not use it in production.
 * Running on http://127.0.0.1:5000
✓ AI Model loaded successfully
```

**Keep this terminal open** while using the app.

## Part 3: Configure API Connection

The `ai_transmission_service.dart` is pre-configured for most scenarios. Adjust if needed:

### For Physical Android Device

Edit `lib/services/ai_transmission_service.dart`:

```dart
// Replace 127.0.0.1 with your machine's IP (e.g., 192.168.1.100)
static const String apiUrl = 'http://192.168.1.100:5000';
```

To find your machine's IP:

**Windows:**
```bash
ipconfig
# Look for "IPv4 Address" under your network adapter
```

**macOS/Linux:**
```bash
ifconfig
# Look for inet address under your network interface
```

### For Android Emulator

No changes needed - automatically uses `http://10.0.2.2:5000`

## Part 4: Integration Points

### Example: Sender Screen Integration

After file selection, before transmission:

```dart
import 'package:visiolock_nextgen/services/ai_transmission_service.dart';

// Check server availability
bool serverAvailable = await AiTransmissionService.isServerAvailable();

if (serverAvailable) {
  // Get AI recommendation
  final config = await AiTransmissionService.getOptimalConfiguration(
    fileType: 'image',
    fileSizeKb: selectedFile.size / 1024,
    snr: estimatedSNR,  // From ChannelStateEstimatorService
    noiseLevel: estimatedNoise,
  );
  
  // Use recommended config for transmission
  applyTransmissionConfig(config);
} else {
  // Fallback to rule-based logic
  applyFallbackConfig();
}
```

## Part 5: Troubleshooting

### Issue: Flutter doctor shows VS Code version error

```
VS Code (version unknown)
Unable to determine VS Code version.
```

**Solution**: Create a directory junction in VS Code install folder
```bash
cd "C:\Users\<user>\AppData\Local\Programs\Microsoft VS Code"
mklink /D Resources <latest_commit_hash>\resources
```

Then run `flutter doctor -v` again.

### Issue: Android emulator cannot connect to Flask server

**Check 1**: Ensure Flask is running on correct port
```bash
# Windows - check port 5000 is in use
netstat -ano | findstr :5000
```

**Check 2**: Verify emulator can access host
```bash
# From emulator terminal
adb shell ping 10.0.2.2
```

**Check 3**: Update API URL in code if needed

### Issue: Python module not found

```
ModuleNotFoundError: No module named 'flask'
```

**Solution**: Reinstall dependencies
```bash
pip install --upgrade flask joblib scikit-learn pandas numpy
```

### Issue: Model file not found

```
FileNotFoundError: adaptive_model.pkl
```

**Solution**: Retrain the model
```bash
python train_model.py
python app.py
```

## Part 6: Building for Release

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Web

```bash
flutter build web --release
```

Output: `build/web/`

### Windows

```bash
flutter build windows --release
```

Output: `build/windows/runner/Release/`

### macOS

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/`

### Linux

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/`

## Part 7: Deployment

### Local Network Testing

1. Find machine IP: `ipconfig` (Windows) or `ifconfig` (macOS/Linux)
2. Update API URL in `ai_transmission_service.dart`
3. Update firewall to allow port 5000:
   - Windows: Allow Python in Windows Defender Firewall
   - macOS: Check System Preferences → Security & Privacy
   - Linux: `sudo ufw allow 5000`
4. Run Flask server: `python app.py`
5. Test from device: `http://<machine_ip>:5000/health`

### Production Deployment

For production, use proper WSGI server instead of Flask development server:

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

Or use Docker for containerization.

## Part 8: Performance Optimization

### Dart/Flutter Side

- Cache frequently used configurations
- Batch predictions when possible
- Implement request timeouts (default: 10 seconds)

### Python/Flask Side

- Use production WSGI server (Gunicorn, uWSGI)
- Implement caching for model predictions
- Monitor memory usage: `memory_profiler`
- Profile code: `cProfile`

## Part 9: Monitoring & Logs

### Flask Server Logs

Check for errors and performance metrics:
```
✓ AI Model loaded successfully
INFO:requests: {start} - /predict (200)
```

### Dart Logs

In Flutter inspector or terminal:
```
✅ AI Configuration received: {encoding: ..., coding: ..., modulation: ...}
❌ AI Server unavailable: Network error
⏱️ AI API request timed out
```

## Part 10: Updating Dependencies

### Flutter Packages

```bash
flutter pub upgrade
```

### Python Packages

```bash
pip install --upgrade flask joblib scikit-learn pandas numpy
```

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [scikit-learn Documentation](https://scikit-learn.org/stable/)
- [AI_INTEGRATION_GUIDE.md](AI_INTEGRATION_GUIDE.md)

## Support

For issues:
1. Check logs in Flask console and Flutter output
2. Verify network connectivity between device and server
3. Review error messages and troubleshooting section
4. Check file permissions and firewall settings
