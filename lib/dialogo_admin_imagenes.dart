import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DialogoAdminImagenes extends StatefulWidget {
  const DialogoAdminImagenes({Key? key}) : super(key: key);

  @override
  State<DialogoAdminImagenes> createState() => _DialogoAdminImagenesState();
}

class _DialogoAdminImagenesState extends State<DialogoAdminImagenes> {
  final TextEditingController _urlController = TextEditingController();
  bool _loading = false;
  List<String> _urls = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarUrls();
  }

  Future<void> _cargarUrls() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('media')
        .doc('rotador')
        .get();
    if (doc.exists && doc.data() != null && doc['urls'] != null) {
      setState(() {
        _urls = List<String>.from(doc['urls']);
        _loading = false;
      });
    } else {
      setState(() {
        _urls = [];
        _loading = false;
      });
    }
  }

  Future<void> _agregarUrl() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;
    // Si es un enlace de Google Drive, convertirlo al formato directo
    final driveRegex =
        RegExp(r"drive\.google\.com/(?:file/d/|open\?id=)([\w-]+)");
    final match = driveRegex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      url = 'https://drive.google.com/uc?export=download&id=$id';
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docRef =
          FirebaseFirestore.instance.collection('media').doc('rotador');
      await docRef.set({
        'urls': FieldValue.arrayUnion([url])
      }, SetOptions(merge: true));
      _urlController.clear();
      await _cargarUrls();
    } catch (e) {
      setState(() {
        _error = 'Error al agregar: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _eliminarUrl(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docRef =
          FirebaseFirestore.instance.collection('media').doc('rotador');
      await docRef.update({
        'urls': FieldValue.arrayRemove([url])
      });
      await _cargarUrls();
    } catch (e) {
      setState(() {
        _error = 'Error al eliminar: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.image, color: Colors.pink),
          SizedBox(width: 8),
          Text('Administrar imágenes', style: TextStyle(color: Colors.pink)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading) const LinearProgressIndicator(color: Colors.pink),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                  ),
                  onPressed: _loading ? null : _agregarUrl,
                  child: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_urls.isEmpty && !_loading) const Text('No hay imágenes'),
            if (_urls.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final url = _urls[i];
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 140,
                              height: 140,
                              color: Colors.grey.shade200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No se pudo cargar',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar',
                            onPressed:
                                _loading ? null : () => _eliminarUrl(url),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar', style: TextStyle(color: Colors.pink)),
        ),
      ],
    );
  }
}
