import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/demo_queue_repository.dart';
import '../data/queue_repository.dart';
import '../data/supabase_queue_repository.dart';
import 'app_config.dart';

Future<QueueRepository> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.hasSupabase) return DemoQueueRepository();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  return SupabaseQueueRepository(Supabase.instance.client);
}
