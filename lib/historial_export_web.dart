// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> exportarExcel(List<int> bytes, context) async {
  final blob = html.Blob([bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'historial_turnos.xlsx')
    ..click();
  html.Url.revokeObjectUrl(url);
}
