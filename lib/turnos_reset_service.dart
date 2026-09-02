import 'package:cloud_firestore/cloud_firestore.dart';

/// Ejecuta la limpieza y reseteo de turnos pendientes a historial a la 1:00 am.
Future<void> resetTurnosPendientes() async {
  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day, 1, 0, 0);
  final configDoc = await FirebaseFirestore.instance
      .collection('config')
      .doc('reset')
      .get();

  final lastReset = configDoc.data()?['last_reset'] != null
      ? DateTime.tryParse(configDoc.data()!['last_reset'])
      : null;

  if (lastReset == null || lastReset.isBefore(hoy)) {
    // Limpiar turnos llamados activos para que no se vean como atendidos en la vista
    final llamados = await FirebaseFirestore.instance
        .collection('turnos_llamados')
        .get();
    for (final doc in llamados.docs) {
      await doc.reference.delete();
    }

    // Si hay turnos del día anterior, moverlos a historial de forma segura.
    final turnos = await FirebaseFirestore.instance.collection('turnos').get();
    for (final doc in turnos.docs) {
      final data = doc.data();
      await FirebaseFirestore.instance.collection('turnos_finalizados').add({
        ...data,
        'hora_finalizacion': now.toIso8601String(),
        'reset_automatico': true,
        'finalizado_por_reset': true,
      });
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance.collection('config').doc('reset').set({
      'last_reset': hoy.toIso8601String(),
    });
  }
}

/// Obtiene el número siguiente de turno, reiniciando si es un nuevo día después del reset.
Future<int> getNextTurnoNumber(String tipo) async {
  final config = await FirebaseFirestore.instance
      .collection('config')
      .doc('reset')
      .get();
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
