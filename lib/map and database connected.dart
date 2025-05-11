import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excelPackage;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:location/location.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;

  final Location _locationService = Location();
  Set<Polygon> _polygons = {}; // Variable d'état pour stocker les polygones
  Map<PolygonId, Map<String, String>> _polygonClientInfo = {}; // Variable pour stocker les informations des clients

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadData();
  }

  Future<void> _getCurrentLocation() async {
    final permissionGranted = await _locationService.requestPermission();
    if (permissionGranted == PermissionStatus.granted) {
      final location = await _locationService.getLocation();
      setState(() {
        _currentLocation = location;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final ByteData data = await rootBundle.load('data/DataTombesTest.xlsx');
      final List<int> bytes = data.buffer.asUint8List();
      final excel = excelPackage.Excel.decodeBytes(bytes);

      Set<Polygon> polygons = {};
      Map<PolygonId, Map<String, String>> polygonClientInfo = {};

      for (var sheet in excel.tables.keys) {
        final sheetData = excel.tables[sheet];
        for (var row in sheetData!.rows) {
          // Utiliser l'opérateur ? pour éviter les erreurs de nullité
          final positionX = row.length > 7 ? double.tryParse(row[7]?.value.toString() ?? '') : null;
          final positionY = row.length > 8 ? double.tryParse(row[8]?.value.toString() ?? '') : null;
          final longueur = row.length > 9 ? double.tryParse(row[9]?.value.toString() ?? '') : null;
          final largeur = row.length > 10 ? double.tryParse(row[10]?.value.toString() ?? '') : null;
          final rotation = row.length > 11 ? double.tryParse(row[11]?.value.toString() ?? '') : null;
          final nomDefunt = row.length > 4 ? row[4]?.value.toString() ?? 'Unknown' : 'Unknown';

          // Imprimer les valeurs extraites
          print('positionX: $positionX');
          print('positionY: $positionY');
          print('longueur: $longueur');
          print('largeur: $largeur');
          print('rotation: $rotation');
          print('nomDefunt: $nomDefunt');

          if (positionX != null && positionY != null) {
            final LatLng center = LatLng(positionX, positionY);
            final double rotationRadians = (rotation ?? 0) * pi / 180;
            final LatLng southwest = _getSouthWest(center, largeur ?? 1, longueur ?? 1);
            final LatLng northeast = _getNorthEast(center, largeur ?? 1, longueur ?? 1);

            final List<LatLng> originalPoints = [
              southwest,
              LatLng(southwest.latitude, northeast.longitude),
              northeast,
              LatLng(northeast.latitude, southwest.longitude),
            ];

            final List<LatLng> rotatedPoints = originalPoints.map((point) {
              return _rotatePoint(center, point, rotationRadians);
            }).toList();

            final PolygonId polygonId = PolygonId('polygon_${polygons.length}');

            final Polygon polygon = Polygon(
              polygonId: polygonId,
              points: rotatedPoints,
              strokeColor: Colors.red,
              strokeWidth: 3,
              fillColor: Colors.red.withOpacity(0.3),
              consumeTapEvents: true,
              onTap: () => _onPolygonTapped(polygonId),
            );

            polygons.add(polygon);
            polygonClientInfo[polygonId] = {'name': nomDefunt};
          }
        }
      }

      setState(() {
        _polygons = polygons;
        _polygonClientInfo = polygonClientInfo;
      });
    } catch (e) {
      print('Erreur lors de la lecture des données: $e');
    }
  }


  LatLng _getSouthWest(LatLng center, double widthMeters, double heightMeters) {
    return LatLng(
      center.latitude - _metersToLatitudeDegrees(heightMeters / 2),
      center.longitude - _metersToLongitudeDegrees(widthMeters / 2, center.latitude),
    );
  }

  LatLng _getNorthEast(LatLng center, double widthMeters, double heightMeters) {
    return LatLng(
      center.latitude + _metersToLatitudeDegrees(heightMeters / 2),
      center.longitude + _metersToLongitudeDegrees(widthMeters / 2, center.latitude),
    );
  }

  double _metersToLatitudeDegrees(double meters) {
    return meters / 111320.0;
  }

  double _metersToLongitudeDegrees(double meters, double latitude) {
    return meters / (111320.0 * cos(latitude * pi / 180));
  }

  LatLng _rotatePoint(LatLng center, LatLng point, double radians) {
    double lat = point.latitude;
    double lng = point.longitude;

    double lat0 = center.latitude;
    double lng0 = center.longitude;

    double latDiff = lat - lat0;
    double lngDiff = lng - lng0;

    double rotatedLat = lat0 + (latDiff * cos(radians) - lngDiff * sin(radians));
    double rotatedLng = lng0 + (latDiff * sin(radians) + lngDiff * cos(radians));

    return LatLng(rotatedLat, rotatedLng);
  }

  void _onPolygonTapped(PolygonId polygonId) {
    final clientInfo = _polygonClientInfo[polygonId];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Information'),
        content: Text('Nom: ${clientInfo?['name']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map with Rotated Polygons'),
      ),
      body: _currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          ),
          zoom: 18.0,
        ),
        mapType: MapType.satellite,
        polygons: _polygons, // Utilise la variable d'état
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: MapPage(),
  ));
}
