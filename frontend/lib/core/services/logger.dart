import 'package:logger/logger.dart';

/// App-wide logger (AGENTS.md §5/§9). Use this instead of `print`,
/// `debugPrint`, or `dart:developer`'s `log`.
final Logger logger = Logger(
  printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5),
);
