import 'package:permission_handler/permission_handler.dart';

/// Helper para solicitar permisos relacionados con Bluetooth y ubicación.
class PermissionHelper {
  /// Solicita permisos de Bluetooth y ubicación necesarios en Android 12+.
  /// Devuelve `true` si todos los permisos requeridos fueron concedidos.
  static Future<bool> requestBluetoothAndLocationPermissions() async {
    final List<Permission> permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    // Solicitar todos los permisos a la vez.
    final statuses = await permissions.request();

    // Verificar que todos estén concedidos.
    bool allGranted = true;
    for (final p in permissions) {
      final status = statuses[p];
      if (status == null || !status.isGranted) {
        allGranted = false;
        break;
      }
    }

    if (!allGranted) {
      // Si algún permiso está permanentemente denegado, guiar al usuario a ajustes.
      final permanentlyDenied =
          statuses.values.any((s) => s.isPermanentlyDenied);
      if (permanentlyDenied) {
        // Abrir la pantalla de ajustes de la app para que el usuario habilite permisos.
        await openAppSettings();
      }
    }

    return allGranted;
  }
}
