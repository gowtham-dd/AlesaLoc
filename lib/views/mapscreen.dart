import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:locationproject/controller/map_controllar.dart';

class MapPage extends ConsumerWidget {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    final mapNotifier = ref.read(mapProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text("Map Navigation"),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () => mapNotifier.getUserLocation(),
          ),
          IconButton(
            icon: Icon(Icons.directions),
            onPressed: () async {
              if (_startController.text.isNotEmpty &&
                  _endController.text.isNotEmpty) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Calculating route...")),
                  );

                  await mapNotifier.searchAndSetLocation(
                    _startController.text,
                    true,
                  );
                  await mapNotifier.searchAndSetLocation(
                    _endController.text,
                    false,
                  );
                  await mapNotifier.getDirections();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Please enter both locations")),
                );
              }
            },
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
                _startFocusNode.unfocus();
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
                  _buildSearchField(
                    context,
                    "Start Location",
                    _startController,
                    _startFocusNode,
                    ref,
                  ),
                  SizedBox(height: 12),
                  _buildSearchField(
                    context,
                    "End Location",
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
                      child: Text(
                        "Turn-by-Turn Directions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                            leading: Icon(Icons.directions),
                            title: Text(direction['instruction']),
                            subtitle: Text("${direction['distance']} meters"),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
        suffixIcon:
            controller.text.isNotEmpty
                ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    final notifier = ref.read(mapProvider.notifier);
                    if (label == "Start Location") {
                      notifier.state = notifier.state.copyWith(
                        startLocation: null,
                        routeCoordinates: [],
                        directions: [],
                      );
                    } else {
                      notifier.state = notifier.state.copyWith(
                        endLocation: null,
                        routeCoordinates: [],
                        directions: [],
                      );
                    }
                  },
                )
                : null,
      ),
      onSubmitted: (value) async {
        if (value.isNotEmpty) {
          await ref
              .read(mapProvider.notifier)
              .searchAndSetLocation(value, label == "Start Location");
        }
      },
    );
  }
}
