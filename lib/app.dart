import 'package:flutter/material.dart';

import 'data/jogos_repository.dart';
import 'screens/detalhes_jogo_screen.dart';
import 'screens/home_screen.dart';
import 'tema.dart';

/// Instância única dos jogos, compartilhada pelas telas e pela navegação
/// vinda das notificações.
final jogosRepository = JogosRepository();

/// Permite navegar fora da árvore de widgets (ex.: ao tocar numa notificação).
final navigatorKey = GlobalKey<NavigatorState>();

/// Permite mostrar SnackBars fora da árvore de widgets (ex.: notificação que
/// chega com o app aberto).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

const rotaHome = '/';

/// Detalhes de um jogo; argumento: o id do jogo (String).
const rotaJogo = '/jogo';

class NbaGameDayApp extends StatelessWidget {
  const NbaGameDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: modoTema,
      builder: (context, modo, _) => MaterialApp(
        title: 'NBA Game Day',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: criarTema(),
        darkTheme: criarTema(Brightness.dark),
        themeMode: modo,
        initialRoute: rotaHome,
        onGenerateRoute: _gerarRota,
      ),
    );
  }

  static Route<void> _gerarRota(RouteSettings settings) {
    switch (settings.name) {
      case rotaJogo:
        final argumento = settings.arguments;
        final id = argumento is String ? argumento : '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              DetalhesJogoScreen(id: id, repository: jogosRepository),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => HomeScreen(repository: jogosRepository),
        );
    }
  }
}
