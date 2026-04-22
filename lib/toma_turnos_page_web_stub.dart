import 'package:flutter/material.dart';

// Stub for web builds: TomaTurnos is Android/tablet-only.
class TomaTurnosPage extends StatelessWidget {
  const TomaTurnosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toma de Turnos')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'La pantalla de toma de turnos no está disponible en la versión web.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
