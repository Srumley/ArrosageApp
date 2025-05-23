import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:excel/excel.dart' as excelPackage;
import 'package:xml/xml.dart' as xml;
import 'package:location/location.dart';
import 'dart:math';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cemetery App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static List<Widget> _pages = <Widget>[
    CemeteriesPage(),
    ClientsPage(),
    CalendarPage(),
    MapPage(),  // Nouvelle page "Map"
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cemetery App'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: 'Cemeteries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;

  final Location _locationService = Location();

  final List<Map<String, dynamic>> rectangles = [
    {
      'position': LatLng(46.20696240022942, 6.117351060646785),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Jean Dupont', 'birthdate': '01/01/1950'},
    },
    {
      'position': LatLng(46.206977250126336, 6.117359107273514),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },
    {
      'position': LatLng(46.2069888516055, 6.117424821391803),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },
    {
      'position': LatLng(46.207034793438964, 6.117400681511615),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },
    {
      'position': LatLng(46.207005557731215, 6.117381235497025),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },

    {
      'position': LatLng(46.207020407616454, 6.117444937958625),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },

    {
      'position': LatLng(46.20704732302324, 6.1174684072865855),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },

    {
      'position': LatLng(46.207050107374904, 6.117412751451709),
      'width': 1.0,
      'height': 3.0,
      'rotation': 120.0,
      'color': Colors.red,
      'clientInfo': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    }


  ];

  Set<Polygon> _polygons = {};
  Map<PolygonId, Map<String, String>> _polygonClientInfo = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _createPolygons();
  }

  Future<void> _getCurrentLocation() async {
    // Request location permission and get the current location
    final permissionGranted = await _locationService.requestPermission();
    if (permissionGranted == PermissionStatus.granted) {
      final location = await _locationService.getLocation();
      setState(() {
        _currentLocation = location;
      });
    }
  }

  void _createPolygons() {
    for (int i = 0; i < rectangles.length; i++) {
      final rectangle = rectangles[i];
      final LatLng center = rectangle['position'];
      final double rotationRadians = rectangle['rotation'] * pi / 180;
      final LatLng southwest = _getSouthWest(center, rectangle['width'], rectangle['height']);
      final LatLng northeast = _getNorthEast(center, rectangle['width'], rectangle['height']);

      final List<LatLng> originalPoints = [
        southwest,
        LatLng(southwest.latitude, northeast.longitude),
        northeast,
        LatLng(northeast.latitude, southwest.longitude),
      ];

      final List<LatLng> rotatedPoints = originalPoints.map((point) {
        return _rotatePoint(center, point, rotationRadians);
      }).toList();

      final PolygonId polygonId = PolygonId('rectangle_$i');

      final Polygon polygon = Polygon(
        polygonId: polygonId,
        points: rotatedPoints,
        strokeColor: rectangle['color'],
        strokeWidth: 3,
        fillColor: rectangle['color'].withOpacity(0.3),
        consumeTapEvents: true,
        onTap: () => _onPolygonTapped(polygonId),
      );

      setState(() {
        _polygons.add(polygon);
        _polygonClientInfo[polygonId] = rectangle['clientInfo'];
      });
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

    if (clientInfo != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(clientInfo['name']!),
            content: Text('Birthdate: ${clientInfo['birthdate']}'),
            actions: <Widget>[
              TextButton(
                child: Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    //_locationService.onLocationChanged.listen((LocationData locationData) {
    // Update the map camera position whenever the location changes
    //_mapController?.animateCamera(
    //CameraUpdate.newLatLng(
    //LatLng(locationData.latitude!, locationData.longitude!),
    //),
    //);
    //});
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
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          ),
          zoom: 18.0,
        ),
        mapType: MapType.satellite,
        polygons: _polygons,
        myLocationEnabled: true, // Display user's current location
        myLocationButtonEnabled: true, // Add a button to center the map on user's location
      ),
    );
  }
}




// Les autres classes restent inchangées
class CemeteriesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: Text('Chatelaine'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatelaineCemetery()),
            );
          },
        ),
        ListTile(
          title: Text('Perly'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PerlyCemetery()),
            );
          },
        ),
        ListTile(
          title: Text('Bardonnex'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BardonnexCemetery()),
            );
          },
        ),
        ListTile(
          title: Text('Genthod'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GenthodCemetery()),
            );
          },
        ),
      ],
    );
  }
}

