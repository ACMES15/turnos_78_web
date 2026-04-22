// Minimal shim to satisfy `package:firebase_storage` usage on web builds.
// This file is only imported on web via conditional import.

import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class FirebaseStorage {
  FirebaseStorage._();
  static final FirebaseStorage instance = FirebaseStorage._();

  Reference ref([String? path]) => Reference(path: path ?? '');
}

class Reference {
  final String path;
  Uint8List? _bytes;

  Reference({required this.path});

  Reference child(String childPath) =>
      Reference(path: path.isEmpty ? childPath : '\$path/\$childPath');

  Future<UploadTask> putData(Uint8List data) async {
    _bytes = data;
    // simulate async upload
    await Future.delayed(const Duration(milliseconds: 150));
    return UploadTask._(this);
  }

  Future<UploadTask> putFile(dynamic /*File*/ file) async {
    // On web, File won't be available; behave like putData if file has bytes
    if (file is html.File) {
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoad.listen((_) {
        final result = reader.result as List<int>;
        completer.complete(Uint8List.fromList(result));
      });
      reader.readAsArrayBuffer(file);
      final bytes = await completer.future;
      return putData(bytes);
    }
    // fallback
    await Future.delayed(const Duration(milliseconds: 100));
    return UploadTask._(this);
  }

  Future<String> getDownloadURL() async {
    if (_bytes == null) return '';
    final blob = html.Blob([_bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    return url;
  }
}

class UploadTask {
  final Reference _ref;
  UploadTask._(this._ref);

  Future<UploadTaskSnapshot> whenComplete([FutureOr Function()? action]) async {
    if (action != null) await action();
    return UploadTaskSnapshot();
  }

  Future<UploadTaskSnapshot> then([_]) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return UploadTaskSnapshot();
  }
}

class UploadTaskSnapshot {}
