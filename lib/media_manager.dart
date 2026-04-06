import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MediaManager {
  static Future<List<String>> pickAndUploadMedia(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );
    if (result == null) return [];
    final files = result.files;
    List<String> urls = [];
    for (final file in files.take(10)) {
      final path = file.path;
      if (path == null) continue;
      final ref = FirebaseStorage.instance.ref().child('media/${file.name}');
      final uploadTask = await ref.putFile(File(path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }
}
