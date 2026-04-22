import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

Future<void> exportarExcel(List<int> bytes, context) async {
  // Solicitar permiso de almacenamiento (nota: en Android 11+ este permiso es limitado)
  final status = await Permission.storage.request();
  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permiso de almacenamiento denegado')),
    );
    return;
  }

  try {
    // Intentar guardar en la carpeta Downloads si está disponible
    List<Directory>? downloads =
        await getExternalStorageDirectories(type: StorageDirectory.downloads);
    Directory? targetDir;
    if (downloads != null && downloads.isNotEmpty) {
      targetDir = downloads.first;
    } else {
      targetDir = await getExternalStorageDirectory();
    }

    if (targetDir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo acceder al almacenamiento externo')),
      );
      return;
    }

    final filePath = '${targetDir.path}/historial_turnos.xlsx';
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportado: $filePath')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al exportar: $e')),
    );
  }
}
