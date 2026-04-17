import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'package:permission_handler/permission_handler.dart';
import 'turnos_reset_service.dart';
import 'fullscreen_helper.dart';

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
    _initialized = true;
    // Ejecutar reset automático de turnos pendientes si corresponde
    resetTurnosPendientes();
    // Acceder a Theme.of(context) solo después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final platform = Theme.of(context).platform;
      if (platform == TargetPlatform.android) {
        FullScreenHelper.enableImmersiveMode();
        _initBluetoothAndPrinter();
      }
    });
  }

  Future<void> _initBluetoothAndPrinter() async {
    if (await _solicitarPermisosBluetooth()) {
      await _initPrinter();
    } else {
      setState(() {
        _error = 'Permisos de Bluetooth denegados. No se puede imprimir.';
      });
    }
  }

  Future<bool> _solicitarPermisosBluetooth() async {
    if (!mounted) return false;
    if (Theme.of(context).platform == TargetPlatform.android) {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location
      ].request();
      return statuses.values.every((status) => status.isGranted);
    }
    return true;
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

  Future<String> _getNextTurnoTransaccion(String tipo) async {
    final pref = tipo == 'RECOGER' ? 'R' : 'I';
    final nextNum = await getNextTurnoNumber(tipo);
    return '$pref${nextNum.toString().padLeft(3, '0')}';
  }

  Future<void> _solicitarTurno(String tipo) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final fecha = DateFormat('dd/MM/yyyy').format(now);
      final hora = DateFormat('HH:mm').format(now);

      // Buscar cuántos turnos existen hoy de este tipo para generar el consecutivo
      final query = await FirebaseFirestore.instance
          .collection('turnos')
          .where('tipo', isEqualTo: tipo)
          .where('fecha', isEqualTo: fecha)
          .get();
      final count = query.docs.length;
      final pref = tipo == 'RECOGER' ? 'R' : 'I';
      final numero = '$pref${(count + 1).toString().padLeft(3, '0')}';

      // Mostrar mensaje si es el primer turno del día
      if (numero.endsWith('001')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '¡Nuevo día! El consecutivo de turnos ha sido reiniciado.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await FirebaseFirestore.instance.collection('turnos').add({
        'tipo': tipo,
        'numero': numero,
        'fecha': fecha,
        'hora': hora,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAtLocal': now,
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

  Future<bool> _pedirPassword(BuildContext context) async {
    final TextEditingController _controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar acción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa la contraseña para continuar:'),
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
                Navigator.of(ctx).pop(_controller.text == 'turno78');
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
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (result != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña incorrecta.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _pedirPassword(context);
          },
        ),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final double padding = isTablet ? 64 : 24;
          final double buttonSize = isTablet ? 220 : 130;
          final double buttonSpacing = isTablet ? 60 : 24;
          final double fontSize = isTablet ? 22 : 16;
          final double lastTurnFontSize = isTablet ? 36 : 28;
          return Center(
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxWidth: isTablet ? 700 : double.infinity,
              ),
              child: _initialized
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¡Gracias por tu preferencia, toma un turno y en breve te atenderemos!',
                          style: TextStyle(
                              fontSize: fontSize,
                              color: Colors.pink,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isTablet ? 48 : 28),
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
                              size: buttonSize,
                            ),
                            SizedBox(width: buttonSpacing),
                            _BotonTurno(
                              label: 'RECOGER PEDIDO',
                              color: Colors.pink.shade700,
                              icon: Icons.shopping_bag_outlined,
                              onTap: _loading
                                  ? null
                                  : () => _solicitarTurno('RECOGER'),
                              size: buttonSize,
                              labelColor: Colors.white,
                            ),
                          ],
                        ),
                        if (_loading) ...[
                          SizedBox(height: isTablet ? 32 : 20),
                          const CircularProgressIndicator(color: Colors.pink),
                        ],
                        if (_error != null) ...[
                          SizedBox(height: isTablet ? 24 : 12),
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                        if (_ultimoTurno != null && !_loading) ...[
                          SizedBox(height: isTablet ? 48 : 24),
                          Divider(color: Colors.pink, thickness: 2),
                          Text(
                            'Último turno solicitado:',
                            style: TextStyle(
                              color: Colors.pink.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 24 : 18,
                            ),
                          ),
                          SizedBox(height: isTablet ? 16 : 8),
                          Text(
                            'Turno: $_ultimoTurno',
                            style: TextStyle(
                              fontSize: lastTurnFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Fecha: $_ultimoFecha   Hora: $_ultimoHora',
                            style: TextStyle(fontSize: fontSize),
                          ),
                        ],
                      ],
                    )
                  : const CircularProgressIndicator(color: Colors.pink),
            ),
          );
        },
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
