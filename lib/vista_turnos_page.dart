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
    _loadMedia();
    _listenTurnoLlamado();
    _startMediaRotation();
  }

  void _loadMedia() async {
    final doc = await FirebaseFirestore.instance
        .collection('media')
        .doc('rotador')
        .get();
    if (doc.exists && doc['urls'] != null) {
      setState(() {
        _mediaUrls = List<String>.from(doc['urls']);
      });
      _prepareVideoController();
    }
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
      await Future.delayed(const Duration(minutes: 2));
      if (!mounted || _mediaUrls.isEmpty) return false;
      setState(() {
        _mediaIndex = (_mediaIndex + 1) % _mediaUrls.length;
        _prepareVideoController();
      });
      return true;
    });
  }

  void _listenTurnoLlamado() {
    FirebaseFirestore.instance
        .collection('turnos_llamados')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) async {
      final nuevos = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'numero': doc['numero']?.toString() ?? '',
                'tipo': doc['tipo']?.toString() ?? '',
                'fecha': doc['fecha']?.toString() ?? '',
                'hora': doc['hora']?.toString() ?? '',
              })
          .toList();
      if (mounted && nuevos.isNotEmpty) {
        // Detectar si hay un nuevo turno para sonar
        if (_turnosLlamados.isEmpty ||
            nuevos.first['numero'] != _turnosLlamados.first['numero']) {
          await _audioPlayer.play(AssetSource('sounds/turno_bell.mp3'));
        }
        setState(() {
          _turnosLlamados
            ..clear()
            ..addAll(nuevos);
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Vista de Turnos'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
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
      body: Row(
        children: [
          // Lado izquierdo: imágenes/videos
          Expanded(
            flex: 2,
            child: Center(
              child: _mediaUrls.isEmpty
                  ? const Text('No hay imágenes o videos')
                  : _mediaUrls[_mediaIndex].endsWith('.mp4') ||
                          _mediaUrls[_mediaIndex].endsWith('.mov')
                      ? (_videoController != null &&
                              _videoController!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : const CircularProgressIndicator())
                      : Image.network(_mediaUrls[_mediaIndex],
                          fit: BoxFit.contain),
            ),
          ),
          // Lado derecho: turnos llamados
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.pink.shade50,
              child: _turnosLlamados.isEmpty
                  ? const Center(
                      child: Text('Esperando turnos...',
                          style: TextStyle(
                              fontSize: 32,
                              color: Colors.pink,
                              fontWeight: FontWeight.bold)))
                  : ListView.builder(
                      itemCount: _turnosLlamados.length,
                      itemBuilder: (context, i) {
                        final turno = _turnosLlamados[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 8),
                          child: Card(
                            color: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Turno llamado',
                                      style: TextStyle(
                                          fontSize: 22,
                                          color: Colors.pink,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Text(turno['numero'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                  const SizedBox(height: 8),
                                  Text(turno['tipo'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 22, color: Colors.pink)),
                                  const SizedBox(height: 8),
                                  Text(
                                      '${turno['fecha'] ?? ''}  ${turno['hora'] ?? ''}',
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle,
                                            color: Colors.green),
                                        label: const Text('Finalizar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          // Eliminar de turnos_llamados
                                          await FirebaseFirestore.instance
                                              .collection('turnos_llamados')
                                              .doc(turno['id'])
                                              .delete();
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.hourglass_empty,
                                            color: Colors.orange),
                                        label: const Text('Pendiente'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          // Eliminar de turnos_llamados
                                          await FirebaseFirestore.instance
                                              .collection('turnos_llamados')
                                              .doc(turno['id'])
                                              .delete();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
