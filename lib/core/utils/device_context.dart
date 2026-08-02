import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Resolves the Operation Tracking context (§7) — app version, device
/// type/model, and a per-launch session id — once per app run and
/// caches it. Every lookup here is best-effort: if a plugin call fails
/// (unsupported platform, plugin not registered yet, etc.) the relevant
/// field is simply left null rather than throwing, since this backs
/// [AuditLogService] and logging must never be able to break a caller.
class DeviceContext {
  DeviceContext._();
  static final DeviceContext instance = DeviceContext._();

  static const _uuid = Uuid();

  /// One id per app session — generated once, the first time it's
  /// asked for, and shared by every audit entry written during this run.
  final String sessionId = _uuid.v4();

  String? _appVersion;
  String? _deviceType;
  String? _deviceModel;
  bool _resolved = false;

  /// Generates a fresh id for one logical operation (e.g. a bulk
  /// archive of 40 items). Pass the same id to every [AuditLogService]
  /// call that belongs to that operation so they can be grouped later.
  String newOperationId() => _uuid.v4();

  Future<void> _ensureResolved() async {
    if (_resolved) return;
    _resolved = true; // set first — a failed lookup shouldn't retry every call

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Left null.
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await deviceInfo.webBrowserInfo;
        _deviceType = 'web';
        _deviceModel = web.browserName.name;
      } else {
        final android = await _tryAndroid(deviceInfo);
        if (android != null) {
          _deviceType = 'android';
          _deviceModel = android;
          return;
        }
        final ios = await _tryIOS(deviceInfo);
        if (ios != null) {
          _deviceType = 'ios';
          _deviceModel = ios;
        }
      }
    } catch (_) {
      // Left null.
    }
  }

  Future<String?> _tryAndroid(DeviceInfoPlugin plugin) async {
    try {
      final info = await plugin.androidInfo;
      return '${info.manufacturer} ${info.model}';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryIOS(DeviceInfoPlugin plugin) async {
    try {
      final info = await plugin.iosInfo;
      return info.utsname.machine;
    } catch (_) {
      return null;
    }
  }

  Future<String?> get appVersion async {
    await _ensureResolved();
    return _appVersion;
  }

  Future<String?> get deviceType async {
    await _ensureResolved();
    return _deviceType;
  }

  Future<String?> get deviceModel async {
    await _ensureResolved();
    return _deviceModel;
  }
}
