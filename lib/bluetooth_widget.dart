// Este archivo contendrá la lógica de Bluetooth para Flutter multiplataforma.
// Usaremos flutter_blue_plus, que es compatible con Android, iOS y parcialmente con Windows.
// Para web, se puede mostrar un mensaje de no soportado.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;

class BluetoothWidget extends StatefulWidget {
  const BluetoothWidget({Key? key}) : super(key: key);

  @override
  State<BluetoothWidget> createState() => _BluetoothWidgetState();
}

class _BluetoothWidgetState extends State<BluetoothWidget> {
  List<fb.BluetoothDevice> devices = [];
  bool scanning = false;
  String? error;
  bt.BlueThermalPrinter printer = bt.BlueThermalPrinter.instance;
  List<bt.BluetoothDevice> pairedPrinters = [];
  bt.BluetoothDevice? selectedPrinter;
  bool printing = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _startScan();
      _getBondedDevices();
    }
  }

  void _getBondedDevices() async {
    try {
      List<bt.BluetoothDevice> bonded = await printer.getBondedDevices();
      setState(() {
        pairedPrinters = bonded;
      });
    } catch (e) {
      setState(() {
        error = 'Error obteniendo impresoras: $e';
      });
    }
  }

  void _printTest() async {
    if (selectedPrinter == null) return;
    setState(() {
      printing = true;
      error = null;
    });
    try {
      await printer.connect(selectedPrinter!);
      await printer.printNewLine();
      await printer.printCustom('Impresión de prueba', 2, 1);
      await printer.printNewLine();
      await printer.printCustom('Turnos 78', 1, 1);
      await printer.printNewLine();
      await printer.printNewLine();
      await printer.disconnect();
    } catch (e) {
      setState(() {
        error = 'Error al imprimir: $e';
      });
    }
    setState(() {
      printing = false;
    });
  }

  void _startScan() async {
    setState(() {
      scanning = true;
      devices.clear();
      error = null;
    });
    try {
      fb.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      fb.FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          devices = results.map((r) => r.device).toList();
        });
      });
      await Future.delayed(const Duration(seconds: 4));
      setState(() {
        scanning = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Text('Bluetooth no soportado en Web',
          style: TextStyle(color: Colors.pink));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: scanning ? null : _startScan,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              child: Text(scanning ? 'Buscando...' : 'Buscar dispositivos'),
            ),
            if (scanning) ...[
              const SizedBox(width: 16),
              const CircularProgressIndicator(color: Colors.pink),
            ]
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        const Text('Dispositivos encontrados:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...devices.map((d) => ListTile(
              title: Text(d.name.isNotEmpty ? d.name : d.id.toString()),
              subtitle: Text(d.id.toString()),
            )),
        if (!scanning && devices.isEmpty)
          const Text('No se encontraron dispositivos',
              style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        const Text('Impresoras Bluetooth:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<bt.BluetoothDevice>(
          value: selectedPrinter,
          hint: const Text('Selecciona una impresora'),
          items: pairedPrinters
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text((d.name ?? '').isNotEmpty
                        ? d.name!
                        : (d.address ?? '')), // Manejo seguro de nulos
                  ))
              .toList(),
          onChanged: (d) => setState(() => selectedPrinter = d),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (selectedPrinter != null && !printing) ? _printTest : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: printing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Imprimir prueba'),
          ),
        ),
      ],
    );
  }
}
