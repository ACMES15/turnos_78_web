import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'permission_helper.dart';
import 'bluetooth_helper.dart';
import 'toma_turnos_page.dart'
    if (dart.library.html) 'toma_turnos_page_web_stub.dart';
import 'admin_turnos_page.dart';
import 'vista_turnos_page.dart';
import 'historial_turnos_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar Firebase solo en plataformas configuradas en `firebase_options.dart`
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      // No detener la app por fallo en la inicialización de Firebase en release.
      // Registramos el error para diagnosticarlo desde el dispositivo.
      // ignore: avoid_print
      print('Error inicializando Firebase: $e');
      // ignore: avoid_print
      print(st);
    }
  } else {
    // Plataforma no soportada por las opciones actuales de Firebase (ej.: Windows, Linux).
    // Omitimos la inicialización para evitar que la app falle en startup.
    // Si necesita Firebase en estas plataformas, genere `firebase_options.dart` apropiado.
  }
  // Pedir permisos de Bluetooth/ubicación en Android al iniciar.
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await PermissionHelper.requestBluetoothAndLocationPermissions();
      // Intentar un escaneo inicial y volcar resultados al log (útil para debug).
      try {
        final devices = await BluetoothHelper.scanForPrinters(
            timeout: const Duration(seconds: 4));
        // ignore: avoid_print
        print(
            'Dispositivos BLE encontrados: ${devices.map((d) => '${d.device.name}(${d.device.id})').toList()}');
      } catch (e) {
        // ignore: avoid_print
        print('Error en escaneo inicial BLE: $e');
      }
    } catch (e) {
      // Ignorar fallos en la petición de permisos; la app debe manejar la ausencia.
      // ignore: avoid_print
      print('Error pidiendo permisos: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turnos 78',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/toma_turnos': (context) => const TomaTurnosPage(),
        '/admin_turnos': (context) => const AdminTurnosPage(),
        '/vista_turnos': (context) => const VistaTurnosPage(),
        '/historial_turnos': (context) => const HistorialTurnosPage(),
      },
    );
  }
}
