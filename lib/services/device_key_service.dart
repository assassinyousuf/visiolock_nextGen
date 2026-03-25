import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceKeyService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Uint8List> generateDeviceKey() async {
    final fingerprint = await _deviceFingerprintString();
    final digest = sha256.convert(utf8.encode(fingerprint));
    return Uint8List.fromList(digest.bytes);
  }

  Future<String> _deviceFingerprintString() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      final parts = <String>[
        'board=${info.board}',
        'bootloader=${info.bootloader}',
        'brand=${info.brand}',
        'device=${info.device}',
        'display=${info.display}',
        'fingerprint=${info.fingerprint}',
        'hardware=${info.hardware}',
        'host=${info.host}',
        'id=${info.id}',
        'manufacturer=${info.manufacturer}',
        'model=${info.model}',
        'product=${info.product}',
        'tags=${info.tags}',
        'type=${info.type}',
        'version.sdkInt=${info.version.sdkInt}',
        'version.release=${info.version.release}',
        if (info.version.securityPatch != null)
          'version.securityPatch=${info.version.securityPatch}',
        if (info.version.baseOS != null) 'version.baseOS=${info.version.baseOS}',
        if (info.version.previewSdkInt != null)
          'version.previewSdkInt=${info.version.previewSdkInt}',
        if (info.version.codename.isNotEmpty)
          'version.codename=${info.version.codename}',
        if (info.version.incremental.isNotEmpty)
          'version.incremental=${info.version.incremental}',
        'isPhysicalDevice=${info.isPhysicalDevice}',
      ];
      return parts.join('|');
    }

    final info = await _deviceInfo.deviceInfo;
    final entries = info.data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('|');
  }
}
