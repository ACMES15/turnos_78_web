// Utilidad para cachear el último turno localmente
import 'package:shared_preferences/shared_preferences.dart';

class TurnoCache {
  static const _keyNumero = 'ultimo_turno_numero';
  static const _keyFecha = 'ultimo_turno_fecha';

  static Future<void> guardarTurno(String numero, String fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNumero, numero);
    await prefs.setString(_keyFecha, fecha);
  }

  static Future<Map<String, String?>> obtenerTurno() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'numero': prefs.getString(_keyNumero),
      'fecha': prefs.getString(_keyFecha),
    };
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNumero);
    await prefs.remove(_keyFecha);
  }
}
