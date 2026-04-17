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
  // Si es un nuevo día después del reset, reiniciar a 1
  if (lastReset == null || (now.isAfter(hoy) && lastReset.isBefore(hoy))) {
    return 1;
  }
  // Buscar el mayor número del día en las 3 colecciones usando ambos campos para filtrar
  int maxNum = 0;
  final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  // turnos
  final turnos = await FirebaseFirestore.instance
      .collection('turnos')
      .where('tipo', isEqualTo: tipo)
      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
      .where('timestamp', isLessThanOrEqualTo: endOfDay)
      .get();
  for (final doc in turnos.docs) {
    DateTime? fecha;
    final ts = doc['timestamp'];
    final local = doc['createdAtLocal'];
    if (ts != null && ts is Timestamp) {
      fecha = ts.toDate();
    } else if (local != null && local is Timestamp) {
      fecha = local.toDate();
    } else if (local != null && local is DateTime) {
      fecha = local;
    }
    if (fecha != null &&
        fecha.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        fecha.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
      final n = int.tryParse((doc['numero'] as String).substring(1)) ?? 0;
      if (n > maxNum) maxNum = n;
    }
  }
  // turnos_llamados
  final llamados = await FirebaseFirestore.instance
      .collection('turnos_llamados')
      .where('tipo', isEqualTo: tipo)
      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
      .where('timestamp', isLessThanOrEqualTo: endOfDay)
      .get();
  for (final doc in llamados.docs) {
    DateTime? fecha;
    final ts = doc['timestamp'];
    final local = doc['createdAtLocal'];
    if (ts != null && ts is Timestamp) {
      fecha = ts.toDate();
    } else if (local != null && local is Timestamp) {
      fecha = local.toDate();
    } else if (local != null && local is DateTime) {
      fecha = local;
    }
    if (fecha != null &&
        fecha.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        fecha.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
      final n = int.tryParse((doc['numero'] as String).substring(1)) ?? 0;
      if (n > maxNum) maxNum = n;
    }
  }
  // turnos_finalizados
  final finalizados = await FirebaseFirestore.instance
      .collection('turnos_finalizados')
      .where('tipo', isEqualTo: tipo)
      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
      .where('timestamp', isLessThanOrEqualTo: endOfDay)
      .get();
  for (final doc in finalizados.docs) {
    DateTime? fecha;
    final ts = doc['timestamp'];
    final local = doc['createdAtLocal'];
    if (ts != null && ts is Timestamp) {
      fecha = ts.toDate();
    } else if (local != null && local is Timestamp) {
      fecha = local.toDate();
    } else if (local != null && local is DateTime) {
      fecha = local;
    }
    if (fecha != null &&
        fecha.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        fecha.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
      final n = int.tryParse((doc['numero'] as String).substring(1)) ?? 0;
      if (n > maxNum) maxNum = n;
    }
  }
  return maxNum + 1;
}
