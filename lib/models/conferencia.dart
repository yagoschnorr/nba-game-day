import 'jogo.dart';

// A API do scoreboard não informa a conferência dos times. Estas listas foram
// conferidas com a classificação da ESPN e usam o mesmo nome de
// `team.displayName` (ver docs/espn_formato.md).
const _timesDoLeste = {
  'Atlanta Hawks',
  'Boston Celtics',
  'Brooklyn Nets',
  'Charlotte Hornets',
  'Chicago Bulls',
  'Cleveland Cavaliers',
  'Detroit Pistons',
  'Indiana Pacers',
  'Miami Heat',
  'Milwaukee Bucks',
  'New York Knicks',
  'Orlando Magic',
  'Philadelphia 76ers',
  'Toronto Raptors',
  'Washington Wizards',
};

const _timesDoOeste = {
  'Dallas Mavericks',
  'Denver Nuggets',
  'Golden State Warriors',
  'Houston Rockets',
  'LA Clippers',
  'Los Angeles Lakers',
  'Memphis Grizzlies',
  'Minnesota Timberwolves',
  'New Orleans Pelicans',
  'Oklahoma City Thunder',
  'Phoenix Suns',
  'Portland Trail Blazers',
  'Sacramento Kings',
  'San Antonio Spurs',
  'Utah Jazz',
};

/// Opções do filtro de conferência.
enum FiltroConferencia {
  /// Jogos com pelo menos um time do Leste.
  leste('Leste'),

  /// Jogos com pelo menos um time do Oeste.
  oeste('Oeste'),

  /// Só os confrontos entre um time de cada conferência.
  entreConferencias('Leste x Oeste');

  const FiltroConferencia(this.rotulo);

  final String rotulo;

  bool aceita(Jogo jogo) {
    final mandante = jogo.mandante;
    final visitante = jogo.visitante;
    return switch (this) {
      leste =>
        _timesDoLeste.contains(mandante) || _timesDoLeste.contains(visitante),
      oeste =>
        _timesDoOeste.contains(mandante) || _timesDoOeste.contains(visitante),
      entreConferencias =>
        (_timesDoLeste.contains(mandante) &&
                _timesDoOeste.contains(visitante)) ||
            (_timesDoOeste.contains(mandante) &&
                _timesDoLeste.contains(visitante)),
    };
  }
}
