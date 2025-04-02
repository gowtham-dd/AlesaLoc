import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:locationproject/views/mapscreen.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Consumer(
        builder: (context, ref, child) {
          return MapPage(); // Use MapScreen instead of MapControllerNotifier
        },
      ),
    );
  }
}
