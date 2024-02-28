import 'package:flutter/material.dart';
import 'package:location/location.dart' as location;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';


import 'package:vibration/vibration.dart'; // Import du package Vibration
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final end = TextEditingController();
  bool isVisible = false;
  List<LatLng> routpoints = [LatLng(52.05884, -1.345583)];
  late GoogleMapController _controller;
  location.Location _locationController = location.Location();

  LatLng? destination;
  LatLng? _currentP;
  AudioPlayer audioPlayer = AudioPlayer();
  //late AudioPlayer _audioPlayer; // Utilisation de AudioPlayer au lieu de AudioCache

  @override
  void initState() {
    super.initState();
    //AudioPlayer audioPlayer = AudioPlayer();
    getLocationUpdates();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Google Map',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey[300],
      ),
      backgroundColor: Colors.grey[300],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                SizedBox(height: 10),
                Container(
                  width: 400,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextField(
                            controller: end,
                            onChanged: (value) {
                              _calculateDistance();
                            },
                            decoration: InputDecoration(
                              hintText: 'Destination',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          List<geocoding.Location> end_l =
                              await geocoding.locationFromAddress(end.text);

                          var v3 = end_l[0].latitude;
                          var v4 = end_l[0].longitude;

                          var url = Uri.parse(
                              'http://router.project-osrm.org/route/v1/driving/${_currentP!.longitude},${_currentP!.latitude};$v4,$v3?steps=true&annotations=true&geometries=geojson&overview=full');
                          var response = await http.get(url);
                          print(response.body);
                          setState(() {
                            routpoints = [];
                            var ruter = jsonDecode(response.body)['routes'][0]
                                ['geometry']['coordinates'];
                            for (int i = 0; i < ruter.length; i++) {
                              var reep = ruter[i].toString();
                              reep = reep.replaceAll("[", "");
                              reep = reep.replaceAll("]", "");
                              var lat1 = reep.split(',');
                              var long1 = reep.split(",");
                              routpoints.add(LatLng(double.parse(lat1[1]),
                                  double.parse(long1[0])));
                            }
                            destination = LatLng(v3, v4);
                            isVisible = !isVisible;
                            print(routpoints);
                            _calculateDistance();
                          });
                        },
                        icon: Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Visibility(
                visible: isVisible,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentP ?? LatLng(0, 0),
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                  },
                  markers: {
                    if (_currentP != null)
                      Marker(
                        markerId: MarkerId('currentLocation'),
                        position: _currentP!,
                        icon: BitmapDescriptor.defaultMarker,
                      ),
                    if (destination != null)
                      Marker(
                        markerId: MarkerId('destination'),
                        position: destination!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                      ),
                  },
                  polylines: Set<Polyline>.from([
                    Polyline(
                      polylineId: PolylineId("route"),
                      points: routpoints,
                      color: Colors.blue,
                      width: 9,
                    ),
                  ]),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          if (_currentP != null && destination != null)
            Text(
              'Kilométrage restant : ${_calculateDistance().toStringAsFixed(2)} km',
              style: TextStyle(fontSize: 20),
            ),
        ],
      ),
    );
  }

  Future<void> _cameraToPosition(LatLng pos) async {
    final GoogleMapController controller = await _controller;
    CameraPosition _newCameraPosition = CameraPosition(
      target: pos,
      zoom: 15,
    );
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_newCameraPosition),
    );
  }

  Future<void> getLocationUpdates() async {
    bool _serviceEnabled;
    location.PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationController.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
    }
    if (!_serviceEnabled) {
      throw Exception('Location service not enabled');
    }

    _permissionGranted = await _locationController.hasPermission();
    if (_permissionGranted == location.PermissionStatus.denied) {
      _permissionGranted = await _locationController.requestPermission();
      if (_permissionGranted != location.PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    }

    _locationController.onLocationChanged
        .listen((location.LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentP =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _cameraToPosition(_currentP!);
          if (destination != null) {
            double distance = _calculateDistance();
            if (distance < 0.1) {
              _audioPlayer();
               Vibration.vibrate(duration: 1000);
            }
          }
        });
      }
    });
  }

  void _getCurrentLocation() async {
    location.LocationData currentLocation =
        await _locationController.getLocation();

    setState(() {
      isVisible = true;
      _currentP = LatLng(currentLocation.latitude!, currentLocation.longitude!);
    });
  }

  double _calculateDistance() {
    if (_currentP == null || destination == null) return 0.0;
    final double earthRadius = 6371.0;
    double lat1 = _currentP!.latitude;
    double lon1 = _currentP!.longitude;
    double lat2 = destination!.latitude;
    double lon2 = destination!.longitude;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * asin(sqrt(a));
    double distance = earthRadius * c;
    return distance;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

void _audioPlayer() async {
  try {
    // Initialize the audio cache
    AudioCache audioCache = AudioCache();
    
    // Load the audio file into the cache
    audioCache.load('assets/alarme(1).mp3');
    
    // Create an instance of AudioPlayer
    AudioPlayer audioPlayer = AudioPlayer();
    
    // Play the audio file from the cache
    int result = await audioPlayer.play('assets/alarme(1).mp3');
    
    // Check if the audio started playing successfully
    if (result == 1) {
      print('Lecture audio démarrée avec succès');
    } else {
      print('Échec de la lecture audio');
    }
  } catch (e) {
    print("Erreur lors de la lecture du son: $e");
  }
}
}
