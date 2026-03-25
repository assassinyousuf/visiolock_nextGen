import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<void> requestImagePickerPermissions() async {
    await _requestMediaAccess(_MediaKind.images);
  }

  static Future<void> requestAudioPickerPermissions() async {
    await _requestMediaAccess(_MediaKind.audio);
  }

  static Future<void> requestAudioSavePermissions() async {
    // Saving into /storage/emulated/0/EncryptAudio requires broad filesystem
    // access on modern Android (scoped storage).
    await _requestExternalWriteAccessIfNeeded();
  }

  static Future<void> requestDecodedImageSavePermissions() async {
    // Saving into /storage/emulated/0/DecodedImage requires broad filesystem
    // access on modern Android (scoped storage).
    await _requestExternalWriteAccessIfNeeded();
  }

  static Future<void> _requestMediaAccess(_MediaKind kind) async {
    if (!Platform.isAndroid) {
      return;
    }

    final sdkInt = await _androidSdkInt();
    if (sdkInt == null) {
      // Best-effort: still request legacy storage.
      await Permission.storage.request();
      return;
    }

    if (sdkInt >= 33) {
      if (kind == _MediaKind.images) {
        await Permission.photos.request();
      } else {
        await Permission.audio.request();
      }
      return;
    }

    await Permission.storage.request();
  }

  static Future<void> _requestExternalWriteAccessIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }

    final sdkInt = await _androidSdkInt();
    if (sdkInt == null) {
      await Permission.storage.request();
      return;
    }

    // Android 11+ requires MANAGE_EXTERNAL_STORAGE to write arbitrary folders
    // under /storage/emulated/0.
    if (sdkInt >= 30) {
      await Permission.manageExternalStorage.request();
      return;
    }

    // Older devices can rely on legacy storage permission.
    await Permission.storage.request();
  }

  static Future<int?> _androidSdkInt() async {
    try {
      final info = await _deviceInfo.androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return null;
    }
  }
}

enum _MediaKind { images, audio }
