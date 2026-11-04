import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app.dart' show navigatorKey, rotaJogo, scaffoldMessengerKey;

/// Instância única usada pelo app.
final notificationService = NotificationService();

/// Chave dos dados personalizados (Firebase Console → Opções adicionais →
/// Dados personalizados) com o ID do jogo a abrir.
const chaveJogoId = 'jogo_id';

/// Concentra tudo o que envolve o Firebase Cloud Messaging: permissão,
/// token e o tratamento do toque nas notificações.
class NotificationService {
  /// Token FCM do aparelho; `null` até ser obtido. É o valor colado no
  /// Firebase Console em "Enviar mensagem de teste".
  final token = ValueNotifier<String?>(null);

  /// Resultado do pedido de permissão; `null` até a resposta.
  final permissao = ValueNotifier<AuthorizationStatus?>(null);

  // Acessado só depois do Firebase.initializeApp (em init), para que os
  // widgets possam ler token/permissao sem o Firebase nos testes.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool _iniciado = false;
  String? _ultimoMessageIdTratado;

  Future<void> init() async {
    if (_iniciado) return;
    _iniciado = true;

    // Navegação primeiro: o diálogo de permissão fica esperando o usuário
    // e não pode atrasar a abertura do jogo tocado.
    await _configurarToques();

    // App aberto: o Android não mostra a notificação na bandeja, então o
    // app avisa com um SnackBar.
    FirebaseMessaging.onMessage.listen(mostrarAvisoEmPrimeiroPlano);

    await _pedirPermissao();
    await _obterToken();
    // ignore: deprecated_member_use, ver _obterToken.
    _messaging.onTokenRefresh.listen(
      _atualizarToken,
      onError: (Object erro) =>
          debugPrint('[FCM] erro no onTokenRefresh: $erro'),
    );
  }

  Future<void> _configurarToques() async {
    // App em segundo plano: o toque traz o app de volta e dispara este
    // stream.
    FirebaseMessaging.onMessageOpenedApp.listen(tratarToque);

    // App fechado: o toque inicia o app, e a mensagem fica disponível aqui.
    try {
      final inicial = await _messaging.getInitialMessage();
      if (inicial != null) {
        debugPrint('[FCM] app aberto pela notificação ${inicial.messageId}');
        _quandoNavegadorPronto(() => tratarToque(inicial));
      }
    } catch (erro) {
      debugPrint('[FCM] erro no getInitialMessage: $erro');
    }
  }

  /// Abre os detalhes do jogo indicado em `jogo_id`. Notificações sem esse
  /// dado só abrem o app (na tela em que ele estiver).
  @visibleForTesting
  void tratarToque(RemoteMessage message) {
    // Versões antigas do firebase_messaging entregavam o mesmo toque por
    // getInitialMessage e onMessageOpenedApp, abrindo a tela duas vezes.
    final messageId = message.messageId;
    if (messageId != null && messageId == _ultimoMessageIdTratado) return;
    _ultimoMessageIdTratado = messageId;

    final id = _jogoId(message);
    if (id == null) return;
    abrirJogo(id);
  }

  /// SnackBar para mensagens que chegam com o app em primeiro plano. Se a
  /// mensagem tiver `jogo_id`, a ação "Ver" abre o jogo como o toque na
  /// notificação faria.
  @visibleForTesting
  void mostrarAvisoEmPrimeiroPlano(RemoteMessage message) {
    debugPrint('[FCM] primeiro plano: ${message.messageId}');
    final titulo = message.notification?.title;
    final texto = message.notification?.body;
    final id = _jogoId(message);
    if (titulo == null && texto == null && id == null) return;

    final mensageiro = scaffoldMessengerKey.currentState;
    if (mensageiro == null) return;
    mensageiro
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo ?? 'Nova notificação',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (texto != null) Text(texto),
            ],
          ),
          duration: const Duration(seconds: 8),
          // Com ação, o SnackBar ficaria na tela até ser tocado.
          persist: false,
          action: id == null
              ? null
              : SnackBarAction(label: 'Ver', onPressed: () => abrirJogo(id)),
        ),
      );
  }

  /// `jogo_id` dos dados personalizados, sem espaços; `null` se ausente.
  static String? _jogoId(RemoteMessage message) {
    final id = message.data[chaveJogoId];
    return id is String && id.trim().isNotEmpty ? id.trim() : null;
  }

  /// Mesma rota usada pelo card da Home. `pushNamed` (e não
  /// `pushReplacement`) para que voltar leve à Home.
  void abrirJogo(String id) {
    debugPrint('[FCM] abrindo o jogo $id');
    navigatorKey.currentState?.pushNamed(rotaJogo, arguments: id);
  }

  /// Executa [acao] quando o MaterialApp (e o navigatorKey) já estiver
  /// montado. Na abertura a frio, getInitialMessage pode responder antes
  /// do primeiro frame.
  void _quandoNavegadorPronto(VoidCallback acao) {
    if (navigatorKey.currentState != null) {
      acao();
      return;
    }
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => acao())
      ..scheduleFrame();
  }

  /// No Android 13+ abre o diálogo de POST_NOTIFICATIONS. Nas versões
  /// anteriores a permissão já é concedida na instalação.
  Future<void> _pedirPermissao() async {
    try {
      final configuracao = await _messaging.requestPermission();
      permissao.value = configuracao.authorizationStatus;
      debugPrint('[FCM] permissão: ${configuracao.authorizationStatus.name}');
    } catch (erro) {
      debugPrint('[FCM] erro ao pedir permissão: $erro');
    }
  }

  Future<void> _obterToken() async {
    try {
      // getToken() está obsoleto no firebase_messaging 17 em favor de
      // register()/onRegistered, mas a API nova entrega um Firebase
      // Installation ID (para envio direto por backend), e não o token FCM
      // que o Firebase Console pede em "Enviar mensagem de teste".
      // ignore: deprecated_member_use
      _atualizarToken(await _messaging.getToken());
    } catch (erro) {
      // Ex.: sem internet ou aparelho sem Google Play Services.
      debugPrint('[FCM] erro ao obter o token: $erro');
    }
  }

  void _atualizarToken(String? novo) {
    if (novo == null) return;
    token.value = novo;
    // debugPrint também escreve no log do build de release; o token só vai
    // para o log em modo debug. No release, ele fica no painel de demonstração.
    if (kDebugMode) debugPrint('[FCM] token: $novo');
  }
}
