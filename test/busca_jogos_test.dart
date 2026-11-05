import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nba_game_day/data/busca_jogos.dart';
import 'package:nba_game_day/data/espn_api.dart';
import 'package:nba_game_day/data/jogos_repository.dart';
import 'package:nba_game_day/utils/datas.dart';

http.Response fixture(String nome) => http.Response.bytes(
  utf8.encode(File('test/fixtures/$nome').readAsStringSync()),
  200,
);

http.Response encerrados() => fixture('espn_scoreboard.json'); // dates=20261102
http.Response agendados() =>
    fixture('espn_scoreboard_agendados.json'); // dates=20261104
http.Response vazio() => fixture('espn_scoreboard_vazio.json');
http.Response erro500() => http.Response('erro', 500);

/// Em 10/11, longe dos dias das fixtures.
final agora = DateTime.utc(2026, 11, 10, 15);

/// 02/11 em Brasília: os 12 jogos da fixture que não caem na madrugada de 03/11.
final dia2 = (
  inicio: diaDeBrasilia(2026, 11, 2),
  fim: diaDeBrasilia(2026, 11, 2),
);

/// 04/11 em Brasília: os jogos da fixture de agendados.
final dia4 = (
  inicio: diaDeBrasilia(2026, 11, 4),
  fim: diaDeBrasilia(2026, 11, 4),
);

class Cenario {
  Cenario(this.respostas, {bool forcarMock = false}) {
    repository = JogosRepository(
      api: EspnApi(
        client: MockClient((requisicao) async {
          final data = requisicao.url.queryParameters['dates']!;
          consultas.add(data);
          final espera = esperas[data];
          if (espera != null) await espera.future;
          return (respostas[data] ?? vazio)();
        }),
      ),
      agora: () => agora,
      forcarMock: forcarMock,
    );
    busca = BuscaJogos(repository);
  }

  final Map<String, http.Response Function()> respostas;
  final consultas = <String>[];

  /// Datas cuja resposta só sai quando o Completer é concluído.
  final esperas = <String, Completer<void>>{};
  late final JogosRepository repository;
  late final BuscaJogos busca;
}

