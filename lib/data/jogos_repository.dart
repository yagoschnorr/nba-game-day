import '../models/jogo.dart';
import '../utils/datas.dart';
import 'espn_api.dart';
import 'jogos_mock.dart';

/// `flutter run --dart-define=FONTE_DADOS=mock` força os dados de
/// demonstração (testes e demonstração do fallback no vídeo).
const _fonteDadosDefinida = String.fromEnvironment('FONTE_DADOS');

/// Resultado de [JogosRepository.buscarPeriodo].
typedef RespostaPeriodo = ({List<Jogo> jogos, int falhas, int consultas});

/// Ponto único de acesso aos jogos do app: decide entre ESPN e mock e guarda
/// o resultado em memória.
class JogosRepository {
  JogosRepository({
    EspnApi? api,
    DateTime Function()? agora,
    this.forcarMock = _fonteDadosDefinida == 'mock',
  }) : _api = api ?? EspnApi(),
       _agora = agora ?? DateTime.now;

  static const motivoSemConexao = 'sem conexão';
  static const motivoSemJogos = 'sem jogos no período';

  /// Quantos dias, a partir de hoje, entram na lista (hoje, amanhã e
  /// depois de amanhã).
  static const diasExibidos = 3;

  final EspnApi _api;
  final DateTime Function() _agora;

  /// Usa o mock direto, sem consultar a ESPN.
  final bool forcarMock;

  List<Jogo> _jogos = const [];
  List<Jogo> _jogosDoPeriodo = const [];
  Periodo? _diasCarregados;
  FonteDados? _fonte;
  String? _motivoFallback;
  Future<void>? _carregamento;

  /// Jogos em ordem de horário.
  List<Jogo> get jogos => _jogos;

  /// `null` enquanto ainda não carregou.
  FonteDados? get fonte => _fonte;

  /// [motivoSemConexao] ou [motivoSemJogos] quando caiu no mock; `null`
  /// quando os dados são da ESPN ou o mock foi forçado.
  String? get motivoFallback => _motivoFallback;

  bool get carregado => _fonte != null;

  /// Relógio usado pelo repositório (injetável nos testes).
  DateTime agora() => _agora();

  /// Carrega os jogos uma única vez; chamadas simultâneas esperam a mesma
  /// carga. Use [recarregar] para buscar de novo.
  Future<void> carregar() => _carregamento ??= _buscar();

  /// Busca de novo (pull-to-refresh).
  Future<void> recarregar() => _carregamento = _buscar();

  /// A lista padrão já traz todos os dias de [periodo].
  bool cobre(Periodo periodo) {
    final carregados = _diasCarregados;
    return carregados != null &&
        !periodo.inicio.isBefore(carregados.inicio) &&
        !periodo.fim.isAfter(carregados.fim);
  }

  /// Busca na ESPN os jogos de [periodo], filtrando pela data de Brasília. A
  /// lista padrão não muda. Falhas contam por dia consultado: quando só
  /// algumas ocorrem, os jogos dos outros dias vêm normalmente.
  Future<RespostaPeriodo> buscarPeriodo(Periodo periodo) async {
    if (forcarMock) return (jogos: const <Jogo>[], falhas: 0, consultas: 0);

    final respostas = await _api.buscarDias(EspnApi.diasDoPeriodo(periodo));
    final porId = <String, Jogo>{};
    for (final resposta in respostas) {
      for (final jogo in resposta.jogos ?? const <Jogo>[]) {
        if (estaNoPeriodo(jogo.dataHora, periodo)) porId[jogo.id] = jogo;
      }
    }
    _jogosDoPeriodo = _ordenados(porId.values);
    return (
      jogos: _jogosDoPeriodo,
      falhas: respostas.where((r) => !r.sucesso).length,
      consultas: respostas.length,
    );
  }

  /// Procura um jogo pelo ID, esperando o carregamento se ele ainda não
  /// aconteceu (caso do app aberto pelo toque na notificação).
  ///
  /// IDs "mock-*" também são procurados no mock com a ESPN ativa, para que
  /// uma notificação de teste com ID mock funcione sempre.
  Future<Jogo?> buscarPorId(String id) async {
    await carregar();
    // O card aberto pode ser de um período fora da lista padrão.
    for (final jogo in [..._jogos, ..._jogosDoPeriodo]) {
      if (jogo.id == id) return jogo;
    }
    if (id.startsWith('mock-')) {
      for (final jogo in gerarJogosMock(_agora())) {
        if (jogo.id == id) return jogo;
      }
    }
    return null;
  }

  Future<void> _buscar() async {
    final agora = _agora();
    final hoje = apenasDia(agora);
    final limite = hoje.add(const Duration(days: diasExibidos));
    _diasCarregados = (
      inicio: hoje,
      fim: limite.subtract(const Duration(days: 1)),
    );
    if (forcarMock) {
      _usarMock(agora, motivo: null);
      return;
    }

    final List<RespostaDia> respostas;
    try {
      respostas = await _api.buscarDias(EspnApi.diasParaConsultar(agora));
    } catch (_) {
      // buscarDias já trata as falhas de cada dia; isto é só uma rede de
      // segurança para o app nunca ficar sem dados.
      _usarMock(agora, motivo: motivoSemConexao);
      return;
    }

    if (!respostas.any((r) => r.sucesso)) {
      _usarMock(agora, motivo: motivoSemConexao);
      return;
    }

    // Filtra pela data de BRASÍLIA: um jogo do "ontem" americano pode cair
    // na madrugada de hoje no Brasil.
    final porId = <String, Jogo>{};
    for (final resposta in respostas) {
      for (final jogo in resposta.jogos ?? const <Jogo>[]) {
        final dia = apenasDia(jogo.dataHora);
        if (!dia.isBefore(hoje) && dia.isBefore(limite)) {
          porId[jogo.id] = jogo;
        }
      }
    }

    if (porId.isEmpty) {
      _usarMock(agora, motivo: motivoSemJogos);
      return;
    }

    _jogos = _ordenados(porId.values);
    _fonte = FonteDados.espn;
    _motivoFallback = null;
  }

  void _usarMock(DateTime agora, {required String? motivo}) {
    _jogos = _ordenados(gerarJogosMock(agora));
    _fonte = FonteDados.mock;
    _motivoFallback = motivo;
  }

  static List<Jogo> _ordenados(Iterable<Jogo> jogos) => List.unmodifiable(
    jogos.toList()..sort((a, b) => a.dataHora.compareTo(b.dataHora)),
  );
}
