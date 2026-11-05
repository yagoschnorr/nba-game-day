import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nba_game_day/data/espn_api.dart';
import 'package:nba_game_day/data/jogos_mock.dart';
import 'package:nba_game_day/models/conferencia.dart';
import 'package:nba_game_day/models/filtro_jogos.dart';
import 'package:nba_game_day/models/jogo.dart';
import 'package:nba_game_day/utils/datas.dart';

/// 02/11 às 15h em Brasília. Os jogos do mock são, em Brasília:
///   hoje:   mock-1 BOS x LAL 21h30, mock-2 NYK x MIA 21h30, mock-3 DEN x OKC 23h
///   amanhã: mock-4 MIL x PHI 22h,   mock-5 DAL x SAS 22h30
///   depois: mock-6 ATL x CHI 21h30
final agora = DateTime.utc(2026, 11, 2, 18);
final jogos = gerarJogosMock(agora);
final hoje = apenasDia(agora);
final amanha = hoje.add(const Duration(days: 1));

List<String> ids(FiltroJogos filtro) =>
    filtro.aplicar(jogos).map((j) => j.id).toList();

Jogo jogoAs(String id, DateTime dataHora) => Jogo(
  id: id,
  mandante: 'Casa',
  visitante: 'Fora',
  dataHora: dataHora,
  arena: '',
  cidade: '',
  status: 'Agendado',
);

