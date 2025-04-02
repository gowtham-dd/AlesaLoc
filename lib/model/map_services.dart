import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  static Future<List<String>> getAutocompleteSuggestions(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5",
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List results = json.decode(response.body);
      return results
          .map((result) => result['display_name'].toString())
          .toList();
    } else {
      throw Exception('Failed to load autocomplete suggestions');
    }
  }

  static Future<LatLng?> searchLocation(String query) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=1",
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List results = json.decode(response.body);
      if (results.isNotEmpty) {
        return LatLng(
          double.parse(results[0]['lat']),
          double.parse(results[0]['lon']),
        );
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> getDirections(
    LatLng start,
    LatLng end,
  ) async {
    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/"
      "${start.longitude},${start.latitude};${end.longitude},${end.latitude}"
      "?overview=full&geometries=geojson&steps=true",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'];
      final routeCoords =
          coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();

      final legs = data['routes'][0]['legs'];
      final directions = <Map<String, dynamic>>[];

      for (final leg in legs) {
        for (final step in leg['steps']) {
          directions.add({
            'instruction': step['maneuver']['instruction'],
            'distance': (step['distance']).round(),
          });
        }
      }

      return {'routeCoordinates': routeCoords, 'directions': directions};
    } else {
      throw Exception('Failed to load directions: ${response.statusCode}');
    }
  }
}
