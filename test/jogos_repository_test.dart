import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nba_game_day/data/espn_api.dart';
import 'package:nba_game_day/data/jogos_repository.dart';
import 'package:nba_game_day/models/jogo.dart';
import 'package:nba_game_day/utils/datas.dart';

http.Response respostaFixture(String nome) => http.Response.bytes(
  utf8.encode(File('test/fixtures/$nome').readAsStringSync()),
  200,
);

/// Cliente falso que responde cada `dates=AAAAMMDD` com [porData]; datas não
/// listadas respondem [padrao]. Conta as requisições feitas.
class ClienteFalso {
  ClienteFalso(this.porData, {required this.padrao});

  final Map<String, http.Response Function()> porData;
  http.Response Function() padrao;
  int requisicoes = 0;

  late final client = MockClient((requisicao) async {
    requisicoes++;
    final data = requisicao.url.queryParameters['dates'];
    return (porData[data] ?? padrao)();
  });
}

http.Response semRede() => throw const SocketException('sem rede');
http.Response erro500() => http.Response('erro', 500);
http.Response vazio() => respostaFixture('espn_scoreboard_vazio.json');
http.Response encerrados() => respostaFixture('espn_scoreboard.json');

JogosRepository criarRepositorio(
  ClienteFalso cliente, {
  required DateTime agora,
  bool forcarMock = false,
}) => JogosRepository(
  api: EspnApi(client: cliente.client),
  agora: () => agora,
  forcarMock: forcarMock,
);

