import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'firebase_options.dart';
import 'turnos_reset_service.dart';

class TomaTurnosPage extends StatefulWidget {
  const TomaTurnosPage({Key? key}) : super(key: key);

  @override
  State<TomaTurnosPage> createState() => _TomaTurnosPageState();
}

class _TomaTurnosPageState extends State<TomaTurnosPage> {
  String? _ultimoTurno;
  String? _ultimoFecha;
  String? _ultimoHora;
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
    // Ejecutar reset automático de turnos pendientes si corresponde
    resetTurnosPendientes();
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
    final pref = tipo == 'RECOGER' ? 'R' : 'I';
    final next = await getNextTurnoNumber(tipo);
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
        _ultimoTurno = numero;
        _ultimoFecha = fecha;
        _ultimoHora = hora;
      });
      _mostrarDialogo(numero, fecha, hora);
    } catch (e, stack) {
      // Debug: imprimir error y stacktrace en consola
      // ignore: avoid_print
      print('Error al solicitar turno: $e');
      // ignore: avoid_print
      print(stack);
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
        centerTitle: true,
        title: LayoutBuilder(
          builder: (context, constraints) {
            double fontSize = constraints.maxWidth > 600 ? 36 : 24;
            return Text(
              'LIVERPOOL GALERIAS CYC',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            );
          },
        ),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  final TextEditingController _controller =
                      TextEditingController();
                  return AlertDialog(
                    title: const Text('Confirmar cierre de sesión'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Ingresa la contraseña para cerrar sesión:'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          obscureText: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Contraseña',
                          ),
                          autofocus: true,
                          onSubmitted: (_) {
                            Navigator.of(ctx)
                                .pop(_controller.text == 'turno78');
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop(_controller.text == 'turno78');
                        },
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  );
                },
              );
              if (result == true) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
              } else if (result == false) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña incorrecta.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
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
                          color: const Color.fromARGB(255, 239, 81, 134),
                          icon: Icons.info_outline,
                          onTap: _loading
                              ? null
                              : () => _solicitarTurno('INFORMES'),
                          size: 150,
                        ),
                        const SizedBox(width: 40),
                        _BotonTurno(
                          label: 'RECOGER PEDIDO',
                          color: Colors.pink.shade700,
                          icon: Icons.shopping_bag_outlined,
                          onTap: _loading
                              ? null
                              : () => _solicitarTurno('RECOGER'),
                          size: 150,
                          labelColor: Colors.white,
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
                    if (_ultimoTurno != null && !_loading) ...[
                      const SizedBox(height: 32),
                      Divider(color: Colors.pink, thickness: 2),
                      Text(
                        'Último turno solicitado:',
                        style: TextStyle(
                          color: Colors.pink.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Turno: $_ultimoTurno',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Fecha: $_ultimoFecha   Hora: $_ultimoHora',
                        style: const TextStyle(fontSize: 16),
                      ),
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
  final double size;
  final Color? labelColor;
  const _BotonTurno({
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
    this.size = 120,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: size * 0.35, color: Colors.white),
            SizedBox(height: size * 0.10),
            Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.13,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
