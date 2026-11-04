import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

/// Chamado pelo FCM quando chega uma mensagem com o app em segundo plano ou
/// fechado. Roda num isolate separado, por isso inicializa o Firebase de
/// novo. As notificações com título e texto são exibidas pelo próprio
/// Android; aqui só registramos no log.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const NbaGameDayApp());
  // Depois do runApp: o app já aparece enquanto o diálogo de permissão e
  // o token são resolvidos.
  notificationService.init();
}
