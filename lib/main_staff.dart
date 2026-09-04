import 'package:flutter/material.dart';

import 'core/app_bootstrap.dart';
import 'staff/staff_app.dart';

Future<void> main() async {
  final repository = await bootstrapApp();
  runApp(StaffApp(repository: repository));
}
