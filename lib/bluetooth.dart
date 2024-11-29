import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:math';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  List<DiscoveredDevice> _devices = [];
  Map<String, List<int>> _deviceRssiHistory = {};
  Timer? _updateTimer;
  bool _isScanning = false;
  final int _historySize = 10; // Nombre de valeurs RSSI à garder pour la moyenne mobile

  @override
  void initState() {
    super.initState();
    checkPermissions();
    checkLocationService();
    startPeriodicScan();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> checkPermissions() async {
    final status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<void> checkLocationService() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
    }
  }

  void startPeriodicScan() {
    _updateTimer = Timer.periodic(Duration(milliseconds: 1000), (Timer timer) {
      if (_isScanning) return;
      _isScanning = true;

      _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen(
            (device) {
          if (device.name.contains('Smart Tag') || device.name.contains('iTAG') || device.name.contains('Smart FInder')) {
            setState(() {
              if (!_devices.any((d) => d.id == device.id)) {
                _devices.add(device);
                _deviceRssiHistory[device.id] = [];
              }

              // Ajouter la nouvelle valeur RSSI à l'historique
              final rssiList = _deviceRssiHistory[device.id]!;
              rssiList.add(device.rssi);
              if (rssiList.length > _historySize) {
                rssiList.removeAt(0);
              }
            });
          }
        },
        onError: (error) {
          print('Scan error: $error');
          Future.delayed(Duration(seconds: 5), () {
            startPeriodicScan(); // Retry scan after error
          });
        },
        onDone: () {
          _isScanning = false;
        },
      );
    });
  }

  double calculateDistance(int rssi) {
    const int txPower = -59; // Valeur typique pour un émetteur BLE
    const double n = 3; // Ajusté pour des environnements typiques

    if (rssi == 0) {
      return 0.0;//-1.0; // Valeur non valide
    }
    final ratio = rssi / txPower;
    if (ratio < 1.0) {
      return pow(ratio, 10.0).toDouble();
    } else {
      final distance = 0.89976 * pow(ratio, 7.7095) + 0.111;
      return distance.toDouble();
    }
  }

  double smoothRssi(String deviceId) {
    final rssiList = _deviceRssiHistory[deviceId] ?? [];
    if (rssiList.isEmpty) return 0.0;
    final averageRssi = rssiList.reduce((a, b) => a + b) / rssiList.length;
    return averageRssi.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Scanner'),
      ),
      body: _devices.isEmpty
          ? Center(child: Text('Scanning for Smart Tag devices...'))
          : ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          final smoothedRssi = smoothRssi(device.id);
          final distance = calculateDistance(smoothedRssi.toInt());
          return ListTile(
            title: Text(device.name.isEmpty ? 'Unnamed device' : device.name),
            subtitle: Text(device.id),
            trailing: Text(distance < 0 ? 'Unknown' : '${distance.toStringAsFixed(2)} m'),
          );
        },
      ),
    );
  }
}
