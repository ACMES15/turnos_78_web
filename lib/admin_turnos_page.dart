import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dialogo_admin_imagenes.dart';

class AdminTurnosPage extends StatelessWidget {
  const AdminTurnosPage({Key? key}) : super(key: key);

  static Future<void> _registrarLlamado(
    BuildContext context,
    Map<String, dynamic> turno,
  ) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 3));

    await FirebaseFirestore.instance.collection('turnos_llamados').add({
      'numero': (turno['numero'] ?? '').toString().trim(),
      'tipo': turno['tipo'] ?? '',
      'fecha': turno['fecha'] ?? '',
      'hora': turno['hora'] ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAtLocal': now,
      'llamadoAt': now,
      'expiresAt': expiresAt,
      'finalizado': false,
    });

    Future.delayed(const Duration(minutes: 3), () async {
      final llamado = await FirebaseFirestore.instance
          .collection('turnos_llamados')
          .where('numero', isEqualTo: (turno['numero'] ?? '').toString().trim())
          .get();

      for (final doc in llamado.docs) {
        await doc.reference.delete();
      }
    });

    try {
      await AudioPlayer().play(AssetSource('sounds/dingdong.mp3'));
    } catch (e) {
      print('Error reproduciendo sonido: $e');
    }

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Turno ${turno['numero']} llamado'),
        backgroundColor: Colors.pink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AudioPlayer audioPlayer = AudioPlayer();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade700,
        title: LayoutBuilder(
          builder: (context, constraints) {
            double fontSize = constraints.maxWidth > 600 ? 36 : 24;
            return Text(
              'Administrador de Turnos',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            );
          },
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.image, color: Colors.white),
            label: const Text(
              'Imágenes',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: DialogoAdminImagenes(),
                ),
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
      body: Stack(
        children: [
          Padding(
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
                          child: Text(
                            'Turno',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            'Tipo de turno',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            'Fecha y hora',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            'Acciones',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
                          child: CircularProgressIndicator(color: Colors.pink),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay turnos solicitados',
                            style: TextStyle(
                              color: Colors.pink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['finalizado_por_reset'] == true) {
                          return false;
                        }
                        return !data.containsKey('finalizado') ||
                            data['finalizado'] != true;
                      }).toList();
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('turnos_llamados')
                            .snapshots(),
                        builder: (context, snapshotLlamados) {
                          final llamados = snapshotLlamados.data?.docs ?? [];
                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: Colors.pink),
                            itemBuilder: (context, i) {
                              final turno = docs[i];
                              final numero = (turno['numero'] ?? '')
                                  .toString()
                                  .trim();
                              final tipo = (turno['tipo'] ?? '')
                                  .toString()
                                  .trim();
                              final fechaTurno = (turno['fecha'] ?? '')
                                  .toString()
                                  .trim();
                              final yaLlamado = llamados.any(
                                (ll) =>
                                    (ll['numero']?.toString().trim() ?? '') ==
                                        numero &&
                                    (ll['tipo']?.toString().trim() ?? '') ==
                                        tipo &&
                                    (ll['fecha']?.toString().trim() ?? '') ==
                                        fechaTurno,
                              );
                              return Container(
                                color: yaLlamado
                                    ? Colors.green.shade100
                                    : i % 2 == 0
                                    ? Colors.pink.shade50
                                    : Colors.white,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              turno['numero'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (yaLlamado)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8.0,
                                                ),
                                                child: Text(
                                                  'Llamado',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
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
                                          '${turno['fecha'] ?? ''} ${turno['hora'] ?? ''}',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Center(
                                        child: SizedBox(
                                          width: 180,
                                          height: 52,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.campaign,
                                              size: 24,
                                            ),
                                            label: const Text(
                                              'Llamar',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.pink,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: yaLlamado
                                                ? null
                                                : () async {
                                                    await _registrarLlamado(
                                                      context,
                                                      turno.data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >,
                                                    );
                                                  },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: Builder(
              builder: (context) {
                return FloatingActionButton.extended(
                  onPressed: () async {
                    try {
                      await audioPlayer.play(
                        AssetSource('sounds/dingdong.mp3'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Sonido habilitado!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al habilitar sonido: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Activar sonido'),
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
