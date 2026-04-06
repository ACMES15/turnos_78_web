import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'media_manager.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class AdminTurnosPage extends StatelessWidget {
  const AdminTurnosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Administración de Turnos'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: 'Agregar imágenes/videos',
            onPressed: () async {
              final urls = await MediaManager.pickAndUploadMedia(context);
              if (urls.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('media')
                    .doc('rotador')
                    .set({
                  'urls': urls,
                  'timestamp': DateTime.now(),
                });
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('¡Imágenes/videos subidos!'),
                      backgroundColor: Colors.pink),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Eliminar todas las imágenes/videos',
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('media')
                  .doc('rotador')
                  .get();
              if (doc.exists && doc['urls'] != null) {
                final urls = List<String>.from(doc['urls']);
                // Eliminar de Storage
                for (final url in urls) {
                  try {
                    final ref = await firebase_storage.FirebaseStorage.instance
                        .refFromURL(url);
                    await ref.delete();
                  } catch (_) {}
                }
              }
              await FirebaseFirestore.instance
                  .collection('media')
                  .doc('rotador')
                  .delete();
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('¡Imágenes/videos eliminados!'),
                    backgroundColor: Colors.pink),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                      child: Text('Tipo de turno',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text('Fecha y hora',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text('Acciones',
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
                    .collection('turnos')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.pink));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No hay turnos solicitados',
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
                              flex: 3,
                              child: Center(
                                child: Text(
                                    '${turno['fecha'] ?? ''} ${turno['hora'] ?? ''}'),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.campaign,
                                        color: Colors.pink),
                                    tooltip: 'Llamar',
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('turnos_llamados')
                                          .add({
                                        'numero': turno['numero'] ?? '',
                                        'tipo': turno['tipo'] ?? '',
                                        'fecha': turno['fecha'] ?? '',
                                        'hora': turno['hora'] ?? '',
                                        'timestamp': DateTime.now(),
                                      });
                                      // ignore: use_build_context_synchronously
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Turno ${turno['numero']} llamado'),
                                            backgroundColor: Colors.pink),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.hourglass_empty,
                                        color: Colors.orange),
                                    tooltip: 'Pendiente',
                                    onPressed: () async {
                                      // Eliminar de turnos_llamados si existe
                                      final llamado = await FirebaseFirestore
                                          .instance
                                          .collection('turnos_llamados')
                                          .where('numero',
                                              isEqualTo: turno['numero'])
                                          .limit(1)
                                          .get();
                                      if (llamado.docs.isNotEmpty) {
                                        await llamado.docs.first.reference
                                            .delete();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    tooltip: 'Finalizar',
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      // Copiar el turno a 'turnos_finalizados' con hora de finalización
                                      await FirebaseFirestore.instance
                                          .collection('turnos_finalizados')
                                          .add({
                                        'numero': turno['numero'] ?? '',
                                        'tipo': turno['tipo'] ?? '',
                                        'fecha': turno['fecha'] ?? '',
                                        'hora': turno['hora'] ?? '',
                                        'timestamp': turno['timestamp'],
                                        'hora_finalizacion':
                                            now.toIso8601String(),
                                      });
                                      // Eliminar de la colección turnos_llamados si existe
                                      final llamado = await FirebaseFirestore
                                          .instance
                                          .collection('turnos_llamados')
                                          .where('numero',
                                              isEqualTo: turno['numero'])
                                          .limit(1)
                                          .get();
                                      if (llamado.docs.isNotEmpty) {
                                        await llamado.docs.first.reference
                                            .delete();
                                      }
                                      // Eliminar el turno de la colección principal
                                      await FirebaseFirestore.instance
                                          .collection('turnos')
                                          .doc(turno.id)
                                          .delete();
                                      // ignore: use_build_context_synchronously
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Turno ${turno['numero']} finalizado'),
                                            backgroundColor: Colors.green),
                                      );
                                    },
                                  ),
                                ],
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
