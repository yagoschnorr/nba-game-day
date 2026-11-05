import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nba_game_day/data/jogos_repository.dart';
import 'package:nba_game_day/screens/home_screen.dart';

void main() {
  // Data fixa: as opções de horário dependem do relógio, e os horários do
  // mock são relativos a "agora".
  Future<void> abrirHome(WidgetTester tester, {int horaDeBrasilia = 12}) async {
    // Tela alta: todos os cards do mock ficam montados na lista.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: JogosRepository(
            forcarMock: true,
            agora: () => DateTime.utc(2026, 11, 2, horaDeBrasilia + 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder texto(String valor) => find.text(valor);

  testWidgets('a busca reduz a lista e o X a restaura', (tester) async {
    await abrirHome(tester);
    expect(texto('Boston Celtics'), findsOneWidget);
    expect(texto('Miami Heat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'celtics');
    await tester.pump();

    expect(texto('Boston Celtics'), findsOneWidget);
    expect(texto('Miami Heat'), findsNothing);
    expect(texto('1 jogo'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();

    expect(texto('Miami Heat'), findsOneWidget);
    expect(texto('1 jogo'), findsNothing);
  });

  testWidgets('busca sem resultado avisa e "Limpar" volta tudo', (
    tester,
  ) async {
    await abrirHome(tester);

    await tester.enterText(find.byType(TextField), 'flamengo');
    await tester.pump();

    expect(texto('Nenhum jogo encontrado'), findsOneWidget);
    expect(texto('Nenhum jogo'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar'));
    await tester.pump();

    expect(texto('Nenhum jogo encontrado'), findsNothing);
    expect(texto('Boston Celtics'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });

  testWidgets('o painel filtra por time, dia e horário', (tester) async {
    await abrirHome(tester);

    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Ver 6 jogos'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Hoje'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 3 jogos'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '21h30'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 2 jogos'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Miami Heat'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 1 jogo'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ver 1 jogo'));
    await tester.pumpAndSettle();

    expect(texto('Miami Heat'), findsOneWidget);
    expect(texto('Boston Celtics'), findsNothing);
    expect(texto('1 jogo'), findsOneWidget);
    expect(texto('3'), findsOneWidget); // selo do botão de filtros
  });

  testWidgets('"Hoje" lista tudo, mas só oferece horários por começar', (
    tester,
  ) async {
    // Às 22h, os dois jogos das 21h30 já começaram; falta o das 23h.
    await abrirHome(tester, horaDeBrasilia: 22);
    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Hoje'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Ver 3 jogos'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '23h'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '21h30'), findsNothing);
    expect(find.widgetWithText(FilterChip, '22h'), findsNothing);
  });

  testWidgets('sem jogos por começar, a seção de horário avisa', (
    tester,
  ) async {
    await abrirHome(tester, horaDeBrasilia: 23);
    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Hoje'));
    await tester.pump();

    expect(find.text('Nenhum jogo por começar.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ver 3 jogos'), findsOneWidget);
  });

  testWidgets('o painel filtra por conferência', (tester) async {
    await abrirHome(tester);
    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Oeste'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 3 jogos'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Oeste'));
    await tester.tap(find.widgetWithText(FilterChip, 'Leste x Oeste'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 1 jogo'), findsOneWidget);
  });

  testWidgets('tocar de novo no atalho de data tira o período', (tester) async {
    await abrirHome(tester);
    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Amanhã'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 2 jogos'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Amanhã'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 6 jogos'), findsOneWidget);
  });

  testWidgets('o calendário escolhe um dia e o chip mostra a data', (
    tester,
  ) async {
    await abrirHome(tester);
    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Escolher datas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Um dia só'), findsOneWidget);
    // A digitação de datas passaria por cima do limite de dias.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);

    // Dia 15 do mês aberto, tocado duas vezes para virar um período de um dia.
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Escolher datas'), findsNothing);
    expect(find.textContaining(RegExp(r'^15/\d\d$')), findsOneWidget);

    await tester.tap(find.byTooltip('Tirar período'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Escolher datas'), findsOneWidget);
  });

  testWidgets('"Limpar" do painel mantém o texto da busca', (tester) async {
    await abrirHome(tester);
    await tester.enterText(find.byType(TextField), 'heat');
    await tester.pump();

    await tester.tap(find.byTooltip('Filtrar jogos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Amanhã'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Ver 0 jogos'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(TextButton, 'Limpar'),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Ver 1 jogo'), findsOneWidget);
  });
}
