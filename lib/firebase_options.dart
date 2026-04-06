// Archivo generado automáticamente para la configuración de Firebase.
// Debes reemplazar los valores con los de tu proyecto en Firebase Console.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBBd2bDrLzC34uuHZ0hOpm9ZVOj7N6N7Z0",
    authDomain: "turnos78web.firebaseapp.com",
    projectId: "turnos78web",
    storageBucket: "turnos78web.firebasestorage.app",
    messagingSenderId: "272159311295",
    appId: "1:272159311295:web:635bc93ca6fec320ec0d0a",
    measurementId: "G-DDPBCYXX3H",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAz2MPjpL0Clq9vgwnKay0yXgcAcFOtFG8',
    appId: '1:272159311295:android:8526f2dc4d919951ec0d0a',
    messagingSenderId: '272159311295',
    projectId: 'turnos78web',
    storageBucket: 'turnos78web.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TU_API_KEY_IOS',
    appId: 'TU_APP_ID_IOS',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    projectId: 'TU_PROJECT_ID',
    storageBucket: 'TU_STORAGE_BUCKET',
    iosClientId: 'TU_IOS_CLIENT_ID',
    iosBundleId: 'TU_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TU_API_KEY_MACOS',
    appId: 'TU_APP_ID_MACOS',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    projectId: 'TU_PROJECT_ID',
    storageBucket: 'TU_STORAGE_BUCKET',
    iosClientId: 'TU_MACOS_CLIENT_ID',
    iosBundleId: 'TU_MACOS_BUNDLE_ID',
  );
}
