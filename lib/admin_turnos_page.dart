import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTurnosPage extends StatelessWidget {
  const AdminTurnosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Administración de Turnos'),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.pink.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Turno',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Tipo de turno',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text('Fecha y hora',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text('Acciones',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('turnos')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.pink));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No hay turnos solicitados',
                            style: TextStyle(
                                color: Colors.pink,
                                fontWeight: FontWeight.bold)));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.pink),
                    itemBuilder: (context, i) {
                      final turno = docs[i];
                      return Container(
                        color: i % 2 == 0 ? Colors.pink.shade50 : Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(turno['numero'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(turno['tipo'] ?? ''),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: Text(
                                    '${turno['fecha'] ?? ''} ${turno['hora'] ?? ''}'),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.campaign,
                                        color: Colors.pink),
                                    tooltip: 'Llamar',
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.hourglass_empty,
                                        color: Colors.orange),
                                    tooltip: 'Pendiente',
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    tooltip: 'Finalizar',
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
