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
      withData: true, // importante para web
    );
    if (result == null) return [];
    final files = result.files;
    List<String> urls = [];
    for (final file in files.take(10)) {
      final ref = FirebaseStorage.instance.ref().child('media/${file.name}');
      if (file.bytes != null) {
        // Para web y fallback universal
        final uploadTask = await ref.putData(file.bytes!);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } else if (file.path != null) {
        // Para Windows/Linux/Mac
        final uploadTask = await ref.putFile(File(file.path!));
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
    }
    return urls;
  }
}
