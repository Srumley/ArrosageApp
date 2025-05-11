import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrosage App',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [
    const MapPage(),
    const StatsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistiques',
          ),
        ],
      ),
    );
  }
}



class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}
class _MapPageState extends State<MapPage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref();
  GoogleMapController? _mapController;
  DateTime selectedDate = DateTime.now();
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  Map<PolygonId, Map<String, String>> _polygonClientInfo = {};
  final Map<String, LatLng> cemeteries = {
    "Châtelaine": LatLng(46.20757633211387, 6.1173431525350574),
    "Vernier": LatLng(46.21526981973005, 6.087483791077042),
  };
  bool _showRectangles = true; // État pour basculer entre rectangles et marqueurs

  @override
  void initState() {
    super.initState();
    _loadMarkersFromFirebase(selectedDate);
  }

  void _loadMarkersFromFirebase(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        setState(() {
          _polygons = {};
          _markers = {};
        });
        return;
      }

      final rawData = data as Map<dynamic, dynamic>;
      Set<Polygon> polygons = {};
      Set<Marker> markers = {};
      Map<PolygonId, Map<String, String>> polygonClientInfo = {};

      rawData.forEach((cemeteryName, cemeteryData) {
        final tombes = cemeteryData['tombes'] as Map<dynamic, dynamic>?;
        if (tombes == null) return;

        tombes.forEach((key, entry) {
          final position = entry['position'];
          final client = entry['client'];
          final arrosages = entry['arrosages'] as Map<dynamic, dynamic>?;
          final bool arrose = arrosages?[dateKey]?['arrosé'] == 1;
          final dimensions = entry['dimensions'];
          final double longueur = dimensions['longueur']?.toDouble() ?? 5.0;
          final double largeur = dimensions['largeur']?.toDouble() ?? 2.0;
          final double rotation = dimensions['rotation']?.toDouble() ?? 0.0;

          final LatLng center = LatLng(position['x'], position['y']);

          if (_showRectangles) {
            // Ajouter un rectangle (polygon)
            final PolygonId polygonId = PolygonId("$cemeteryName-$key");
            final List<LatLng> rectPoints = _getRectanglePoints(center, longueur, largeur, rotation);

            final Polygon polygon = Polygon(
              polygonId: polygonId,
              points: rectPoints,
              strokeColor: arrose ? Colors.green : Colors.red,
              strokeWidth: 3,
              fillColor: (arrose ? Colors.green : Colors.red).withOpacity(0.3),
              consumeTapEvents: true,
              onTap: () => _toggleArrosage(cemeteryName, key, dateKey, arrose),
            );

            polygons.add(polygon);
            polygonClientInfo[polygonId] = {'name': client};
          } else {
            // Ajouter un marqueur (marker)
            final MarkerId markerId = MarkerId("$cemeteryName-$key");
            final Marker marker = Marker(
              markerId: markerId,
              position: center,
              infoWindow: InfoWindow(title: client),
              icon: arrose
                  ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                  : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              onTap: () => _toggleArrosage(cemeteryName, key, dateKey, arrose),
            );

            markers.add(marker);
          }
        });
      });

      setState(() {
        _polygons = polygons;
        _markers = markers;
        _polygonClientInfo = polygonClientInfo;
      });
    });
  }

  List<LatLng> _getRectanglePoints(LatLng center, double longueur, double largeur, double rotation) {
    final double halfLongueur = longueur / 2;
    final double halfLargeur = largeur / 2;

    // Convert rotation from degrees to radians
    final double radians = rotation * pi / 180;

    // Define the unrotated rectangle points relative to the center
    final List<LatLng> unrotatedPoints = [
      LatLng(-halfLargeur, -halfLongueur),
      LatLng(-halfLargeur, halfLongueur),
      LatLng(halfLargeur, halfLongueur),
      LatLng(halfLargeur, -halfLongueur),
    ];

    // Rotate each point around the center
    final List<LatLng> rotatedPoints = unrotatedPoints.map((point) {
      final double x = point.longitude * cos(radians) - point.latitude * sin(radians);
      final double y = point.longitude * sin(radians) + point.latitude * cos(radians);
      return LatLng(
        center.latitude + _metersToLatitude(y),
        center.longitude + _metersToLongitude(x, center.latitude),
      );
    }).toList();

    return rotatedPoints;
  }

  double _metersToLatitude(double meters) => meters / 111320.0;
  double _metersToLongitude(double meters, double latitude) => meters / (111320.0 * cos(latitude * pi / 180));

  void _toggleArrosage(String cemeteryName, String tombeKey, String dateKey, bool currentlyArrose) async {
    final tombeRef = ref.child('$cemeteryName/tombes').child(tombeKey).child('arrosages');
    await tombeRef.child(dateKey).set({"arrosé": currentlyArrose ? 0 : 1});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _loadMarkersFromFirebase(selectedDate);
      });
    }
  }

  void _chooseCemetery() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choisir un cimetière"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: cemeteries.keys.map((cemetery) {
            return ListTile(
              title: Text(cemetery),
              onTap: () {
                final LatLng position = cemeteries[cemetery]!;
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: position, zoom: 17),
                  ),
                );
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _toggleView() {
    setState(() {
      _showRectangles = !_showRectangles;
      _loadMarkersFromFirebase(selectedDate); // Recharger les données pour le mode actuel
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Carte des tombes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _chooseCemetery,
          ),
          IconButton(
            icon: Icon(_showRectangles ? Icons.location_on : Icons.pin_drop),
            onPressed: _toggleView,
          ),
        ],
      ),
      body: GoogleMap(
        mapType: MapType.satellite,
        initialCameraPosition: const CameraPosition(
          target: LatLng(46.20757633211387, 6.1173431525350574),
          zoom: 17,
        ),
        polygons: _showRectangles ? _polygons : {},
        markers: _showRectangles ? {} : _markers,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref();
  DateTime selectedDate = DateTime.now();
  Map<String, String> stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats(selectedDate);
  }

  Future<void> _loadStats(DateTime date) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    final Map<String, String> cemeteryStats = {};
    for (final cemetery in ['Châtelaine', 'Vernier']) {
      final snapshot = await ref.child('$cemetery/tombes').get();
      if (!snapshot.exists) {
        cemeteryStats[cemetery] = "0/0";
        continue;
      }

      final tombes = snapshot.value as Map<dynamic, dynamic>;
      int total = tombes.length;
      int arrosees = tombes.values.where((tombe) {
        final arrosages = tombe['arrosages'] as Map<dynamic, dynamic>?;
        return arrosages?[dateKey]?['arrosé'] == 1;
      }).length;

      cemeteryStats[cemetery] = "$arrosees/$total";
    }

    setState(() {
      stats = cemeteryStats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistiques"),
      ),
      body: Column(
        children: [
          // Calendrier toujours visible
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime.now(),
            focusedDay: selectedDate,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            calendarFormat: CalendarFormat.month,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay;
              });
              _loadStats(selectedDay);
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Color.fromARGB(153, 255, 165, 0), //orange transparent
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.grey, // Garder la surbrillance grise par défaut
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          // Liste des statistiques pour chaque cimetière
          Expanded(
            child: ListView(
              children: stats.entries
                  .map((entry) => ListTile(
                title: Text(entry.key),
                subtitle: Text(entry.value),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
