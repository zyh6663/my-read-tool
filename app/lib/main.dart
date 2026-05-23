import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'main_app.dart';

const kPaperDark = Color(0xFF1A1210);
const kPaperWarm = Color(0xFF231A15);
const kGold = Color(0xFFC9A96E);
const kVermilion = Color(0xFFB5433A);
const kInkWarm = Color(0xFFE8D5B7);
const kInkGray = Color(0xFF9B8E82);
const kCloudWhite = Color(0xFFF0EBE0);

const kGoldGradient = LinearGradient(
  colors: [Color(0xFFC9A96E), Color(0xFFE8D5B7), Color(0xFFC9A96E)],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.storage.request();
  runApp(const ReaderRootApp());
}
