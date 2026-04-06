import 'package:cloud_firestore/cloud_firestore.dart';

/// Ejecuta la limpieza y reseteo de turnos pendientes a historial a la 1:00 am.
Future<void> resetTurnosPendientes() async {
  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day, 1, 0, 0);
  final ayer = hoy.subtract(const Duration(days: 1));

  // Solo ejecutar si la hora actual es entre 1:00 y 1:10 am (ventana de 10 minutos)
  if (now.isAfter(hoy) && now.isBefore(hoy.add(const Duration(minutes: 10)))) {
    final turnos = await FirebaseFirestore.instance.collection('turnos').get();
    for (final doc in turnos.docs) {
      final data = doc.data();
      await FirebaseFirestore.instance.collection('turnos_finalizados').add({
        ...data,
        'hora_finalizacion': now.toIso8601String(),
        'reset_automatico': true,
      });
      await doc.reference.delete();
    }
    // Guardar el último reset para reiniciar el conteo
    await FirebaseFirestore.instance.collection('config').doc('reset').set({
      'last_reset': hoy.toIso8601String(),
    });
  }
}

/// Obtiene el número siguiente de turno, reiniciando si es un nuevo día después del reset.
Future<int> getNextTurnoNumber(String tipo) async {
  final config =
      await FirebaseFirestore.instance.collection('config').doc('reset').get();
  DateTime? lastReset;
  if (config.exists && config['last_reset'] != null) {
    lastReset = DateTime.tryParse(config['last_reset']);
  }
  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day, 1, 0, 0);
  final col = FirebaseFirestore.instance.collection('turnos');
  final query = await col
      .where('tipo', isEqualTo: tipo)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .get();
  if (lastReset == null || now.isAfter(hoy) && lastReset.isBefore(hoy)) {
    // Es un nuevo día después del reset, reiniciar a 1
    return 1;
  }
  if (query.docs.isNotEmpty) {
    final last = query.docs.first['numero'] as String;
    final num = int.tryParse(last.substring(1)) ?? 0;
    return num + 1;
  }
  return 1;
}
