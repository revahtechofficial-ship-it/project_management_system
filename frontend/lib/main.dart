import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() {
  // ProviderScope is the root of the Riverpod dependency graph.
  runApp(const ProviderScope(child: NexaxApp()));
}
