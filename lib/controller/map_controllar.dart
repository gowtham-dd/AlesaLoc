import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:locationproject/model/map_services.dart';

final mapProvider = StateNotifierProvider<MapControllerNotifier, MapState>(
  (ref) => MapControllerNotifier(),
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

  MapState({
    required this.mapController,
    this.currentLocation,
    this.startLocation,
    this.endLocation,
    this.routeCoordinates = const [],
    this.directions = const [],
    this.isBlinking = false,
    this.isLoading = false,
  });

  MapState copyWith({
    LatLng? currentLocation,
    LatLng? startLocation,
    LatLng? endLocation,
    List<LatLng>? routeCoordinates,
    List<Map<String, dynamic>>? directions,
    bool? isBlinking,
    bool? isLoading,
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
    );
  }
}

class MapControllerNotifier extends StateNotifier<MapState> {
  MapControllerNotifier() : super(MapState(mapController: MapController())) {
    getUserLocation();
    startBlinking();
  }

  Future<void> getUserLocation() async {
    try {
      final response = await http.get(Uri.parse("https://ipinfo.io/json"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latLng = data["loc"].split(",");
        final userLat = double.parse(latLng[0]);
        final userLng = double.parse(latLng[1]);

        state = state.copyWith(currentLocation: LatLng(userLat, userLng));
        state.mapController.move(LatLng(userLat, userLng), 15.0);
      }
    } catch (e) {
      print("Error getting location: $e");
    }
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
    if (state.startLocation == null || state.endLocation == null) return;

    try {
      state = state.copyWith(isLoading: true);

      final result = await MapService.getDirections(
        state.startLocation!,
        state.endLocation!,
      );

      state = state.copyWith(
        routeCoordinates: (result['routeCoordinates'] as List).cast<LatLng>(),
        directions: (result['directions'] as List).cast<Map<String, dynamic>>(),
        isLoading: false,
      );

      if (state.routeCoordinates.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(state.routeCoordinates);
        state.mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(50)),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print("Error getting directions: $e");
      throw Exception("Failed to get directions: $e");
    }
  }

  void startBlinking() {
    Future.delayed(Duration(milliseconds: 500), () {
      state = state.copyWith(isBlinking: !state.isBlinking);
      startBlinking();
    });
  }
}
