import 'package:flutter/material.dart';

import 'main_app.dart' as app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const app.ReaderRootApp());
}