void main() {
  // Dias consultados com "agora" em 02/11: 01/11, 02/11, 03/11 e 04/11.
  final dia2 = DateTime.utc(2026, 11, 2, 18, 0);

  group('fonte dos dados', () {
    test('todas as requisições falham por rede → mock "sem conexão"', () async {
      final cliente = ClienteFalso({}, padrao: semRede);
      final repo = criarRepositorio(cliente, agora: dia2);

      await repo.carregar();

      expect(repo.fonte, FonteDados.mock);
      expect(repo.motivoFallback, JogosRepository.motivoSemConexao);
      expect(repo.jogos.map((j) => j.id), everyElement(startsWith('mock-')));
      expect(repo.jogos, hasLength(6));
      expect(cliente.requisicoes, 4);
    });

    test('todas respondem com erro HTTP → mock "sem conexão"', () async {
      final repo = criarRepositorio(
        ClienteFalso({}, padrao: erro500),
        agora: dia2,
      );
      await repo.carregar();
      expect(repo.fonte, FonteDados.mock);
      expect(repo.motivoFallback, JogosRepository.motivoSemConexao);
    });

    test('respondem, mas sem jogos → mock "sem jogos no período"', () async {
      final repo = criarRepositorio(
        ClienteFalso({}, padrao: vazio),
        agora: dia2,
      );
      await repo.carregar();
      expect(repo.fonte, FonteDados.mock);
      expect(repo.motivoFallback, JogosRepository.motivoSemJogos);
    });

    test('jogos só fora do período (hoje até hoje + 2) → mock', () async {
      // Todos os jogos da fixture são de 02 e 03/11; "hoje" é 10/11.
      final repo = criarRepositorio(
        ClienteFalso({}, padrao: encerrados),
        agora: DateTime.utc(2026, 11, 10, 15),
      );
      await repo.carregar();
      expect(repo.fonte, FonteDados.mock);
      expect(repo.motivoFallback, JogosRepository.motivoSemJogos);
    });

    test('falha parcial com jogos → ESPN, em ordem de horário', () async {
      final repo = criarRepositorio(
        ClienteFalso({'20261102': encerrados}, padrao: erro500),
        agora: dia2,
      );
      await repo.carregar();

      expect(repo.fonte, FonteDados.espn);
      expect(repo.motivoFallback, isNull);
      expect(repo.jogos, hasLength(15));
      final horarios = repo.jogos.map((j) => j.dataHora).toList();
      expect(horarios, [...horarios]..sort());
    });

    test('o mesmo jogo vindo em dois dias aparece uma vez só', () async {
      final repo = criarRepositorio(
        ClienteFalso({
          '20261102': encerrados,
          '20261103': encerrados,
        }, padrao: vazio),
        agora: dia2,
      );
      await repo.carregar();
      expect(repo.jogos, hasLength(15));
    });

    test(
      'jogo da madrugada do "ontem" americano entra como jogo de hoje',
      () async {
        // Hoje é 03/11. A requisição de "ontem" (20261102) traz 15 jogos:
        // 12 são de 02/11 em Brasília (ficam de fora) e 3 começam à 0h de
        // 03/11 (entram).
        final repo = criarRepositorio(
          ClienteFalso({'20261102': encerrados}, padrao: vazio),
          agora: DateTime.utc(2026, 11, 3, 15),
        );
        await repo.carregar();

        expect(repo.fonte, FonteDados.espn);
        expect(
          repo.jogos.map((j) => j.id),
          unorderedEquals(['401909919', '401909920', '401909921']),
        );
      },
    );

    test('"hoje" vira à meia-noite de Brasília, não à de UTC', () async {
      // 03/11 à 1h em UTC ainda é 02/11 às 22h em Brasília: os 12 jogos de
      // 02/11 são de hoje e os 3 da madrugada de 03/11 são de amanhã.
      final repo = criarRepositorio(
        ClienteFalso({'20261102': encerrados}, padrao: vazio),
        agora: DateTime.utc(2026, 11, 3, 1),
      );
      await repo.carregar();

      final dias = repo.jogos.map(
        (j) => formatarDia(j.dataHora, agora: repo.agora()),
      );
      expect(dias.where((d) => d == 'Hoje'), hasLength(12));
      expect(dias.where((d) => d == 'Amanhã'), hasLength(3));
    });

    test('os horários do mock são de Brasília', () async {
      final repo = criarRepositorio(
        ClienteFalso({}, padrao: semRede),
        // 03/11 à 1h em UTC ainda é 02/11 em Brasília.
        agora: DateTime.utc(2026, 11, 3, 1),
      );
      await repo.carregar();

      final primeiro = repo.jogos.first.dataHora;
      expect(formatarHora(primeiro), '21h30');
      expect(formatarDia(primeiro, agora: repo.agora()), 'Hoje');
      expect(primeiro, DateTime.utc(2026, 11, 3, 0, 30));
    });

    test('FONTE_DADOS=mock usa o mock sem consultar a ESPN', () async {
      final cliente = ClienteFalso({}, padrao: encerrados);
      final repo = criarRepositorio(cliente, agora: dia2, forcarMock: true);
      await repo.carregar();

      expect(repo.fonte, FonteDados.mock);
      expect(repo.motivoFallback, isNull);
      expect(cliente.requisicoes, 0);
    });
  });

  group('carregamento', () {
    test('carregar várias vezes faz uma única consulta', () async {
      final cliente = ClienteFalso({}, padrao: vazio);
      final repo = criarRepositorio(cliente, agora: dia2);

      await Future.wait([repo.carregar(), repo.carregar()]);
      await repo.carregar();

      expect(cliente.requisicoes, 4);
    });

    test('recarregar troca do mock para a ESPN quando a rede volta', () async {
      final cliente = ClienteFalso({}, padrao: semRede);
      final repo = criarRepositorio(cliente, agora: dia2);

      await repo.carregar();
      expect(repo.fonte, FonteDados.mock);

      cliente.padrao = encerrados;
      await repo.recarregar();

      expect(repo.fonte, FonteDados.espn);
      expect(repo.motivoFallback, isNull);
      expect(cliente.requisicoes, 8);
    });
  });

  group('buscarPorId', () {
    late JogosRepository repo;
    late ClienteFalso cliente;

    setUp(() {
      cliente = ClienteFalso({'20261102': encerrados}, padrao: vazio);
      repo = criarRepositorio(cliente, agora: dia2);
    });

    test('carrega antes de procurar (abertura pela notificação)', () async {
      expect(repo.carregado, isFalse);

      final jogo = await repo.buscarPorId('401909907');

      expect(cliente.requisicoes, 4);
      expect(jogo?.mandante, 'Cleveland Cavaliers');
    });

    test('acha "mock-3" mesmo com a fonte ESPN', () async {
      final jogo = await repo.buscarPorId('mock-3');

      expect(repo.fonte, FonteDados.espn);
      expect(jogo?.mandante, 'Denver Nuggets');
      expect(jogo?.visitante, 'Oklahoma City Thunder');
    });

    test('id inexistente devolve null', () async {
      expect(await repo.buscarPorId('999'), isNull);
      expect(await repo.buscarPorId('mock-99'), isNull);
    });
  });
}
