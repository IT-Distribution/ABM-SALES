import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../main.dart'; // Pour backendUrl

class BestRouteScreen extends StatefulWidget {
  final String userEmail;

  const BestRouteScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  _BestRouteScreenState createState() => _BestRouteScreenState();
}

class _BestRouteScreenState extends State<BestRouteScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _clientsCoordinates = [];
  List<LatLng> _optimizedRoutePoints = [];
  MapController mapController = MapController();
  String _totalDistance = '';
  String _totalDuration = '';
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateRoute();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMessage = 'Les services de localisation sont désactivés. Veuillez les activer.';
        _isLoading = false;
      });
      return Future.error('Les services de localisation sont désactivés.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'La permission de localisation a été refusée. Veuillez l\'accorder dans les paramètres de l\'application.';
          _isLoading = false;
        });
        return Future.error('La permission de localisation a été refusée.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'La permission de localisation a été refusée de façon permanente. Veuillez l\'activer manuellement dans les paramètres de l\'application.';
        _isLoading = false;
      });
      return Future.error('La permission de localisation a été refusée de façon permanente.');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      await _checkLocationPermission();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_clientsCoordinates.isEmpty || mapController.center == _calculateMapCenter()) {
          mapController.move(_currentLocation!, _calculateZoomLevel());
        }
      });

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      });

    } catch (e) {
      print('Erreur lors de la récupération de la localisation: $e');
    }
  }

  Future<void> _fetchAndCalculateRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        setState(() {
          _errorMessage = 'Non authentifié. Veuillez vous connecter.';
          _isLoading = false;
        });
        return;
      }

      // Assurez-vous que la localisation actuelle est disponible
      await _getCurrentLocation();
      if (_currentLocation == null) {
        setState(() {
          _errorMessage = 'Impossible de récupérer la localisation actuelle pour calculer le trajet.';
          _isLoading = false;
        });
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final clientsResponse = await http.get(
        Uri.parse('$backendUrl/zones/user/${widget.userEmail}'),
        headers: headers,
      );

      if (clientsResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(clientsResponse.body);
        if (data.isEmpty) {
          setState(() {
            _errorMessage = 'Aucun client assigné trouvé pour votre compte.';
            _isLoading = false;
          });
          return;
        }

        _clientsCoordinates = data.map((zone) => {
          "id": zone['id'],
          "nom": "Client de Zone ${zone['name'].split(' ').last}",
          "latitude": zone['latitude'],
          "longitude": zone['longitude'],
        }).toList();

        // Envoyer uniquement les coordonnées des clients à l'API TomTom pour optimisation
        final routeRequestPoints = _clientsCoordinates.map((client) => {
          'latitude': client['latitude'] as double,
          'longitude': client['longitude'] as double,
        }).toList();

        final routeResponse = await http.post(
          Uri.parse('$backendUrl/calculate-best-route/'),
          headers: headers,
          body: jsonEncode(routeRequestPoints),
        );

        print('Statut de la réponse de route: ${routeResponse.statusCode}');
        print('Corps de la réponse de route: ${routeResponse.body}');

        if (routeResponse.statusCode == 200) {
          final routeData = jsonDecode(routeResponse.body);
          print('Données de route analysées: $routeData');
          _optimizedRoutePoints = (routeData['route_points'] as List)
              .map((p) => LatLng(p['latitude'], p['longitude']))
              .toList();
          
          // Insérer la position actuelle de l'utilisateur au début du trajet
          if (_currentLocation != null) {
            print('Insertion de la position actuelle: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
            _optimizedRoutePoints.insert(0, _currentLocation!);
          } else {
            print('Erreur: _currentLocation est null, impossible d\'insérer la position de départ.');
          }
          
          _totalDistance = routeData['distance_km'].toString();
          _totalDuration = routeData['duration_str'];

        } else {
          _errorMessage = 'Erreur lors du calcul de la route: ${routeResponse.statusCode} - ${routeResponse.body}';
        }
      } else {
        _errorMessage = 'Erreur lors de la récupération des clients: ${clientsResponse.statusCode} - ${clientsResponse.body}';
      }

    } catch (e) {
      _errorMessage = 'Erreur de connexion: $e';
    }

    setState(() {
      _isLoading = false;
    });
  }

  LatLng _calculateMapCenter() {
    if (_clientsCoordinates.isEmpty) {
      return LatLng(31.7917, -7.0926); // Default to Morocco
    }
    double sumLat = 0, sumLng = 0;
    for (var client in _clientsCoordinates) {
      sumLat += client['latitude'];
      sumLng += client['longitude'];
    }
    return LatLng(sumLat / _clientsCoordinates.length, sumLng / _clientsCoordinates.length);
  }

  double _calculateZoomLevel() {
    if (_clientsCoordinates.length <= 1) return 13.0;

    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;

    for (var client in _clientsCoordinates) {
      final lat = client['latitude'];
      final lng = client['longitude'];
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;

    if (latDiff > 2.0 || lngDiff > 2.0) return 6.0;
    if (latDiff > 1.0 || lngDiff > 1.0) return 7.0;
    if (latDiff > 0.5 || lngDiff > 0.5) return 8.0;
    if (latDiff > 0.2 || lngDiff > 0.2) return 9.0;
    if (latDiff > 0.1 || lngDiff > 0.1) return 10.0;
    if (latDiff > 0.05 || lngDiff > 0.05) return 11.0;
    if (latDiff > 0.02 || lngDiff > 0.02) return 12.0;

    return 13.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Color(0xFF7AB828)),
          ),
        ),
      );
    }

    if (_clientsCoordinates.isEmpty) {
      return const Center(
        child: Text('Aucun client trouvé pour afficher le trajet.'),
      );
    }

    final center = _currentLocation ?? _calculateMapCenter();
    final zoom = _calculateZoomLevel();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Meilleur Trajet'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: center,
              zoom: zoom,
              maxZoom: 18.0,
              minZoom: 3.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.abm_sales',
                tileProvider: NetworkTileProvider(),
                tileBuilder: (context, tileWidget, tile) {
                  return tileWidget;
                },
              ),
              if (_optimizedRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _optimizedRoutePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      width: 50.0,
                      height: 50.0,
                      point: _currentLocation!,
                      child: const Icon(
                        Icons.my_location,
                        color: const Color(0xFF7AB828),
                        size: 50.0,
                      ),
                    ),
                  if (_optimizedRoutePoints.isNotEmpty)
                    Marker(
                      width: 50.0,
                      height: 50.0,
                      point: _optimizedRoutePoints.first,
                      child: const Icon(
                        Icons.flag,
                        color: const Color(0xFF7AB828),
                        size: 50.0,
                      ),
                    ),
                  ..._clientsCoordinates.map((client) {
                    return Marker(
                      width: 40.0,
                      height: 40.0,
                      point: LatLng(client['latitude'], client['longitude']),
                      child: const Icon(
                        Icons.location_on,
                        color: const Color(0xFF7AB828),
                        size: 40.0,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          if (_totalDistance.isNotEmpty && _totalDuration.isNotEmpty)
            Positioned(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              child: Card(
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.route, color: const Color(0xFF7AB828)),
                          const SizedBox(height: 4),
                          Text('Distance', style: const TextStyle(fontSize: 12, color: Color(0xFF7AB828))),
                          Text('$_totalDistance km', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7AB828))),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.timer, color: const Color(0xFF7AB828)),
                          const SizedBox(height: 4),
                          Text('Durée estimée', style: const TextStyle(fontSize: 12, color: Color(0xFF7AB828))),
                          Text(_totalDuration, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7AB828))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 