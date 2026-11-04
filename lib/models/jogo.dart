/// De onde vieram os jogos exibidos no app.
enum FonteDados { espn, mock }

class Jogo {
  /// ID do evento na ESPN, ou "mock-1" ... "mock-6" nos dados de demonstração.
  /// É String porque o Console do Firebase envia dados personalizados como texto.
  final String id;
  final String mandante;
  final String visitante;
  final String? siglaMandante;
  final String? siglaVisitante;

  /// Sempre em horário local do aparelho.
  final DateTime dataHora;
  final String arena;
  final String cidade;

  /// "Agendado", "Ao vivo" ou "Encerrado".
  final String status;
  final int? placarMandante;
  final int? placarVisitante;

  /// Cores em hexadecimal ("#007A33"), quando a fonte trouxer.
  final String? corMandante;
  final String? corVisitante;

  /// URL da logo de cada time na CDN da ESPN, quando houver.
  final String? logoMandante;
  final String? logoVisitante;

  /// Texto de prévia; só existe nos dados mock.
  final String? previa;

  /// "Jogo da Noite"; só nos dados mock.
  final bool destaque;

  const Jogo({
    required this.id,
    required this.mandante,
    required this.visitante,
    this.siglaMandante,
    this.siglaVisitante,
    required this.dataHora,
    required this.arena,
    required this.cidade,
    required this.status,
    this.placarMandante,
    this.placarVisitante,
    this.corMandante,
    this.corVisitante,
    this.logoMandante,
    this.logoVisitante,
    this.previa,
    this.destaque = false,
  });

  bool get temPlacar => placarMandante != null && placarVisitante != null;
}
