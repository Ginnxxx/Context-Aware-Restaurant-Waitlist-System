import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/demo_queue_repository.dart';
import '../data/queue_repository.dart';
import '../shared/brand_widgets.dart';
import 'screens/staff_dashboard.dart';

export 'screens/checkin_page.dart';
export 'screens/insights_page.dart';
export 'screens/live_queue_page.dart';
export 'screens/overview_page.dart';
export 'screens/staff_dashboard.dart';
export 'screens/staff_settings_page.dart';
export 'widgets/side_navigation.dart' show StaffPage;

class StaffApp extends StatelessWidget {
  const StaffApp({super.key, this.repository});

  final QueueRepository? repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QueueLess Staff',
    debugShowCheckedModeBanner: false,
    theme: QueueLessTheme.light,
    home: _StaffGate(repository: repository ?? DemoQueueRepository()),
  );
}

class _StaffGate extends StatefulWidget {
  const _StaffGate({required this.repository});
  final QueueRepository repository;

  @override
  State<_StaffGate> createState() => _StaffGateState();
}

class _StaffGateState extends State<_StaffGate> {
  bool signedIn = false;

  @override
  void initState() {
    super.initState();
    signedIn = widget.repository.isStaffSignedIn;
  }

  @override
  Widget build(BuildContext context) => signedIn
      ? StaffDashboard(repository: widget.repository)
      : _StaffLogin(
          repository: widget.repository,
          onSignedIn: () => setState(() => signedIn = true),
        );
}

class _StaffLogin extends StatefulWidget {
  const _StaffLogin({required this.repository, required this.onSignedIn});
  final QueueRepository repository;
  final VoidCallback onSignedIn;

  @override
  State<_StaffLogin> createState() => _StaffLoginState();
}

class _StaffLoginState extends State<_StaffLogin> {
  String email = '';
  String password = '';
  String? error;
  bool busy = false;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.signInStaff(email: email, password: password);
      widget.onSignedIn();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandMark(),
                  const SizedBox(height: 34),
                  Text(
                    'Welcome back.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in with your restaurant staff account.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    onChanged: (value) => email = value,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => password = value,
                    obscureText: true,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.coral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy ? 'Signing in…' : 'Sign in to dashboard',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
