import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  // The status and navigation bars are dressed inside the app, where the
  // theme in force is known — set once here they would stay light after the
  // system switched to dark.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SportVenueApp());
}