// Les autres pages et composants restent également inchangés
class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, String> _cemeteryMappings = {
    'Chatelaine': 'images/tombe-svg.svg',
    'Perly': 'images/perly.svg',
    'Bardonnex': 'images/bardonnex.svg',
    'Genthod': 'images/genthod.svg',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(1900),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
          },
        ),
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Selected Date: ${_selectedDay!.toLocal()}".split(' ')[0],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: _cemeteryMappings.keys.map((cemetery) {
                String svgPath = _cemeteryMappings[cemetery]!;
                int numberOfMarkers = _getNumberOfMarkers(svgPath);
                return ListTile(
                  title: Text(cemetery),
                  trailing: Text('Markers: $numberOfMarkers'),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  int _getNumberOfMarkers(String svgPath) {
    return 10;
  }
}

// Classe CemeteryPage et ses sous-classes restent inchangées
class CemeteryPage extends StatefulWidget {
  final String title;
  final String svgAssetPath;
  final Map<String, Map<String, String>> tombClientMapping;

  CemeteryPage({
    required this.title,
    required this.svgAssetPath,
    required this.tombClientMapping,
  });

  @override
  _CemeteryPageState createState() => _CemeteryPageState();
}



class _CemeteryPageState extends State<CemeteryPage> {
  String? svgString;
  xml.XmlDocument? svgXml;
  final TransformationController _transformationController = TransformationController();
  bool isPlaying = false;

  // Map to store the state of each marker (true for selected, false for not selected)
  Map<String, bool> _markerStates = {};

  @override
  void initState() {
    super.initState();
    _loadSvg();
    // Initialize all markers to not selected (red)
    widget.tombClientMapping.keys.forEach((id) {
      _markerStates[id] = false;
    });
  }

  Future<void> _loadSvg() async {
    try {
      svgString = await rootBundle.loadString(widget.svgAssetPath);
      svgXml = xml.XmlDocument.parse(svgString!);
      setState(() {});
    } catch (e) {
      print('Error loading SVG: $e');
    }
  }

