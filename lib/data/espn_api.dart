import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/jogo.dart';
import '../utils/datas.dart';

/// Cliente da API pública (não oficial) do scoreboard da NBA na ESPN.
/// Os caminhos de chave usados aqui estão documentados em
/// docs/espn_formato.md.
class EspnApi {
  EspnApi({http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _base =
      'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard';

  /// URL do scoreboard de um dia (dia americano), no formato AAAAMMDD.
  static Uri urlDoDia(DateTime dia) {
    final aaaammdd =
        '${dia.year.toString().padLeft(4, '0')}'
        '${dia.month.toString().padLeft(2, '0')}'
        '${dia.day.toString().padLeft(2, '0')}';
    return Uri.parse('$_base?dates=$aaaammdd');
  }

  /// Dias consultados: de ontem até depois de amanhã. "Ontem" entra porque
  /// jogos tarde nos EUA caem na madrugada do dia seguinte no Brasil.
  static List<DateTime> diasParaConsultar(DateTime agora) {
    final hoje = emBrasilia(agora);
    return [
      for (var i = -1; i <= 2; i++)
        DateTime(hoje.year, hoje.month, hoje.day + i),
    ];
  }

  /// Dias americanos que cobrem [periodo]: do dia anterior ao início até o
  /// fim, porque o jogo da madrugada no Brasil é do dia anterior nos EUA.
  static List<DateTime> diasDoPeriodo(Periodo periodo) {
    final inicio = emBrasilia(periodo.inicio);
    final duracao = periodo.fim.difference(periodo.inicio).inDays;
    return [
      for (var i = -1; i <= duracao; i++)
        DateTime(inicio.year, inicio.month, inicio.day + i),
    ];
  }

  /// Busca os [dias] em paralelo. Cada dia vira um [RespostaDia]; uma falha
  /// (exceção, timeout, status ≠ 200 ou JSON inválido) não derruba os outros.
  Future<List<RespostaDia>> buscarDias(List<DateTime> dias) =>
      Future.wait(dias.map(_buscarDia));

  Future<RespostaDia> _buscarDia(DateTime dia) async {
    try {
      final resposta = await _client.get(urlDoDia(dia)).timeout(timeout);
      if (resposta.statusCode != 200) {
        return RespostaDia.falha(dia, 'HTTP ${resposta.statusCode}');
      }
      final json = jsonDecode(utf8.decode(resposta.bodyBytes));
      return RespostaDia.sucesso(dia, parseScoreboard(json));
    } catch (erro) {
      return RespostaDia.falha(dia, erro);
    }
  }
}

/// Resultado da consulta de um dia: os jogos, ou o erro que impediu obtê-los.
class RespostaDia {
  RespostaDia.sucesso(this.dia, List<Jogo> this.jogos) : erro = null;
  RespostaDia.falha(this.dia, Object this.erro) : jogos = null;

  final DateTime dia;
  final List<Jogo>? jogos;
  final Object? erro;

  bool get sucesso => jogos != null;
}

/// Converte a resposta do scoreboard em jogos.
///
/// Lança [FormatException] se a estrutura geral não for a esperada (não há
/// lista `events`). Eventos individuais sem os campos essenciais (id, data
/// e os dois times) são descartados sem afetar os demais.
List<Jogo> parseScoreboard(Object? json) {
  final eventos = _mapa(json)?['events'];
  if (eventos is! List) {
    throw const FormatException('Resposta da ESPN sem a lista "events".');
  }
  final jogos = <Jogo>[];
  for (final evento in eventos) {
    final jogo = _parseEvento(evento);
    if (jogo != null) jogos.add(jogo);
  }
  return jogos;
}

Jogo? _parseEvento(Object? dado) {
  final evento = _mapa(dado);
  if (evento == null) return null;

  final id = _texto(evento['id']);
  final dataUtc = DateTime.tryParse(_texto(evento['date']) ?? '');
  final competicoes = evento['competitions'];
  final comp = competicoes is List && competicoes.isNotEmpty
      ? _mapa(competicoes.first)
      : null;
  if (id == null || dataUtc == null || comp == null) return null;

  final competidores = comp['competitors'];
  if (competidores is! List) return null;
  final mandante = _competidor(competidores, 'home');
  final visitante = _competidor(competidores, 'away');
  final timeMandante = _mapa(mandante?['team']);
  final timeVisitante = _mapa(visitante?['team']);
  final nomeMandante = _texto(timeMandante?['displayName']);
  final nomeVisitante = _texto(timeVisitante?['displayName']);
  if (nomeMandante == null || nomeVisitante == null) return null;

  final estado = _texto(_mapa(_mapa(comp['status'])?['type'])?['state']);
  // Jogos agendados trazem placar "0"; só vale depois que o jogo começa.
  final temPlacar = estado == 'in' || estado == 'post';
  final placarMandante = temPlacar ? _inteiro(mandante?['score']) : null;
  final placarVisitante = temPlacar ? _inteiro(visitante?['score']) : null;
  final placarCompleto = placarMandante != null && placarVisitante != null;

  final corMandante = _cor(timeMandante?['color']);
  var corVisitante = _cor(timeVisitante?['color']);
  if (corVisitante != null && corVisitante == corMandante) {
    // Times com a mesma cor deixariam o gradiente chapado.
    corVisitante = _cor(timeVisitante?['alternateColor']) ?? corVisitante;
  }

  final local = _mapa(comp['venue']);

  return Jogo(
    id: id,
    mandante: nomeMandante,
    visitante: nomeVisitante,
    siglaMandante: _texto(timeMandante?['abbreviation']),
    siglaVisitante: _texto(timeVisitante?['abbreviation']),
    dataHora: dataUtc,
    arena: _texto(local?['fullName']) ?? '',
    cidade: _texto(_mapa(local?['address'])?['city']) ?? '',
    status: switch (estado) {
      'in' => 'Ao vivo',
      'post' => 'Encerrado',
      _ => 'Agendado',
    },
    placarMandante: placarCompleto ? placarMandante : null,
    placarVisitante: placarCompleto ? placarVisitante : null,
    corMandante: corMandante,
    corVisitante: corVisitante,
    logoMandante: _url(timeMandante?['logo']),
    logoVisitante: _url(timeVisitante?['logo']),
  );
}

Map<String, dynamic>? _competidor(List<dynamic> competidores, String lado) {
  for (final item in competidores) {
    final competidor = _mapa(item);
    if (competidor?['homeAway'] == lado) return competidor;
  }
  return null;
}

Map<String, dynamic>? _mapa(Object? valor) =>
    valor is Map<String, dynamic> ? valor : null;

/// Texto não vazio, ou `null`.
String? _texto(Object? valor) =>
    valor is String && valor.trim().isNotEmpty ? valor.trim() : null;

int? _inteiro(Object? valor) => switch (valor) {
  int v => v,
  String v => int.tryParse(v),
  _ => null,
};

/// URL https da CDN da ESPN, ou `null`. Qualquer outro endereço é recusado,
/// para o app não baixar imagens de sites inesperados.
String? _url(Object? valor) {
  final texto = _texto(valor);
  final uri = texto == null ? null : Uri.tryParse(texto);
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  return host == 'espncdn.com' || host.endsWith('.espncdn.com') ? texto : null;
}

/// "860038" → "#860038"; `null` se não for um hex de 6 dígitos.
String? _cor(Object? valor) {
  final hex = _texto(valor)?.replaceFirst('#', '');
  if (hex == null || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return '#${hex.toUpperCase()}';
}
