import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class ZebraPrinterPage extends StatefulWidget {
  @override
  _ZebraPrinterPageState createState() => _ZebraPrinterPageState();
}

class _ZebraPrinterPageState extends State<ZebraPrinterPage> {
  List<ScanResult> devices = [];
  BluetoothDevice? selectedDevice;
  bool scanning = false;

  Future<void> startScan() async {
    // Solicitar permisos solo en Android
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    setState(() {
      scanning = true;
      devices.clear();
    });
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devices = results;
      });
    });
    await Future.delayed(Duration(seconds: 4));
    FlutterBluePlus.stopScan();
    setState(() {
      scanning = false;
    });
  }

  Future<void> connectAndPrint(BluetoothDevice device) async {
    await device.connect();
    List<BluetoothService> services = await device.discoverServices();
    BluetoothCharacteristic? targetCharacteristic;
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic c in service.characteristics) {
        if (c.properties.write) {
          targetCharacteristic = c;
          break;
        }
      }
      if (targetCharacteristic != null) break;
    }
    if (targetCharacteristic != null) {
      String zpl = '^XA^FO50,50^ADN,36,20^FD¡Hola Zebra!^FS^XZ';
      await targetCharacteristic.write(utf8.encode(zpl));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impresión enviada a ${device.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se encontró característica de escritura.')),
      );
    }
    await device.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Selecciona impresora Zebra')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: scanning ? null : startScan,
            child: Text(scanning ? 'Buscando...' : 'Buscar impresoras'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index].device;
                return ListTile(
                  title:
                      Text(device.name.isNotEmpty ? device.name : device.id.id),
                  subtitle: Text(device.id.id),
                  onTap: () async {
                    setState(() {
                      selectedDevice = device;
                    });
                    await connectAndPrint(device);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
