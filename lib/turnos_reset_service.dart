import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Ejecuta la limpieza y reseteo de turnos pendientes a las 00:00.
Future<void> resetTurnosPendientes() async {
  final now = DateTime.now();
  final midnightToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
  final configDocRef = FirebaseFirestore.instance
      .collection('config')
      .doc('reset');
  final configDoc = await configDocRef.get();

  final lastReset = configDoc.data()?['last_reset'] != null
      ? DateTime.tryParse(configDoc.data()!['last_reset'])
      : null;

  if (lastReset == null || !isSameDay(lastReset, midnightToday)) {
    // Evitar que resten turnos previos en la vista del administrador.
    final llamados = await FirebaseFirestore.instance
        .collection('turnos_llamados')
        .get();
    for (final doc in llamados.docs) {
      await doc.reference.delete();
    }

    // Mover turnos del día anterior a historial antes de limpiar.
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

    await configDocRef.set({
      'last_reset': midnightToday.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

void startDailyTurnosResetWatcher() {
  Timer.periodic(const Duration(minutes: 1), (_) async {
    final now = DateTime.now();
    if (now.hour == 0 && now.minute == 0) {
      await resetTurnosPendientes();
    }
  });
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
  final hoy = DateTime(now.year, now.month, now.day, 0, 0, 0);
  if (lastReset == null || !isSameDay(lastReset, hoy)) {
    return 1;
  }

  int maxNum = 0;
  final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

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
