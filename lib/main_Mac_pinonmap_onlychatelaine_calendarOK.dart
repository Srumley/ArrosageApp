import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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
  final DatabaseReference ref = FirebaseDatabase.instance.ref("Châtelaine/tombes");
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  DateTime selectedDate = DateTime.now();

  final Map<String, LatLng> cemeteries = {
    "Châtelaine": LatLng(46.2069624, 6.1173511),
    "Vernier": LatLng(46.21526981973005, 6.087483791077042),
  };

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
          _markers = {};
        });
        return;
      }

      final rawData = data as Map<dynamic, dynamic>;
      final formattedData = rawData.map((key, value) {
        return MapEntry(key.toString(), value as Map<dynamic, dynamic>);
      });

      setState(() {
        _markers = formattedData.entries.map((entry) {
          final position = entry.value['position'];
          final client = entry.value['client'];
          final arrosages = entry.value['arrosages'] as Map<dynamic, dynamic>?;

          final bool arrose = arrosages?[dateKey]?['arrosé'] == 1;

          return Marker(
            markerId: MarkerId(entry.key),
            position: LatLng(position['x'], position['y']),
            infoWindow: InfoWindow(
              title: client,
              snippet: arrose ? "Arrosé : Oui" : "Arrosé : Non",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              arrose ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
            onTap: () => _toggleArrosage(entry.key, dateKey, arrose),
          );
        }).toSet();
      });
    });
  }

  void _toggleArrosage(String tombeKey, String dateKey, bool currentlyArrose) async {
    final tombeRef = ref.child(tombeKey).child('arrosages');
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
                    CameraPosition(target: position, zoom: 15),
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
            icon: const Icon(Icons.location_on),
            onPressed: _chooseCemetery,
          ),
        ],
      ),
      body: GoogleMap(
        mapType: MapType.satellite,
        initialCameraPosition: const CameraPosition(
          target: LatLng(46.2069624, 6.1173511),
          zoom: 15,
        ),
        markers: _markers,
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
