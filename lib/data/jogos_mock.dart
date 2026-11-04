import '../models/jogo.dart';

/// Logo do time na CDN da ESPN (mesmo endereço que a API devolve).
String _logo(String codigoEspn) =>
    'https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/$codigoEspn.png';

/// Dados de demonstração usados quando a ESPN não responde ou não há jogos.
///
/// As datas são relativas a [agora] (hoje, amanhã e depois de amanhã), para
/// que o fallback sempre pareça atual. Os horários são de Brasília.
List<Jogo> gerarJogosMock(DateTime agora) {
  DateTime em(int diasAFrente, int hora, int minuto) =>
      DateTime(agora.year, agora.month, agora.day + diasAFrente, hora, minuto);

  return [
    Jogo(
      id: 'mock-1',
      mandante: 'Boston Celtics',
      visitante: 'Los Angeles Lakers',
      siglaMandante: 'BOS',
      logoMandante: _logo('bos'),
      siglaVisitante: 'LAL',
      logoVisitante: _logo('lal'),
      dataHora: em(0, 21, 30),
      arena: 'TD Garden',
      cidade: 'Boston',
      status: 'Agendado',
      corMandante: '#007A33',
      corVisitante: '#552583',
      previa:
          'Clássico mais tradicional da liga, com duas das torcidas mais '
          'apaixonadas dos EUA.',
      destaque: true,
    ),
    Jogo(
      id: 'mock-2',
      mandante: 'New York Knicks',
      visitante: 'Miami Heat',
      siglaMandante: 'NYK',
      logoMandante: _logo('ny'),
      siglaVisitante: 'MIA',
      logoVisitante: _logo('mia'),
      dataHora: em(0, 21, 30),
      arena: 'Madison Square Garden',
      cidade: 'Nova York',
      status: 'Agendado',
      corMandante: '#006BB6',
      corVisitante: '#98002E',
      previa:
          'Rivalidade da Conferência Leste marcada por jogos físicos e '
          'defesas fortes.',
    ),
    Jogo(
      id: 'mock-3',
      mandante: 'Denver Nuggets',
      visitante: 'Oklahoma City Thunder',
      siglaMandante: 'DEN',
      logoMandante: _logo('den'),
      siglaVisitante: 'OKC',
      logoVisitante: _logo('okc'),
      dataHora: em(0, 23, 0),
      arena: 'Ball Arena',
      cidade: 'Denver',
      status: 'Agendado',
      corMandante: '#0E2240',
      corVisitante: '#007AC1',
      previa:
          'Duelo da Conferência Oeste na altitude de Denver, um dos '
          'ginásios mais difíceis para o visitante.',
    ),
    Jogo(
      id: 'mock-4',
      mandante: 'Milwaukee Bucks',
      visitante: 'Philadelphia 76ers',
      siglaMandante: 'MIL',
      logoMandante: _logo('mil'),
      siglaVisitante: 'PHI',
      logoVisitante: _logo('phi'),
      dataHora: em(1, 22, 0),
      arena: 'Fiserv Forum',
      cidade: 'Milwaukee',
      status: 'Agendado',
      corMandante: '#00471B',
      corVisitante: '#006BB6',
      previa:
          'Confronto do Leste entre duas franquias tradicionais, com '
          'histórico de séries de playoff.',
    ),
    Jogo(
      id: 'mock-5',
      mandante: 'Dallas Mavericks',
      visitante: 'San Antonio Spurs',
      siglaMandante: 'DAL',
      logoMandante: _logo('dal'),
      siglaVisitante: 'SAS',
      logoVisitante: _logo('sa'),
      dataHora: em(1, 22, 30),
      arena: 'American Airlines Center',
      cidade: 'Dallas',
      status: 'Agendado',
      corMandante: '#00538C',
      corVisitante: '#1D1D1B',
      previa: 'Clássico texano, uma das rivalidades regionais mais antigas da liga.',
    ),
    Jogo(
      id: 'mock-6',
      mandante: 'Atlanta Hawks',
      visitante: 'Chicago Bulls',
      siglaMandante: 'ATL',
      logoMandante: _logo('atl'),
      siglaVisitante: 'CHI',
      logoVisitante: _logo('chi'),
      dataHora: em(2, 21, 30),
      arena: 'State Farm Arena',
      cidade: 'Atlanta',
      status: 'Agendado',
      corMandante: '#E03A3E',
      corVisitante: '#CE1141',
      previa: 'Encontro entre duas franquias históricas da Conferência Leste.',
    ),
  ];
}