  void _togglePlayPause() {
    setState(() {
      isPlaying = !isPlaying;
    });

    if (isPlaying) {
      print("Play");
    } else {
      print("Pause");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (svgString == null || svgXml == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: InteractiveViewer(
        panEnabled: true,
        boundaryMargin: EdgeInsets.all(20.0),
        minScale: 0.5,
        maxScale: 4.0,
        transformationController: _transformationController,
        child: Stack(
          children: [
            SvgPicture.string(
              svgString!,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
              width: double.infinity,
              height: double.infinity,
            ),
            ..._buildTombMarkers(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _togglePlayPause,
        child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  List<Widget> _buildTombMarkers() {
    List<Widget> markers = [];

    svgXml!.findAllElements('rect').forEach((rectElement) {
      String? id = rectElement.getAttribute('id');
      if (id != null && widget.tombClientMapping.containsKey(id)) {
        double x = double.parse(rectElement.getAttribute('x')!);
        double y = double.parse(rectElement.getAttribute('y')!);
        double width = double.parse(rectElement.getAttribute('width')!);
        double height = double.parse(rectElement.getAttribute('height')!);

        bool isSelected = _markerStates[id] ?? false;
        Color markerColor = isSelected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3);

        markers.add(Positioned(
          left: x,
          top: y,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: () {
              _toggleMarkerState(id);
            },
            child: Container(
              decoration: BoxDecoration(
                color: markerColor,
                border: Border.all(color: isSelected ? Colors.green : Colors.red, width: 2),
              ),
            ),
          ),
        ));
      }
    });

    return markers;
  }

  void _toggleMarkerState(String id) {
    setState(() {
      _markerStates[id] = !(_markerStates[id] ?? false);
    });
  }

  void _showClientInfo(BuildContext context, Map<String, String>? clientInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(clientInfo!['name']!),
          content: Text('Birthdate: ${clientInfo['birthdate']}'),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}


class ChatelaineCemetery extends CemeteryPage {
  ChatelaineCemetery()
      : super(
    title: 'Chatelaine Cemetery',
    svgAssetPath: 'images/tombe-svg.svg',
    tombClientMapping: {
      'rect1': {'name': 'Jean Dupont', 'birthdate': '01/01/1950'},
      'rect2': {'name': 'Marie Dupont', 'birthdate': '05/05/1955'},
    },
  );
}

class PerlyCemetery extends CemeteryPage {
  PerlyCemetery()
      : super(
    title: 'Perly Cemetery',
    svgAssetPath: 'images/perly.svg',
    tombClientMapping: {
      'rect1': {'name': 'Alice Durand', 'birthdate': '02/02/1940'},
      'rect2': {'name': 'Pierre Durand', 'birthdate': '03/03/1945'},
    },
  );
}

class BardonnexCemetery extends CemeteryPage {
  BardonnexCemetery()
      : super(
    title: 'Bardonnex Cemetery',
    svgAssetPath: 'images/bardonnex.svg',
    tombClientMapping: {
      'rect1': {'name': 'Luc Martin', 'birthdate': '04/04/1930'},
      'rect2': {'name': 'Sophie Martin', 'birthdate': '06/06/1935'},
    },
  );
}

class GenthodCemetery extends CemeteryPage {
  GenthodCemetery()
      : super(
    title: 'Genthod Cemetery',
    svgAssetPath: 'images/genthod.svg',
    tombClientMapping: {
      'rect1': {'name': 'Henri Lefevre', 'birthdate': '07/07/1920'},
      'rect2': {'name': 'Claire Lefevre', 'birthdate': '08/08/1925'},
    },
  );
}

class ClientsPage extends StatefulWidget {
  @override
  _ClientsPageState createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Map<String, String>> _clients = [];
  List<Map<String, String>> _filteredClients = [];
  String _searchQuery = '';
  String _searchCriteria = 'Client'; // Par défaut, on cherche par Client

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    try {
      // Charger le fichier Excel comme un byte array
      ByteData data = await rootBundle.load('data/DataTombes.xlsx');
      var bytes = data.buffer.asUint8List();

      // Décoder le fichier Excel
      var excel = excelPackage.Excel.decodeBytes(bytes);

      // Récupérer la première feuille
      var sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null) {
        print('Aucune feuille trouvée dans le fichier Excel.');
        return;
      }

      // Lire les en-têtes pour déterminer l'index de chaque colonne
      List<String> headers = [];
      if (sheet.rows.isNotEmpty) {
        headers = sheet.rows.first.map((cell) => cell?.value.toString() ?? '').toList();
      } else {
        print('La feuille Excel est vide.');
        return;
      }

      // Définir les noms des colonnes attendues
      Map<String, int> columnIndices = {};
      for (int i = 0; i < headers.length; i++) {
        String header = headers[i].trim().toLowerCase(); // Normaliser les en-têtes
        columnIndices[header] = i;
      }

      // Vérifier que les colonnes nécessaires existent
      List<String> requiredColumns = ['client', 'nom_defunt', 'nr_tombe', 'carre', 'cimetiere', 'desactivee'];
      for (String col in requiredColumns) {
        if (!columnIndices.containsKey(col)) {
          print('La colonne "$col" est manquante dans le fichier Excel.');
          return;
        }
      }

      // Parcourir les lignes de la feuille en commençant par la deuxième ligne (index 1)
      final List<Map<String, String>> loadedClients = [];
      for (int i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        if (row.length < headers.length) {
          // Gérer les lignes incomplètes
          print('Ligne ${i + 1} incomplète, sautée.');
          continue;
        }

        // Vérifier si la colonne "Desactivee" contient '1'
        if (row[columnIndices['desactivee']!]?.value.toString() != '1') {
          continue; // Ignorer les lignes où 'Desactivee' n'est pas '1'
        }

        loadedClients.add({
          'Client': row[columnIndices['client']!]?.value.toString() ?? '',
          'Nom_defunt': row[columnIndices['nom_defunt']!]?.value.toString() ?? '',
          'Nr_tombe': row[columnIndices['nr_tombe']!]?.value.toString() ?? '',
          'Carre': row[columnIndices['carre']!]?.value.toString() ?? '',
          'Cimetiere': row[columnIndices['cimetiere']!]?.value.toString() ?? '',
          // Ajoutez d'autres champs si nécessaire
        });
      }

      // Mettre à jour l'état avec les clients chargés
      setState(() {
        _clients = loadedClients;
        _filteredClients = loadedClients; // Initialement, tous les clients sont affichés
      });
    } catch (e) {
      print('Erreur lors du chargement du fichier Excel: $e');
    }
  }

  void _filterClients() {
    setState(() {
      _filteredClients = _clients.where((client) {
        String valueToCheck = client[_searchCriteria]!.toLowerCase();
        return valueToCheck.contains(_searchQuery.toLowerCase());
      }).toList();

      // Si le critère de recherche est "Cimetiere", trier par ordre alphabétique des clients
      if (_searchCriteria == 'Cimetiere') {
        _filteredClients.sort((a, b) => a['Client']!.compareTo(b['Client']!));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clients'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _filterClients();
                    },
                    decoration: InputDecoration(
                      labelText: 'Rechercher',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: _searchCriteria,
                  onChanged: (String? newValue) {
                    setState(() {
                      _searchCriteria = newValue!;
                    });
                    _filterClients();
                  },
                  items: <String>['Client', 'Nom_defunt', 'Cimetiere']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client['Client']!,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Défunt: ${client['Nom_defunt']}'),
                      Text('Cimetière: ${client['Cimetiere']}'),
                      Text('Carré: ${client['Carre']}'),
                      Text('Numéro tombe: ${client['Nr_tombe']}'),
                      Divider(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
