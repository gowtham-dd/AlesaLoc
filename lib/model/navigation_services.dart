import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

class NavigationService {
  final FlutterTts _tts = FlutterTts();
  Position? _lastPosition;
  int _currentStep = 0;
  List<Map<String, dynamic>> _directions = [];
  bool _isNavigating = false;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
  }

  void startNavigation(List<Map<String, dynamic>> directions) {
    _directions = directions;
    _currentStep = 0;
    _isNavigating = true;
    _speakCurrentInstruction();
  }

  void stopNavigation() {
    _isNavigating = false;
    _tts.stop();
  }

  Future<void> checkMovement(Position currentPosition) async {
    if (!_isNavigating || _directions.isEmpty) return;

    // Check if user has moved significantly (at least 20 meters)
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      if (distance < 20) return; // Not significant movement
    }

    _lastPosition = currentPosition;
    await _speakCurrentInstruction();
  }

  Future<void> _speakCurrentInstruction() async {
    if (_currentStep >= _directions.length) {
      await _tts.speak("You have arrived at your destination");
      _isNavigating = false;
      return;
    }

    final instruction = _directions[_currentStep]['instruction'];
    final distance = _directions[_currentStep]['distance'];
    final distanceText = distance < 1000 ? '$distance meters' : '${(distance/1000).toStringAsFixed(1)} kilometers';

    await _tts.speak('$instruction in $distanceText');
    
    // Move to next step after speaking (or stay if no movement detected)
    _currentStep++;
  }
}