void main() {
  test('período dentro da lista padrão não consulta a ESPN de novo', () async {
    final cenario = Cenario({});
    await cenario.repository.carregar();
    cenario.consultas.clear();

    final hoje = apenasDia(agora);
    await cenario.busca.escolherPeriodo((
      inicio: hoje,
      fim: hoje.add(const Duration(days: 2)),
    ));

    expect(cenario.consultas, isEmpty);
    expect(cenario.busca.usaConsultaDePeriodo, isFalse);
  });

  test('período fora da lista busca só os dias necessários', () async {
    final cenario = Cenario({'20261102': encerrados});
    await cenario.repository.carregar();
    cenario.consultas.clear();

    await cenario.busca.escolherPeriodo(dia2);

    expect(cenario.consultas, unorderedEquals(['20261101', '20261102']));
    expect(cenario.busca.usaConsultaDePeriodo, isTrue);
    // Os 3 da madrugada de 03/11 ficam de fora.
    expect(cenario.busca.resultado, hasLength(12));
    final horarios = cenario.busca.resultado.map((j) => j.dataHora).toList();
    expect(horarios, [...horarios]..sort());
  });

  test('a madrugada do período vem do dia americano anterior', () async {
    final cenario = Cenario({'20261102': encerrados});
    await cenario.repository.carregar();

    await cenario.busca.escolherPeriodo((
      inicio: diaDeBrasilia(2026, 11, 3),
      fim: diaDeBrasilia(2026, 11, 3),
    ));

    expect(
      cenario.busca.resultado.map((j) => j.id),
      unorderedEquals(['401909919', '401909920', '401909921']),
    );
  });

  test('os outros filtros valem sobre os jogos do período', () async {
    final cenario = Cenario({'20261102': encerrados});
    await cenario.repository.carregar();
    await cenario.busca.escolherPeriodo(dia2);

    cenario.busca.atualizar((f) => f.copiarCom(texto: 'cavaliers'));

    expect(cenario.busca.resultado.single.id, '401909907');
    expect(cenario.busca.filtro.periodo, dia2);
  });

  test(
    'o jogo do período abre nos detalhes e não entra na lista padrão',
    () async {
      final cenario = Cenario({'20261102': encerrados});
      await cenario.repository.carregar();
      await cenario.busca.escolherPeriodo(dia2);

      expect(
        cenario.repository.jogos.map((j) => j.id),
        isNot(contains('401909907')),
      );
      final jogo = await cenario.repository.buscarPorId('401909907');
      expect(jogo?.mandante, 'Cleveland Cavaliers');
    },
  );

  test('sem período, volta para a lista padrão', () async {
    final cenario = Cenario({'20261102': encerrados});
    await cenario.repository.carregar();
    final padrao = cenario.busca.resultado.length;
    await cenario.busca.escolherPeriodo(dia2);

    await cenario.busca.escolherPeriodo(null);

    expect(cenario.busca.usaConsultaDePeriodo, isFalse);
    expect(cenario.busca.resultado, hasLength(padrao));
  });

  test('a resposta de um período antigo é descartada', () async {
    final cenario = Cenario({'20261102': encerrados, '20261104': agendados});
    await cenario.repository.carregar();
    final lenta = cenario.esperas['20261102'] = Completer<void>();

    final primeira = cenario.busca.escolherPeriodo(dia2);
    expect(cenario.busca.carregando, isTrue);
    await cenario.busca.escolherPeriodo(dia4);
    final doDia4 = cenario.busca.resultado.map((j) => j.id).toList();

    lenta.complete();
    await primeira;

    expect(doDia4, isNotEmpty);
    expect(cenario.busca.carregando, isFalse);
    expect(cenario.busca.filtro.periodo, dia4);
    expect(cenario.busca.resultado.map((j) => j.id), doDia4);
  });

  test(
    'voltar à lista padrão também descarta a consulta em andamento',
    () async {
      final cenario = Cenario({'20261102': encerrados});
      await cenario.repository.carregar();
      final lenta = cenario.esperas['20261102'] = Completer<void>();

      final consulta = cenario.busca.escolherPeriodo(dia2);
      await cenario.busca.limpar();
      lenta.complete();
      await consulta;

      expect(cenario.busca.carregando, isFalse);
      expect(cenario.busca.usaConsultaDePeriodo, isFalse);
    },
  );

  test('todos os dias falham: avisa, sem afirmar que não há jogos', () async {
    final cenario = Cenario({'20261101': erro500, '20261102': erro500});
    await cenario.repository.carregar();

    await cenario.busca.escolherPeriodo(dia2);

    expect(cenario.busca.periodoFalhou, isTrue);
    expect(cenario.busca.diasComFalha, 0);
    expect(cenario.busca.resultado, isEmpty);
  });

  test('falha parcial mostra o que veio e conta os dias', () async {
    final cenario = Cenario({'20261101': erro500, '20261102': encerrados});
    await cenario.repository.carregar();

    await cenario.busca.escolherPeriodo(dia2);

    expect(cenario.busca.periodoFalhou, isFalse);
    expect(cenario.busca.diasComFalha, 1);
    expect(cenario.busca.resultado, hasLength(12));
  });

  test('recarregar consulta o período de novo e limpa a falha', () async {
    final respostas = <String, http.Response Function()>{
      '20261101': erro500,
      '20261102': erro500,
    };
    final cenario = Cenario(respostas);
    await cenario.repository.carregar();
    await cenario.busca.escolherPeriodo(dia2);
    expect(cenario.busca.periodoFalhou, isTrue);

    respostas
      ..['20261101'] = vazio
      ..['20261102'] = encerrados;
    await cenario.busca.recarregar();

    expect(cenario.busca.periodoFalhou, isFalse);
    expect(cenario.busca.resultado, hasLength(12));
  });

  test('limparSelecoes tira o período e mantém o texto', () async {
    final cenario = Cenario({'20261102': encerrados});
    await cenario.repository.carregar();
    cenario.busca.atualizar((f) => f.copiarCom(texto: 'celtics'));
    await cenario.busca.escolherPeriodo(dia2);

    await cenario.busca.limparSelecoes();

    expect(cenario.busca.filtro.periodo, isNull);
    expect(cenario.busca.filtro.texto, 'celtics');
    expect(cenario.busca.usaConsultaDePeriodo, isFalse);
  });

  test('FONTE_DADOS=mock não consulta a ESPN para nenhum período', () async {
    final cenario = Cenario({'20261102': encerrados}, forcarMock: true);
    await cenario.repository.carregar();

    await cenario.busca.escolherPeriodo(dia2);

    expect(cenario.consultas, isEmpty);
    expect(cenario.busca.resultado, isEmpty);
    expect(cenario.busca.periodoFalhou, isFalse);
  });

  test('não avisa depois de descartada', () async {
    final cenario = Cenario({'20261102': encerrados});
    await cenario.repository.carregar();
    final lenta = cenario.esperas['20261102'] = Completer<void>();

    final consulta = cenario.busca.escolherPeriodo(dia2);
    cenario.busca.dispose();
    lenta.complete();

    await expectLater(consulta, completes);
  });
}
