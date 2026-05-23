import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'main_app.dart';

const kPrimaryGreen = Color(0xFF4CAF50);
const kDarkBg = Color(0xFF121212);
const kDarkSurface = Color(0xFF1E1E1E);
const kLightBg = Color(0xFFF5F5F5);
const kLightSurface = Color(0xFFFFFFFF);
const kTextDark = Color(0xFFE0E0E0);
const kTextLight = Color(0xFF212121);

// legacy — still referenced by widgets
const kPaperDark = Color(0xFF121212);
const kPaperWarm = Color(0xFF1E1E1E);
const kGold = Color(0xFF4CAF50);
const kVermilion = Color(0xFFE53935);
const kInkWarm = Color(0xFFE0E0E0);
const kInkGray = Color(0xFF9E9E9E);
const kCloudWhite = Color(0xFFFFFFFF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.storage.request();
  runApp(const ReaderRootApp());
}
