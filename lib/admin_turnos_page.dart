import 'package:flutter/material.dart';

class AdminTurnosPage extends StatelessWidget {
  const AdminTurnosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Administración de Turnos'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings,
                  size: 64, color: Colors.pink.shade200),
              const SizedBox(height: 16),
              const Text('Administrar turnos',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink)),
              const SizedBox(height: 24),
              const Text('Aquí puedes administrar los turnos',
                  style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
