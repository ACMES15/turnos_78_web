import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

class VistaTurnosPage extends StatefulWidget {
  const VistaTurnosPage({Key? key}) : super(key: key);

  @override
  State<VistaTurnosPage> createState() => _VistaTurnosPageState();
}

class _VistaTurnosPageState extends State<VistaTurnosPage> {
  int _mediaIndex = 0;
  List<String> _mediaUrls = [];
  VideoPlayerController? _videoController;
  final List<Map<String, dynamic>> _turnosLlamados = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _listenTurnoLlamado();
    // Escuchar cambios en las URLs de media para web/APP and actualizar rotador
    FirebaseFirestore.instance
        .collection('media')
        .doc('rotador')
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc['urls'] != null) {
            final urls = List<String>.from(doc['urls']);
            if (mounted) {
              setState(() {
                _mediaUrls = urls;
              });
              _prepareVideoController();
            }
          } else {
            if (mounted) {
              setState(() {
                _mediaUrls = [];
              });
              _videoController?.dispose();
              _videoController = null;
            }
          }
        });

    _startMediaRotation();
  }

  void _prepareVideoController() {
    if (_mediaUrls.isEmpty) return;
    final url = _mediaUrls[_mediaIndex];
    if (url.endsWith('.mp4') || url.endsWith('.mov')) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.network(url)
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
        });
    } else {
      _videoController?.dispose();
      _videoController = null;
    }
  }

  void _startMediaRotation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (!mounted) return false;
      setState(() {
        _mediaIndex =
            (_mediaIndex + 1) % (_mediaUrls.isNotEmpty ? _mediaUrls.length : 1);
      });
      return true;
    });
  }

  void _listenTurnoLlamado() {
    FirebaseFirestore.instance
        .collection('turnos_llamados')
        .where('finalizado', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
          // DEBUG: imprimir documentos recibidos en consola
          print('turnos_llamados recibidos:');
          for (final doc in snapshot.docs) {
            print(doc.data());
          }

          final now = DateTime.now();
          final activos = snapshot.docs.where((doc) {
            final expiresAt = doc['expiresAt'];
            if (expiresAt is Timestamp) {
              return now.isBefore(expiresAt.toDate()) ||
                  now.isAtSameMomentAs(expiresAt.toDate());
            }
            if (expiresAt is DateTime) {
              return now.isBefore(expiresAt) || now.isAtSameMomentAs(expiresAt);
            }
            return true;
          }).toList();

          final nuevos = activos
              .map(
                (doc) => {
                  'id': doc.id,
                  'numero': doc['numero']?.toString() ?? '',
                  'tipo': doc['tipo']?.toString() ?? '',
                  'fecha': doc['fecha']?.toString() ?? '',
                  'hora': doc['hora']?.toString() ?? '',
                  'timestamp': doc['timestamp'] ?? doc['createdAtLocal'],
                },
              )
              .toList();
          nuevos.sort((a, b) {
            final ta = a['timestamp'];
            final tb = b['timestamp'];
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return (tb as Comparable).compareTo(ta);
          });
          final ultimos = nuevos.take(10).toList();
          if (mounted) {
            if (ultimos.isNotEmpty &&
                (_turnosLlamados.isEmpty ||
                    ultimos.first['numero'] !=
                        _turnosLlamados.first['numero'])) {
              try {
                await _audioPlayer.play(AssetSource('sounds/dingdong.mp3'));
              } catch (e) {
                print('Error reproduciendo sonido: $e');
              }
            }
            setState(() {
              _turnosLlamados
                ..clear()
                ..addAll(ultimos);
            });
          }
        });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // Widget para mostrar cualquier tipo de media
  Widget _buildMediaWidget(String url) {
    if (url.endsWith('.mp4') || url.endsWith('.mov')) {
      if (_videoController != null &&
          _videoController!.value.isInitialized &&
          _videoController!.dataSource == url) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      } else {
        return const CircularProgressIndicator();
      }
    } else if (url.endsWith('.gif')) {
      // Los GIFs animados se muestran igual que imágenes normales en Flutter
      return Image.network(url, fit: BoxFit.contain);
    } else {
      // Cualquier otro formato de imagen
      return Image.network(url, fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: LayoutBuilder(
          builder: (context, constraints) {
            double fontSize = constraints.maxWidth > 600 ? 36 : 24;
            return Text(
              'LIVERPOOL GALERIAS',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            );
          },
        ),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('media')
            .doc('rotador')
            .snapshots(),
        builder: (context, snapshot) {
          final mediaUrls = _mediaUrls;
          // Mantener el índice dentro del rango
          if (mediaUrls.isEmpty) {
            _mediaIndex = 0;
          } else if (_mediaIndex >= mediaUrls.length) {
            _mediaIndex = 0;
          }
          return Row(
            children: [
              // Lado izquierdo: imágenes/videos
              Expanded(
                flex: 2,
                child: Center(
                  child: mediaUrls.isEmpty
                      ? const Text('No hay imágenes o videos')
                      : _buildMediaWidget(mediaUrls[_mediaIndex]),
                ),
              ),
              // Lado derecho: turnos llamados
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.pink.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _turnosLlamados.isEmpty
                            ? const Center(
                                child: Text(
                                  'Esperando turnos...',
                                  style: TextStyle(
                                    fontSize: 32,
                                    color: Colors.pink,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _turnosLlamados.length,
                                itemBuilder: (context, i) {
                                  final turno = _turnosLlamados[i];
                                  final numero = (turno['numero'] ?? '')
                                      .toString();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 32,
                                      horizontal: 8,
                                    ),
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Center(
                                          child: Text(
                                            numero.isNotEmpty
                                                ? ' ' + numero
                                                : '---',
                                            style: const TextStyle(
                                              fontSize: 96,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.pink,
                                              letterSpacing: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
