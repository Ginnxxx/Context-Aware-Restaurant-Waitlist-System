import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../data/queue_repository.dart';

class PushNotice {
  const PushNotice({required this.title, required this.body, this.ticketId});

  final String title;
  final String body;
  final String? ticketId;
}

class PushNotificationService {
  bool get isSupported =>
      AppConfig.hasFirebase &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  final _notices = StreamController<PushNotice>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;

  Stream<PushNotice> get notices => _notices.stream;

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: AppConfig.firebaseApiKey,
            appId: AppConfig.firebaseAppId,
            messagingSenderId: AppConfig.firebaseMessagingSenderId,
            projectId: AppConfig.firebaseProjectId,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    } catch (_) {
      if (Firebase.apps.isEmpty) rethrow;
    }

    FirebaseMessaging.onBackgroundMessage(queueLessPushBackgroundHandler);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_emitNotice);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _emitNotice,
    );
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _emitNotice(initial);
    } catch (_) {}
    _initialized = true;
  }

  Future<void> enable(QueueRepository repository) async {
    if (!isSupported) {
      throw StateError('Firebase Cloud Messaging is not configured.');
    }
    try {
      await initialize();
    } catch (_) {
      throw StateError('Failed to initialize push notifications.');
    }

    NotificationSettings settings;
    try {
      settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      throw StateError(
        'Unable to reach Google notification services. Please check your network or VPN.',
      );
    }

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError(
        'Notification permission was declined. Enable it in Android settings.',
      );
    }

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      throw StateError(
        'Unable to reach Google notification server. Please verify your internet connection or VPN.',
      );
    }
    if (token == null || token.isEmpty) {
      throw StateError('Firebase could not create a notification token.');
    }
    await _saveToken(repository, token);
    await _tokenSubscription?.cancel();
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => _saveToken(repository, token),
    );
  }

  Future<bool> isAuthorized() async {
    if (!isSupported) return false;
    try {
      await initialize();
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToken(QueueRepository repository, String token) =>
      repository.registerDeviceInstallation(
        platform: 'android',
        fcmToken: token,
      );

  void _emitNotice(RemoteMessage message) {
    final notification = message.notification;
    _notices.add(
      PushNotice(
        title: notification?.title ?? 'QueueLess update',
        body: notification?.body ?? 'Your queue status has changed.',
        ticketId: message.data['ticket_id'],
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _notices.close();
  }
}

@pragma('vm:entry-point')
Future<void> queueLessPushBackgroundHandler(RemoteMessage message) async {
  // Notification payloads are displayed by Android. Keep this top-level
  // handler registered for future data-only message work.
}