void main() {
  test('sem filtro, passam todos os jogos', () {
    const filtro = FiltroJogos(texto: '   ');
    expect(filtro.ativo, isFalse);
    expect(filtro.aplicar(jogos), hasLength(6));
  });

  group('busca por texto', () {
    test('acha pelo trecho do nome, sem diferenciar maiúsculas', () {
      expect(ids(const FiltroJogos(texto: 'lakers')), ['mock-1']);
      expect(ids(const FiltroJogos(texto: '  CELT ')), ['mock-1']);
    });

    test('procura no mandante e no visitante', () {
      expect(ids(const FiltroJogos(texto: 'boston')), ['mock-1']);
      expect(ids(const FiltroJogos(texto: 'los angeles')), ['mock-1']);
    });

    test('acha pela sigla', () {
      expect(ids(const FiltroJogos(texto: 'okc')), ['mock-3']);
    });

    test('sem correspondência, a lista fica vazia', () {
      expect(ids(const FiltroJogos(texto: 'flamengo')), isEmpty);
    });

    test('jogo sem sigla não quebra a busca', () {
      final jogo = jogoAs('1', agora);
      expect(const FiltroJogos(texto: 'casa').aplicar([jogo]), [jogo]);
      expect(const FiltroJogos(texto: 'xyz').aplicar([jogo]), isEmpty);
    });
  });

  group('filtros', () {
    test('times: vale qualquer um dos escolhidos, em casa ou fora', () {
      expect(ids(const FiltroJogos(times: {'Miami Heat', 'Chicago Bulls'})), [
        'mock-2',
        'mock-6',
      ]);
    });

    test('período: compara o dia de Brasília', () {
      expect(ids(FiltroJogos(periodo: (inicio: amanha, fim: amanha))), [
        'mock-4',
        'mock-5',
      ]);

      // Os dois são de 03/11 em UTC, mas em Brasília um cai à 0h30 de 03/11
      // e o outro às 22h de 02/11.
      final madrugada = jogoAs('a', DateTime.utc(2026, 11, 3, 3, 30));
      final noite = jogoAs('b', DateTime.utc(2026, 11, 3, 1));
      expect(
        FiltroJogos(periodo: (inicio: amanha, fim: amanha))
            .aplicar([madrugada, noite]),
        [madrugada],
      );
    });

    test('horários: compara o horário de Brasília', () {
      expect(ids(const FiltroJogos(horarios: {'21h30'})), [
        'mock-1',
        'mock-2',
        'mock-6',
      ]);
      expect(ids(const FiltroJogos(horarios: {'22h', '23h'})), [
        'mock-3',
        'mock-4',
      ]);
    });

    test('critérios diferentes precisam valer juntos', () {
      final deHoje = (inicio: hoje, fim: hoje);
      expect(ids(FiltroJogos(periodo: deHoje, horarios: const {'21h30'})), [
        'mock-1',
        'mock-2',
      ]);
      expect(
        ids(
          FiltroJogos(
            texto: 'knicks',
            periodo: deHoje,
            horarios: const {'21h30'},
            times: const {'Boston Celtics'},
          ),
        ),
        isEmpty,
      );
    });
  });

  group('conferências', () {
    test('Leste e Oeste valem para qualquer um dos dois times', () {
      expect(ids(const FiltroJogos(conferencias: {FiltroConferencia.leste})), [
        'mock-1',
        'mock-2',
        'mock-4',
        'mock-6',
      ]);
      expect(ids(const FiltroJogos(conferencias: {FiltroConferencia.oeste})), [
        'mock-1',
        'mock-3',
        'mock-5',
      ]);
    });

    test('"Leste x Oeste" só aceita um time de cada conferência', () {
      expect(
        ids(
          const FiltroJogos(
            conferencias: {FiltroConferencia.entreConferencias},
          ),
        ),
        ['mock-1'],
      );
    });

    test('marcar Leste e Oeste traz os jogos das duas', () {
      expect(
        ids(
          const FiltroJogos(
            conferencias: {FiltroConferencia.leste, FiltroConferencia.oeste},
          ),
        ),
        hasLength(6),
      );
    });

    test('time fora das listas não entra em nenhuma conferência', () {
      final jogo = jogoAs('1', agora);
      for (final opcao in FiltroConferencia.values) {
        expect(opcao.aceita(jogo), isFalse);
      }
    });

    test('todos os times das respostas da ESPN têm conferência', () {
      for (final fixture in [
        'espn_scoreboard.json',
        'espn_scoreboard_agendados.json',
      ]) {
        final json = jsonDecode(
          File('test/fixtures/$fixture').readAsStringSync(),
        );
        for (final jogo in parseScoreboard(json)) {
          final leste = FiltroConferencia.leste.aceita(jogo);
          final oeste = FiltroConferencia.oeste.aceita(jogo);
          expect(leste || oeste, isTrue, reason: jogo.mandante);
          expect(
            FiltroConferencia.entreConferencias.aceita(jogo),
            leste && oeste,
            reason: '${jogo.mandante} x ${jogo.visitante}',
          );
        }
      }
    });
  });

  test('selecoes conta os itens marcados, sem a busca', () {
    final filtro = FiltroJogos(
      texto: 'knicks',
      periodo: (inicio: hoje, fim: hoje),
      conferencias: const {FiltroConferencia.leste},
      horarios: const {'21h30', '22h'},
      times: const {'Miami Heat'},
    );
    expect(filtro.selecoes, 5);
    expect(filtro.ativo, isTrue);
  });

  test('comPeriodo troca ou tira o período e mantém o resto', () {
    final periodo = (inicio: hoje, fim: hoje);
    final filtro = FiltroJogos(
      texto: 'bos',
      periodo: periodo,
      horarios: const {'22h'},
    );
    expect(filtro.copiarCom(texto: 'x').periodo, periodo);
    final semPeriodo = filtro.comPeriodo(null);
    expect(semPeriodo.periodo, isNull);
    expect(semPeriodo.texto, 'bos');
    expect(semPeriodo.horarios, {'22h'});
  });

  group('OpcoesFiltro', () {
    test('lista os times sem repetir, em ordem', () {
      final opcoes = OpcoesFiltro.de(jogos, const FiltroJogos(), agora: agora);
      expect(opcoes.times, hasLength(12));
      expect(opcoes.times.first.nome, 'Atlanta Hawks');
      expect(opcoes.times.first.sigla, 'ATL');
      expect(opcoes.times.last.nome, 'San Antonio Spurs');
    });

    test('deixa a madrugada depois das 23h', () {
      final opcoes = OpcoesFiltro.de(
        [
          jogoAs('a', DateTime.utc(2026, 11, 3, 3, 30)), // 0h30
          jogoAs('b', DateTime.utc(2026, 11, 3, 2)), // 23h
          jogoAs('c', DateTime.utc(2026, 11, 3, 0)), // 21h
          jogoAs('d', DateTime.utc(2026, 11, 3, 3)), // 0h
          jogoAs('e', DateTime.utc(2026, 11, 2, 18)), // 15h
        ],
        const FiltroJogos(),
        agora: DateTime.utc(2026, 11, 2, 12),
      );
      expect(opcoes.horarios, ['15h', '21h', '23h', '0h', '0h30']);
    });

    group('horários de jogos que ainda vão começar', () {
      // Em Brasília, dois jogos de madrugada e um à noite do mesmo dia.
      final madrugada = jogoAs('a', DateTime.utc(2026, 11, 5, 3)); // 0h
      final madrugada2 = jogoAs('b', DateTime.utc(2026, 11, 5, 3, 30)); // 0h30
      final noite = jogoAs('c', DateTime.utc(2026, 11, 6, 2)); // 23h
      final doDia = [madrugada, madrugada2, noite];
      final dia5 = diaDeBrasilia(2026, 11, 5);
      final filtroDoDia = FiltroJogos(periodo: (inicio: dia5, fim: dia5));

      test('deixa de fora os que já começaram', () {
        final meioDia = DateTime.utc(2026, 11, 5, 15);
        final opcoes = OpcoesFiltro.de(doDia, filtroDoDia, agora: meioDia);
        expect(opcoes.horarios, ['23h']);
      });

      test('os jogos que já aconteceram continuam na lista', () {
        expect(filtroDoDia.aplicar(doDia), hasLength(3));
      });

      test('o jogo que começa agora já não conta', () {
        final opcoes = OpcoesFiltro.de(
          doDia,
          filtroDoDia,
          agora: noite.dataHora,
        );
        expect(opcoes.horarios, isEmpty);
      });

      test('vale também sem período escolhido', () {
        final opcoes = OpcoesFiltro.de(
          doDia,
          const FiltroJogos(),
          agora: DateTime.utc(2026, 11, 5, 3, 15),
        );
        expect(opcoes.horarios, ['23h', '0h30']);
      });

      test('período todo no passado mostra todos os horários', () {
        final opcoes = OpcoesFiltro.de(
          doDia,
          filtroDoDia,
          agora: DateTime.utc(2026, 11, 6, 15), // 06/11 ao meio-dia
        );
        expect(opcoes.horarios, ['23h', '0h', '0h30']);
      });

      test('período que termina hoje só mostra o que vai começar', () {
        final opcoes = OpcoesFiltro.de(
          doDia,
          FiltroJogos(periodo: (inicio: diaDeBrasilia(2026, 11, 1), fim: dia5)),
          agora: DateTime.utc(2026, 11, 5, 15),
        );
        expect(opcoes.horarios, ['23h']);
      });

      test('horário marcado que já passou continua para ser desmarcado', () {
        final opcoes = OpcoesFiltro.de(
          doDia,
          const FiltroJogos(horarios: {'0h'}),
          agora: DateTime.utc(2026, 11, 5, 15),
        );
        expect(opcoes.horarios, ['23h', '0h']);
      });
    });

    test('item marcado continua na lista mesmo sem jogos', () {
      final opcoes = OpcoesFiltro.de(
        jogos.take(1).toList(), // BOS x LAL às 21h30
        const FiltroJogos(horarios: {'0h'}, times: {'Miami Heat'}),
        agora: agora,
      );
      expect(opcoes.horarios, ['21h30', '0h']);
      expect(opcoes.times.map((t) => t.nome), [
        'Boston Celtics',
        'Los Angeles Lakers',
        'Miami Heat',
      ]);
    });
  });
}
