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
      // " https://routes.alesaservices.com/route"
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
          final maneuver = step['maneuver'];
          final distance = (step['distance'] ?? 0).round();

          // Extract maneuver type and modifier
          final type = maneuver['type']?.toString() ?? '';
          final modifier = maneuver['modifier']?.toString() ?? '';

          String instruction = _getManeuverInstruction(type, modifier);

          directions.add({
            'instruction': instruction,
            'distance': distance,
            'type': type,
            'modifier': modifier,
          });
        }
      }

      return {'routeCoordinates': routeCoords, 'directions': directions};
    } else {
      throw Exception('Failed to load directions: ${response.statusCode}');
    }
  }

  static String _getManeuverInstruction(String type, String modifier) {
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left':
            return 'Turn left';
          case 'right':
            return 'Turn right';
          case 'sharp left':
            return 'Sharp left turn';
          case 'sharp right':
            return 'Sharp right turn';
          case 'slight left':
            return 'Slight left turn';
          case 'slight right':
            return 'Slight right turn';
          default:
            return 'Turn';
        }
      case 'new name':
        return 'Continue straight';
      case 'depart':
        return 'Start going';
      case 'arrive':
        return 'Arrive at destination';
      case 'merge':
        return 'Merge onto road';
      case 'ramp':
        return 'Take the ramp';
      case 'on ramp':
        return 'Take the on ramp';
      case 'off ramp':
        return 'Take the exit ramp';
      case 'fork':
        return 'At fork';
      case 'end of road':
        return 'Road ends';
      case 'roundabout':
        return 'Take the roundabout';
      default:
        return 'Continue';
    }
  }

  static String _cleanInstruction(String instruction) {
    // Remove HTML tags if any
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), '');
    // Capitalize first letter
    if (instruction.isNotEmpty) {
      instruction = instruction[0].toUpperCase() + instruction.substring(1);
    }
    return instruction;
  }
}
