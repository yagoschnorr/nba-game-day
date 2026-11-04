import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nba_game_day/data/espn_api.dart';
import 'package:nba_game_day/models/jogo.dart';

// Fixtures reais (ver docs/espn_formato.md):
//   espn_scoreboard.json            dates=20261102, 15 jogos encerrados
//   espn_scoreboard_agendados.json  dates=20261104, 14 jogos agendados
//   espn_scoreboard_vazio.json      dates=20261103, sem jogos
String lerFixture(String nome) =>
    File('test/fixtures/$nome').readAsStringSync();

Map<String, dynamic> jsonFixture(String nome) =>
    jsonDecode(lerFixture(nome)) as Map<String, dynamic>;

Jogo porId(List<Jogo> jogos, String id) => jogos.singleWhere((j) => j.id == id);

/// Os exemplos "calculados à mão" assumem o horário de Brasília (UTC−3).
final foraDeBrasilia =
    DateTime(2026, 11, 3).timeZoneOffset != const Duration(hours: -3);

void main() {
  group('jogos encerrados (espn_scoreboard.json)', () {
    final jogos = parseScoreboard(jsonFixture('espn_scoreboard.json'));

    test('lê os 15 jogos, com ids únicos', () {
      expect(jogos, hasLength(15));
      expect(jogos.map((j) => j.id).toSet(), hasLength(15));
    });

    test('preenche todos os campos de OKC @ CLE', () {
      final jogo = porId(jogos, '401909907');
      expect(jogo.mandante, 'Cleveland Cavaliers');
      expect(jogo.visitante, 'Oklahoma City Thunder');
      expect(jogo.siglaMandante, 'CLE');
      expect(jogo.siglaVisitante, 'OKC');
      expect(jogo.arena, 'Rocket Arena');
      expect(jogo.cidade, 'Cleveland');
      expect(jogo.status, 'Encerrado');
      expect(jogo.placarMandante, 112);
      expect(jogo.placarVisitante, 117);
      expect(jogo.corMandante, '#860038');
      expect(jogo.corVisitante, '#007AC1');
      expect(
        jogo.logoMandante,
        'https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/cle.png',
      );
      expect(
        jogo.logoVisitante,
        'https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/okc.png',
      );
      expect(jogo.previa, isNull);
      expect(jogo.destaque, isFalse);
    });

    test('guarda a data em horário local, representando o instante UTC', () {
      final jogo = porId(jogos, '401909907'); // "2026-11-03T00:00Z"
      expect(jogo.dataHora.isUtc, isFalse);
      expect(jogo.dataHora.toUtc(), DateTime.utc(2026, 11, 3, 0, 0));
    });

    test('converte para Brasília conforme a conta feita à mão', () {
      // OKC @ CLE: 2026-11-03T00:00Z − 3 h = 02/11 às 21h.
      final okc = porId(jogos, '401909907').dataHora;
      expect([okc.day, okc.month, okc.hour, okc.minute], [2, 11, 21, 0]);

      // MIA @ LAL: 2026-11-03T03:00Z − 3 h = 03/11 à 0h. É do dia
      // americano 02/11, mas no Brasil cai na madrugada do dia seguinte.
      final mia = porId(jogos, '401909921').dataHora;
      expect([mia.day, mia.month, mia.hour, mia.minute], [3, 11, 0, 0]);
    }, skip: foraDeBrasilia ? 'a máquina não está no fuso de Brasília' : false);
  });

  group('jogos agendados (espn_scoreboard_agendados.json)', () {
    final jogos = parseScoreboard(
      jsonFixture('espn_scoreboard_agendados.json'),
    );

    test('lê os 14 jogos como "Agendado" e sem placar', () {
      expect(jogos, hasLength(14));
      for (final jogo in jogos) {
        expect(jogo.status, 'Agendado');
        // A API manda "0" nos agendados; não pode virar placar 0 x 0.
        expect(jogo.placarMandante, isNull);
        expect(jogo.placarVisitante, isNull);
      }
    });

    test('troca a cor do visitante quando os dois times têm a mesma', () {
      final jogo = porId(jogos, '401909922'); // PHI @ DET, ambos 1d428a
      expect(jogo.corMandante, '#1D428A');
      expect(jogo.corVisitante, '#E01234'); // alternateColor do PHI
    });
  });

  test('dia sem jogos (espn_scoreboard_vazio.json) devolve lista vazia', () {
    expect(parseScoreboard(jsonFixture('espn_scoreboard_vazio.json')), isEmpty);
  });

  group('parser defensivo', () {
    test('descarta só os eventos sem campo essencial', () {
      final json = jsonFixture('espn_scoreboard.json');
      final eventos = json['events'] as List<dynamic>;

      (eventos[0] as Map).remove('id');
      (eventos[1] as Map)['date'] = 'data inválida';
      final competidores =
          ((eventos[2] as Map)['competitions'] as List).first['competitors']
              as List;
      competidores.removeWhere((c) => c['homeAway'] == 'home');
      eventos.add('não é um evento');

      final jogos = parseScoreboard(json);
      expect(jogos, hasLength(12));
      expect(
        jogos.map((j) => j.id),
        isNot(contains(anyOf('401909908', '401909909'))),
      );
    });

    test('campos opcionais ausentes viram null ou texto vazio', () {
      final json = jsonFixture('espn_scoreboard.json');
      final evento = (json['events'] as List).first as Map<String, dynamic>;
      final comp = (evento['competitions'] as List).first as Map;
      comp.remove('venue');
      for (final c in comp['competitors'] as List) {
        c.remove('score');
        (c['team'] as Map)
          ..remove('abbreviation')
          ..remove('color')
          ..remove('logo');
      }

      final jogo = porId(parseScoreboard(json), evento['id'] as String);
      expect(jogo.mandante, 'Cleveland Cavaliers');
      expect(jogo.siglaMandante, isNull);
      expect(jogo.siglaVisitante, isNull);
      expect(jogo.corMandante, isNull);
      expect(jogo.corVisitante, isNull);
      expect(jogo.logoMandante, isNull);
      expect(jogo.logoVisitante, isNull);
      expect(jogo.placarMandante, isNull);
      expect(jogo.placarVisitante, isNull);
      expect(jogo.arena, '');
      expect(jogo.cidade, '');
    });

    test('aceita logo só em https na CDN da ESPN', () {
      String? logoCom(String url) {
        final json = jsonFixture('espn_scoreboard.json');
        final evento = (json['events'] as List).first as Map<String, dynamic>;
        final comp = (evento['competitions'] as List).first as Map;
        for (final c in comp['competitors'] as List) {
          (c['team'] as Map)['logo'] = url;
        }
        return porId(
          parseScoreboard(json),
          evento['id'] as String,
        ).logoMandante;
      }

      const valida = 'https://a.espncdn.com/i/teamlogos/nba/500/cle.png';
      expect(logoCom(valida), valida);
      expect(logoCom('http://a.espncdn.com/cle.png'), isNull);
      expect(logoCom('https://exemplo.com/cle.png'), isNull);
      expect(logoCom('https://espncdn.com.exemplo.com/cle.png'), isNull);
      expect(logoCom('https://falsoespncdn.com/cle.png'), isNull);
    });

    test('estrutura inesperada lança FormatException', () {
      expect(() => parseScoreboard({'foo': 1}), throwsFormatException);
      expect(() => parseScoreboard([1, 2]), throwsFormatException);
      expect(() => parseScoreboard(null), throwsFormatException);
    });
  });

  group('EspnApi', () {
    test('monta a URL com a data no formato AAAAMMDD', () {
      expect(
        EspnApi.urlDoDia(DateTime(2026, 11, 4)).toString(),
        endsWith('/basketball/nba/scoreboard?dates=20261104'),
      );
    });

    test('consulta de ontem até depois de amanhã', () {
      final dias = EspnApi.diasParaConsultar(DateTime(2026, 11, 1, 22, 15));
      expect(dias, [
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
      ]);
    });

    test('uma falha não derruba os outros dias', () async {
      final cliente = MockClient((requisicao) async {
        return switch (requisicao.url.queryParameters['dates']) {
          '20261102' => http.Response.bytes(
            utf8.encode(lerFixture('espn_scoreboard.json')),
            200,
          ),
          '20261103' => http.Response('erro', 500),
          '20261104' => http.Response('<html>não é JSON</html>', 200),
          _ => throw const SocketException('sem rede'),
        };
      });

      final respostas = await EspnApi(client: cliente).buscarDias([
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 4),
        DateTime(2026, 11, 5),
      ]);

      expect(respostas.map((r) => r.sucesso), [true, false, false, false]);
      expect(respostas.first.jogos, hasLength(15));
    });

    test('estoura o timeout e devolve falha', () async {
      final cliente = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{"events": []}', 200);
      });
      final api = EspnApi(
        client: cliente,
        timeout: const Duration(milliseconds: 20),
      );

      final respostas = await api.buscarDias([DateTime(2026, 11, 3)]);
      expect(respostas.single.sucesso, isFalse);
    });
  });
}
