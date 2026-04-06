import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'firebase_options.dart';

class TomaTurnosPage extends StatefulWidget {
  const TomaTurnosPage({Key? key}) : super(key: key);

  @override
  State<TomaTurnosPage> createState() => _TomaTurnosPageState();
}

class _TomaTurnosPageState extends State<TomaTurnosPage> {
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  bt.BlueThermalPrinter printer = bt.BlueThermalPrinter.instance;
  bt.BluetoothDevice? selectedPrinter;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _initPrinter();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Error inicializando Firebase: $e';
      });
    }
  }

  Future<void> _initPrinter() async {
    try {
      List<bt.BluetoothDevice> bonded = await printer.getBondedDevices();
      if (bonded.isNotEmpty) {
        setState(() {
          selectedPrinter = bonded.first;
        });
      }
    } catch (_) {}
  }

  Future<String> _getNextTurno(String tipo) async {
    final col = FirebaseFirestore.instance.collection('turnos');
    final pref = tipo == 'RECOGER' ? 'R' : 'I';
    final query = await col
        .where('tipo', isEqualTo: tipo)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    int next = 1;
    if (query.docs.isNotEmpty) {
      final last = query.docs.first['numero'] as String;
      final num = int.tryParse(last.substring(1)) ?? 0;
      next = num + 1;
    }
    return '$pref${next.toString().padLeft(3, '0')}';
  }

  Future<void> _solicitarTurno(String tipo) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final numero = await _getNextTurno(tipo);
      final now = DateTime.now();
      final fecha = DateFormat('dd/MM/yyyy').format(now);
      final hora = DateFormat('HH:mm').format(now);
      await FirebaseFirestore.instance.collection('turnos').add({
        'tipo': tipo,
        'numero': numero,
        'fecha': fecha,
        'hora': hora,
        'timestamp': now,
      });
      await _imprimirTurno(numero, fecha, hora);
      setState(() {
        _loading = false;
      });
      _mostrarDialogo(numero, fecha, hora);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _imprimirTurno(String numero, String fecha, String hora) async {
    if (selectedPrinter == null) return;
    try {
      await printer.connect(selectedPrinter!);
      await printer.printCustom('LIVERPOOL', 2, 1);
      await printer.printNewLine();
      await printer.printCustom(numero, 2, 1);
      await printer.printNewLine();
      await printer.printCustom('$fecha $hora', 1, 1);
      await printer.printNewLine();
      await printer.printCustom('¡Gracias por tu preferencia!', 1, 1);
      await printer.printNewLine();
      await printer.disconnect();
    } catch (_) {}
  }

  void _mostrarDialogo(String numero, String fecha, String hora) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turno generado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Turno: $numero'),
            Text('Fecha: $fecha'),
            Text('Hora: $hora'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('LIVERPOOL GALERIAS CYC'),
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
          child: _initialized
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¡Gracias por tu preferencia, toma un turno y en breve te atenderemos!',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.pink,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BotonTurno(
                          label: 'INFORMES',
                          color: Colors.pink,
                          icon: Icons.info_outline,
                          onTap: _loading
                              ? null
                              : () => _solicitarTurno('INFORMES'),
                        ),
                        const SizedBox(width: 32),
                        _BotonTurno(
                          label: 'RECOGER PEDIDO',
                          color: Colors.pink.shade200,
                          icon: Icons.shopping_bag_outlined,
                          onTap: _loading
                              ? null
                              : () => _solicitarTurno('RECOGER'),
                        ),
                      ],
                    ),
                    if (_loading) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(color: Colors.pink),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                )
              : const CircularProgressIndicator(color: Colors.pink),
        ),
      ),
    );
  }
}

class _BotonTurno extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _BotonTurno(
      {required this.label,
      required this.color,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
