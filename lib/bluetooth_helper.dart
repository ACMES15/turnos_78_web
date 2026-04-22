import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'permission_helper.dart';

/// Helper para escanear dispositivos Bluetooth LE (usado para detectar impresoras).
class BluetoothHelper {
  /// Escanea durante [timeout] y devuelve los resultados únicos.
  static Future<List<ScanResult>> scanForPrinters(
      {Duration timeout = const Duration(seconds: 5)}) async {
    // Solo en plataformas Android/iOS
    if (kIsWeb) return [];

    final granted =
        await PermissionHelper.requestBluetoothAndLocationPermissions();
    if (!granted) return [];

    final Map<String, ScanResult> found = {};

    StreamSubscription<List<ScanResult>>? sub;
    try {
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          found[r.device.id.id] = r;
        }
      });

      // Iniciar y esperar el timeout
      FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(timeout + const Duration(milliseconds: 300));
      FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignorar errores de escaneo.
    } finally {
      await sub?.cancel();
    }

    return found.values.toList();
  }
}
