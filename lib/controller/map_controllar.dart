import 'dart:async';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:locationproject/model/map_services.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Create a provider for TTS
final ttsProvider = Provider<FlutterTts>((ref) => FlutterTts());

final mapProvider = StateNotifierProvider<MapControllerNotifier, MapState>(
  (ref) => MapControllerNotifier(ref.read(ttsProvider)),
);

class MapState {
  final MapController mapController;
  final LatLng? currentLocation;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final List<LatLng> routeCoordinates;
  final List<Map<String, dynamic>> directions;
  final bool isBlinking;
  final bool isLoading;
  final bool isSpeaking;
  final int currentStep;

  MapState({
    required this.mapController,
    this.currentLocation,
    this.startLocation,
    this.endLocation,
    this.routeCoordinates = const [],
    this.directions = const [],
    this.isBlinking = false,
    this.isLoading = false,
    this.isSpeaking = false,
    this.currentStep = 0,
  });

  MapState copyWith({
    LatLng? currentLocation,
    LatLng? startLocation,
    LatLng? endLocation,
    List<LatLng>? routeCoordinates,
    List<Map<String, dynamic>>? directions,
    bool? isBlinking,
    bool? isLoading,
    bool? isSpeaking,
    int? currentStep,
  }) {
    return MapState(
      mapController: mapController,
      currentLocation: currentLocation ?? this.currentLocation,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      directions: directions ?? this.directions,
      isBlinking: isBlinking ?? this.isBlinking,
      isLoading: isLoading ?? this.isLoading,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

class MapControllerNotifier extends StateNotifier<MapState> {
  final FlutterTts _tts;
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;
  bool _navigationActive = false;

  MapControllerNotifier(this._tts)
    : super(MapState(mapController: MapController())) {
    _initTTS();
    getUserLocation();
    startBlinking();
  }
  Future<void> _initTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      print("TTS initialized successfully");
    } catch (e) {
      print("Error initializing TTS: $e");
      // You might want to disable TTS functionality if initialization fails
    }
  }

  Future<void> _getLocationFromIP() async {
    try {
      final response = await http.get(Uri.parse("https://ipapi.co/json/"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lat = data['latitude'];
        final lng = data['longitude'];

        if (lat != null && lng != null) {
          _updateLocation(
            Position(
              latitude: lat.toDouble(),
              longitude: lng.toDouble(),
              timestamp: DateTime.now(),
              accuracy: 100,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ),
          );
        }
      }
    } catch (e) {
      print("Error getting IP location: $e");
      // Fallback to default location (Coimbatore)
      _updateLocation(
        Position(
          latitude: 11.0168,
          longitude: 76.9558,
          timestamp: DateTime.now(),
          accuracy: 100,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
      );
    }
  }

  Future<void> getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _getLocationFromIP();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _getLocationFromIP();
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _updateLocation(position);
    } catch (e) {
      print("Error getting GPS location: $e");
      await _getLocationFromIP();
    }
  }

  void _startPositionUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _updateLocation(position);
      if (_navigationActive) {
        _checkMovement(position);
      }
    });
  }

  void _updateLocation(Position position) {
    state = state.copyWith(
      currentLocation: LatLng(position.latitude, position.longitude),
    );
    state.mapController.move(
      LatLng(position.latitude, position.longitude),
      15.0,
    );
  }

  Future<void> _checkMovement(Position currentPosition) async {
    if (state.directions.isEmpty || !_navigationActive) return;

    // Check if user has moved significantly (at least 20 meters)
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      if (distance < 20) {
        // If not moved enough, repeat current instruction after delay
        Future.delayed(Duration(seconds: 30), () {
          if (_navigationActive &&
              state.currentStep < state.directions.length) {
            _speakInstruction(state.directions[state.currentStep]);
          }
        });
        return;
      }
    }

    _lastPosition = currentPosition;
    _progressToNextStep();
  }

  Future<void> _progressToNextStep() async {
    if (state.currentStep >= state.directions.length - 1) {
      await _speakArrival();
      _stopNavigation();
      return;
    }

    state = state.copyWith(currentStep: state.currentStep + 1);
    await _speakInstruction(state.directions[state.currentStep]);
  }

  Future<void> _speakInstruction(Map<String, dynamic> direction) async {
    if (state.isSpeaking) await _tts.stop();

    final instruction = direction['instruction'];
    final distance = direction['distance'];
    final distanceText =
        distance < 1000
            ? '$distance meters'
            : '${(distance / 1000).toStringAsFixed(1)} kilometers';

    state = state.copyWith(isSpeaking: true);
    await _tts.speak('$instruction in $distanceText');
    state = state.copyWith(isSpeaking: false);
  }

  Future<void> _speakArrival() async {
    state = state.copyWith(isSpeaking: true);
    await _tts.speak("You have arrived at your destination");
    state = state.copyWith(isSpeaking: false);
  }

  void _stopNavigation() {
    _navigationActive = false;
    _positionStream?.cancel();
    _lastPosition = null;
    state = state.copyWith(currentStep: 0, isSpeaking: false);
  }

  Future<void> searchAndSetLocation(String query, bool isStart) async {
    if (query.isEmpty) return;

    try {
      final location = await MapService.searchLocation(query);
      if (location != null) {
        state =
            isStart
                ? state.copyWith(startLocation: location)
                : state.copyWith(endLocation: location);

        state.mapController.move(location, 15.0);
      }
    } catch (e) {
      print("Error searching location: $e");
    }
  }

  Future<void> getDirections() async {
    if (state.startLocation == null || state.endLocation == null) {
      throw Exception("Start or end location not set");
    }

    try {
      state = state.copyWith(isLoading: true, directions: []);

      final result = await MapService.getDirections(
        state.startLocation!,
        state.endLocation!,
      );

      if (result['routeCoordinates'].isEmpty || result['directions'].isEmpty) {
        throw Exception("No route found between locations");
      }

      state = state.copyWith(
        routeCoordinates: (result['routeCoordinates'] as List).cast<LatLng>(),
        directions: (result['directions'] as List).cast<Map<String, dynamic>>(),
        isLoading: false,
        currentStep: 0,
      );

      // Start navigation
      _navigationActive = true;
      _startPositionUpdates();
      await _speakInstruction(state.directions[0]);

      if (state.routeCoordinates.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(state.routeCoordinates);
        state.mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(50)),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print("Error getting directions: $e");
      throw Exception("Could not get directions: ${e.toString()}");
    }
  }

  // Add the new public stopNavigation method here
  Future<void> stopNavigation() async {
    try {
      await _tts.stop();
      _navigationActive = false;
      _positionStream?.cancel();
      _lastPosition = null;
      state = state.copyWith(
        directions: [],
        routeCoordinates: [],
        currentStep: 0,
        isSpeaking: false,
      );
    } catch (e) {
      print("Error stopping navigation: $e");
      // Fallback to just clearing the state if TTS fails
      state = state.copyWith(
        directions: [],
        routeCoordinates: [],
        currentStep: 0,
        isSpeaking: false,
      );
    }
  }

  void startBlinking() {
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_navigationActive) return; // Only blink when navigating
      state = state.copyWith(isBlinking: !state.isBlinking);
      startBlinking();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _tts.stop();
    super.dispose();
  }
}
