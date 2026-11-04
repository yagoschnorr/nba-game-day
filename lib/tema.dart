import 'package:flutter/material.dart';

/// Cores oficiais da NBA e os tons de apoio dos temas.
abstract final class CoresNba {
  static const azul = Color(0xFF1D428A);
  static const vermelho = Color(0xFFC8102E);
  static const preto = Color(0xFF000000);
  static const branco = Color(0xFFFFFFFF);

  /// Fundo do tema claro: um cinza bem claro, para os cards brancos se
  /// destacarem.
  static const fundo = Color(0xFFF2F4F8);

  /// Cards e painéis do tema escuro, sobre o fundo preto.
  static const cartaoEscuro = Color(0xFF171A21);

  /// O azul oficial é escuro demais para texto sobre preto; no tema escuro,
  /// títulos e botões usam este tom mais claro.
  static const azulClaro = Color(0xFF8FB0F0);

  /// O mesmo vale para ícones e textos vermelhos sobre os cards escuros.
  static const vermelhoClaro = Color(0xFFFF6B7D);
}

/// Tema escolhido pelo botão da Home. Fica só em memória: ao reabrir, o app
/// volta ao tema claro.
final modoTema = ValueNotifier<ThemeMode>(ThemeMode.light);

void alternarTema() {
  modoTema.value = modoTema.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
}

/// Tema do app: AppBar azul, vermelho nos destaques, fundo claro ou preto
/// conforme [brilho].
ThemeData criarTema([Brightness brilho = Brightness.light]) {
  final escuro = brilho == Brightness.dark;
  final principal = escuro ? CoresNba.azulClaro : CoresNba.azul;
  // Vermelho de ícones e textos; faixas e botões usam o oficial nos dois temas.
  final destaque = escuro ? CoresNba.vermelhoClaro : CoresNba.vermelho;
  final cartao = escuro ? CoresNba.cartaoEscuro : CoresNba.branco;
  final texto = escuro ? CoresNba.branco : CoresNba.preto;
  // O SnackBar usa a cor oposta à do fundo, para se destacar.
  final fundoAviso = escuro ? CoresNba.branco : CoresNba.preto;
  final textoAviso = escuro ? CoresNba.preto : CoresNba.branco;

  final esquema =
      ColorScheme.fromSeed(
        seedColor: CoresNba.azul,
        brightness: brilho,
      ).copyWith(
        primary: principal,
        onPrimary: escuro ? CoresNba.preto : CoresNba.branco,
        secondary: CoresNba.vermelho,
        onSecondary: CoresNba.branco,
        tertiary: destaque,
        onTertiary: escuro ? CoresNba.preto : CoresNba.branco,
        surface: cartao,
        onSurface: texto,
        inverseSurface: fundoAviso,
        onInverseSurface: textoAviso,
        inversePrimary: escuro ? CoresNba.azul : CoresNba.azulClaro,
      );

  return ThemeData(
    colorScheme: esquema,
    scaffoldBackgroundColor: escuro ? CoresNba.preto : CoresNba.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: CoresNba.azul,
      foregroundColor: CoresNba.branco,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: CoresNba.vermelho, width: 3)),
    ),
    cardTheme: CardThemeData(
      color: cartao,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cartao,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: fundoAviso,
      contentTextStyle: TextStyle(color: textoAviso),
      actionTextColor: escuro ? CoresNba.azul : CoresNba.branco,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CoresNba.vermelho,
    ),
    listTileTheme: ListTileThemeData(iconColor: destaque),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CoresNba.vermelho,
        foregroundColor: CoresNba.branco,
      ),
    ),
  );
}
