import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // Entry point: pre-run initialization (.env, etc.) goes here before runApp
  // (AGENTS.md §1). ProviderScope is the root of the Riverpod graph.
  runApp(const ProviderScope(child: NexaxApp()));
}
