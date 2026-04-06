import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HistorialTurnosPage extends StatefulWidget {
  const HistorialTurnosPage({Key? key}) : super(key: key);

  @override
  State<HistorialTurnosPage> createState() => _HistorialTurnosPageState();
}

class _HistorialTurnosPageState extends State<HistorialTurnosPage> {
  bool _exportando = false;

  Future<void> _exportarExcel(List<QueryDocumentSnapshot> docs) async {
    setState(() => _exportando = true);
    final excel = Excel.createExcel();
    final sheet = excel['Turnos'];
    sheet.appendRow([
      'Turno',
      'Tipo',
      'Fecha',
      'Hora Solicitud',
      'Hora Finalización',
      'Tiempo Transcurrido'
    ]);
    for (final doc in docs) {
      final ts = doc['timestamp'];
      final hf = doc['hora_finalizacion'];
      String horaSolicitud = '';
      String horaFinal = '';
      String tiempo = '';
      if (ts != null && hf != null) {
        final inicio = DateTime.tryParse(ts.toString());
        final fin = DateTime.tryParse(hf.toString());
        if (inicio != null && fin != null) {
          final dur = fin.difference(inicio);
          tiempo = dur.inMinutes.toString().padLeft(2, '0') +
              ':' +
              (dur.inSeconds % 60).toString().padLeft(2, '0');
          horaSolicitud =
              inicio.toString().replaceFirst('T', ' ').substring(0, 19);
          horaFinal = fin.toString().replaceFirst('T', ' ').substring(0, 19);
        }
      }
      sheet.appendRow([
        doc['numero'] ?? '',
        doc['tipo'] ?? '',
        doc['fecha'] ?? '',
        horaSolicitud,
        horaFinal,
        tiempo,
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null) return;
    if (await Permission.storage.request().isGranted) {
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/historial_turnos.xlsx');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Archivo guardado en: ${file.path}'),
              backgroundColor: Colors.pink),
        );
      }
    }
    setState(() => _exportando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('HISTORIAL CYC TURNOS',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar Excel',
            onPressed: _exportando
                ? null
                : () async {
                    final snapshot = await FirebaseFirestore.instance
                        .collection('turnos')
                        .orderBy('timestamp', descending: true)
                        .get();
                    await _exportarExcel(snapshot.docs);
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.pink.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Turno',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Tipo',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Fecha',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Hora Solicitud',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Hora Finalización',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Tiempo',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('turnos_finalizados')
                    .orderBy('hora_finalizacion', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.pink));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No hay turnos finalizados',
                            style: TextStyle(
                                color: Colors.pink,
                                fontWeight: FontWeight.bold)));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.pink),
                    itemBuilder: (context, i) {
                      final turno = docs[i];
                      String horaSolicitud = '';
                      String horaFinal = '';
                      String tiempo = '';
                      final ts = turno['timestamp'];
                      final hf = turno['hora_finalizacion'];
                      if (ts != null && hf != null) {
                        final inicio = DateTime.tryParse(ts.toString());
                        final fin = DateTime.tryParse(hf.toString());
                        if (inicio != null && fin != null) {
                          final dur = fin.difference(inicio);
                          tiempo = dur.inMinutes.toString().padLeft(2, '0') +
                              ':' +
                              (dur.inSeconds % 60).toString().padLeft(2, '0');
                          horaSolicitud = inicio
                              .toString()
                              .replaceFirst('T', ' ')
                              .substring(0, 19);
                          horaFinal = fin
                              .toString()
                              .replaceFirst('T', ' ')
                              .substring(0, 19);
                        }
                      }
                      return Container(
                        color: i % 2 == 0 ? Colors.pink.shade50 : Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(turno['numero'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(turno['tipo'] ?? ''),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(turno['fecha'] ?? ''),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(horaSolicitud),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(horaFinal),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(tiempo),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
