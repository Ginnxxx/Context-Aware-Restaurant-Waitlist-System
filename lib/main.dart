import 'package:flutter/material.dart';

import 'core/app_bootstrap.dart';
import 'customer/customer_app.dart';

Future<void> main() async {
  final repository = await bootstrapApp();
  try {
    await repository.ensureCustomerSession();
  } catch (_) {
    // Best-effort at startup; retry when user joins queue.
  }
  runApp(CustomerApp(repository: repository));
}
