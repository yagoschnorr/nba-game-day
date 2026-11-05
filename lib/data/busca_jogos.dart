import 'package:flutter/foundation.dart';

import '../models/filtro_jogos.dart';
import '../models/jogo.dart';
import '../utils/datas.dart';
import 'jogos_repository.dart';

/// Estado da busca da Home: os filtros e os jogos do período escolhido.
///
/// Períodos dentro da lista já carregada não consultam a ESPN. Os outros são
/// buscados aqui, sem mexer na lista padrão, que continua sendo a usada pelo
/// painel de demonstração.
class BuscaJogos extends ChangeNotifier {
  BuscaJogos(this._repository);

  /// Maior período aceito. Cada dia é uma requisição, porque a ESPN não
  /// aceita intervalo de datas.
  static const maxDias = 31;

  final JogosRepository _repository;

  FiltroJogos _filtro = const FiltroJogos();
  List<Jogo>? _jogosConsultados;
  bool _carregando = false;
  int _diasComFalha = 0;
  bool _periodoFalhou = false;

  /// Identifica a consulta mais recente, para descartar as respostas das
  /// anteriores: quem troca de período rápido não pode ver o período antigo.
  int _consultaAtual = 0;

  FiltroJogos get filtro => _filtro;

  /// Está buscando o período na ESPN.
  bool get carregando => _carregando;

  /// Nenhum dia do período respondeu.
  bool get periodoFalhou => _periodoFalhou;

  /// Dias do período que não responderam, quando parte deles respondeu.
  int get diasComFalha => _diasComFalha;

  /// Os jogos exibidos vieram de uma consulta por período, e não da lista
  /// padrão.
  bool get usaConsultaDePeriodo => _jogosConsultados != null;

  /// Jogos do período, antes dos outros filtros. É daqui que o painel tira
  /// as opções de horário e de time.
  List<Jogo> get jogosDoPeriodo =>
      FiltroJogos(periodo: _filtro.periodo)
          .aplicar(_jogosConsultados ?? _repository.jogos);

  /// Jogos que passam em todos os filtros.
  List<Jogo> get resultado => _filtro.aplicar(jogosDoPeriodo);

  /// Troca busca e filtros, mantendo o período.
  void atualizar(FiltroJogos Function(FiltroJogos atual) mudanca) {
    _filtro = mudanca(_filtro);
    notifyListeners();
  }

  Future<void> escolherPeriodo(Periodo? periodo) {
    _filtro = _filtro.comPeriodo(periodo);
    return _consultarPeriodo();
  }

  /// Tira todos os filtros marcados no painel, mantendo o texto da busca.
  Future<void> limparSelecoes() {
    _filtro = FiltroJogos(texto: _filtro.texto);
    return _consultarPeriodo();
  }

  /// Tira a busca e todos os filtros.
  Future<void> limpar() {
    _filtro = const FiltroJogos();
    return _consultarPeriodo();
  }

  /// Puxar para atualizar: busca de novo a lista padrão e o período.
  Future<void> recarregar() async {
    await _repository.recarregar();
    await _consultarPeriodo();
  }

  Future<void> _consultarPeriodo() async {
    final consulta = ++_consultaAtual;
    final periodo = _filtro.periodo;
    _jogosConsultados = null;
    _diasComFalha = 0;
    _periodoFalhou = false;

    if (periodo == null || _repository.cobre(periodo)) {
      _carregando = false;
      notifyListeners();
      return;
    }

    _carregando = true;
    notifyListeners();

    final resposta = await _repository.buscarPeriodo(periodo);
    if (consulta != _consultaAtual) return;

    _carregando = false;
    _jogosConsultados = resposta.jogos;
    _periodoFalhou =
        resposta.consultas > 0 && resposta.falhas == resposta.consultas;
    _diasComFalha = _periodoFalhou ? 0 : resposta.falhas;
    notifyListeners();
  }

  @override
  void dispose() {
    _consultaAtual++;
    super.dispose();
  }
}
