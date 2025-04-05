import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:locationproject/controller/map_controllar.dart';

class MapPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final TextEditingController _endController = TextEditingController();
  final FocusNode _endFocusNode = FocusNode();
  bool _showRouteDistance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).getUserLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final mapNotifier = ref.read(mapProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text("Map Navigation"),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () {
              mapNotifier.getUserLocation();
            },
          ),
          IconButton(
            icon: Icon(Icons.directions),
            onPressed: () async {
              if (_endController.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Calculating route...")));

                try {
                  await mapNotifier.searchAndSetLocation(
                    _endController.text,
                    false,
                  );
                  await mapNotifier.getDirections();
                  setState(() {
                    _showRouteDistance = true;
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Please enter destination")),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (mapState.directions.isNotEmpty)
            FloatingActionButton(
              heroTag: 'stop_navigation',
              onPressed: () => mapNotifier.stopNavigation(),
              child: Icon(Icons.volume_off),
            ),
          SizedBox(height: 10),
          FloatingActionButton(
            mini: true,
            heroTag: 'zoomIn',
            onPressed: () {
              final currentZoom = mapState.mapController.camera.zoom;
              mapState.mapController.move(
                mapState.mapController.camera.center,
                currentZoom + 1,
              );
            },
            child: Icon(Icons.add),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            mini: true,
            heroTag: 'zoomOut',
            onPressed: () {
              final currentZoom = mapState.mapController.camera.zoom;
              mapState.mapController.move(
                mapState.mapController.camera.center,
                currentZoom - 1,
              );
            },
            child: Icon(Icons.remove),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapState.mapController,
            options: MapOptions(
              initialCenter:
                  mapState.currentLocation ?? LatLng(11.0168, 76.9558),
              initialZoom: 13.0,
              onTap: (_, __) {
                _endFocusNode.unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  if (mapState.startLocation != null)
                    Marker(
                      point: mapState.startLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  if (mapState.endLocation != null)
                    Marker(
                      point: mapState.endLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  if (mapState.currentLocation != null)
                    Marker(
                      point: mapState.currentLocation!,
                      width: 40,
                      height: 40,
                      child: AnimatedOpacity(
                        opacity: mapState.isBlinking ? 0.2 : 1.0,
                        duration: Duration(milliseconds: 500),
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
              if (mapState.routeCoordinates.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: mapState.routeCoordinates,
                      color: Colors.blue.withOpacity(0.7),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Current Location",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        if (mapState.currentLocation != null)
                          Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildSearchField(
                    context,
                    "Destination",
                    _endController,
                    _endFocusNode,
                    ref,
                  ),
                ],
              ),
            ),
          ),
          if (mapState.directions.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Step-by-Step Directions",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDistance(
                                _calculateTotalDistance(mapState.directions)),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: mapState.directions.length,
                        itemBuilder: (context, index) {
                          final direction = mapState.directions[index];
                          return ListTile(
                            leading: _getDirectionIcon(
                                direction['type'], direction['modifier']),
                            title: Text(
                              direction['instruction'],
                              style: TextStyle(fontSize: 16),
                            ),
                            trailing: Text(
                              _formatDistance(direction['distance']),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (mapState.isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Widget _buildSearchField(
    BuildContext context,
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    WidgetRef ref,
  ) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[100],
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  final notifier = ref.read(mapProvider.notifier);
                  notifier.state = notifier.state.copyWith(
                    endLocation: null,
                    routeCoordinates: [],
                    directions: [],
                  );
                  setState(() {
                    _showRouteDistance = false;
                  });
                },
              )
            : null,
      ),
      onSubmitted: (value) async {
        if (value.isNotEmpty) {
          await ref
              .read(mapProvider.notifier)
              .searchAndSetLocation(value, false);
        }
      },
    );
  }

  int _calculateTotalDistance(List<Map<String, dynamic>> directions) {
    return directions.fold(0, (sum, dir) => sum + (dir['distance'] as int));
  }

  Icon _getDirectionIcon(String type, String? modifier) {
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left':
            return Icon(Icons.turn_left, color: Colors.blue);
          case 'right':
            return Icon(Icons.turn_right, color: Colors.green);
          default:
            return Icon(Icons.directions, color: Colors.grey);
        }
      case 'depart':
        return Icon(Icons.flag, color: Colors.green);
      case 'arrive':
        return Icon(Icons.flag, color: Colors.red);
      default:
        return Icon(Icons.directions, color: Colors.grey);
    }
  }
}