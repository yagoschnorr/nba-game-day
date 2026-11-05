import 'package:flutter/material.dart';

import '../app.dart' show rotaJogo;
import '../data/busca_jogos.dart';
import '../data/jogos_repository.dart';
import '../models/jogo.dart';
import '../tema.dart';
import '../utils/datas.dart';
import '../widgets/demo_sheet.dart';
import '../widgets/filtros_jogos.dart';
import '../widgets/jogo_card.dart';
import '../widgets/titulo_app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final JogosRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<void> _carregamento = widget.repository.carregar();
  late final _busca = BuscaJogos(widget.repository);
  final _campoBusca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    _campoBusca.dispose();
    super.dispose();
  }

  void _limparFiltros() {
    _campoBusca.clear();
    _busca.limpar();
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const TituloApp(),
        actions: [
          IconButton(
            icon: Icon(
              escuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: escuro ? 'Usar modo claro' : 'Usar modo escuro',
            onPressed: alternarTema,
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined),
            tooltip: 'Painel de demonstração',
            onPressed: () => mostrarDemoSheet(context, widget.repository),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _carregamento,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListenableBuilder(
            listenable: _busca,
            builder: (context, _) => _conteudo(context),
          );
        },
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final filtro = _busca.filtro;
    final jogos = _busca.resultado;
    return Column(
      children: [
        BarraBusca(
          controller: _campoBusca,
          selecoes: filtro.selecoes,
          onBuscar: (texto) =>
              _busca.atualizar((atual) => atual.copiarCom(texto: texto)),
          onAbrirFiltros: () => mostrarFiltrosSheet(
            context,
            busca: _busca,
            agora: widget.repository.agora(),
          ),
        ),
        if (filtro.ativo)
          _ResumoFiltro(
            quantidade: _busca.carregando ? null : jogos.length,
            onLimpar: _limparFiltros,
          ),
        Expanded(
          child: RefreshIndicator(
            color: CoresNba.vermelho,
            onRefresh: _busca.recarregar,
            child: _ListaPorDia(
              jogos: jogos,
              aviso: _textoAviso(_busca, widget.repository),
              carregando: _busca.carregando,
              semResultados: !_busca.periodoFalhou,
            ),
          ),
        ),
      ],
    );
  }

  /// Aviso exibido no topo quando o período não carregou inteiro ou a lista
  /// é de dados de demonstração.
  static String? _textoAviso(BuscaJogos busca, JogosRepository repository) {
    if (busca.periodoFalhou) {
      return 'Não foi possível buscar os jogos desse período. Puxe para '
          'tentar de novo.';
    }
    if (busca.diasComFalha > 0) {
      return 'Alguns dias não carregaram e podem faltar jogos. Puxe para '
          'tentar de novo.';
    }
    if (busca.usaConsultaDePeriodo || repository.fonte != FonteDados.mock) {
      return null;
    }
    return switch (repository.motivoFallback) {
      JogosRepository.motivoSemConexao =>
        'Sem conexão com a ESPN — exibindo dados de demonstração',
      JogosRepository.motivoSemJogos =>
        'Sem jogos nos próximos dias — exibindo dados de demonstração',
      _ => 'Modo demonstração — exibindo dados de demonstração',
    };
  }
}

/// Lista com um cabeçalho por dia (data de Brasília): "Hoje", "Amanhã", ...
class _ListaPorDia extends StatelessWidget {
  const _ListaPorDia({
    required this.jogos,
    this.aviso,
    this.carregando = false,
    this.semResultados = true,
  });

  final List<Jogo> jogos;
  final String? aviso;
  final bool carregando;

  /// Mostra "Nenhum jogo encontrado" se a lista estiver vazia. Fica `false`
  /// quando a busca falhou: não dá para afirmar que não há jogos.
  final bool semResultados;

  @override
  Widget build(BuildContext context) {
    final itens = <Widget>[
      if (aviso != null) _AvisoFallback(texto: aviso!),
      if (carregando)
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (jogos.isEmpty && semResultados)
        const _SemResultados(),
    ];
    DateTime? diaAtual;
    for (final jogo in carregando ? const <Jogo>[] : jogos) {
      final dia = apenasDia(jogo.dataHora);
      if (dia != diaAtual) {
        diaAtual = dia;
        itens.add(_CabecalhoDia(texto: formatarDia(jogo.dataHora)));
      }
      itens.add(
        JogoCard(
          jogo: jogo,
          // Mesma rota e mesmo argumento que a notificação do Desafio 3 usa.
          onTap: () =>
              Navigator.of(context).pushNamed(rotaJogo, arguments: jogo.id),
        ),
      );
    }

    return ListView(
      // Permite puxar para atualizar mesmo com poucos itens na tela.
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 16),
      children: itens,
    );
  }
}

/// Quantos jogos sobraram e o atalho para tirar a busca e os filtros.
class _ResumoFiltro extends StatelessWidget {
  const _ResumoFiltro({required this.quantidade, required this.onLimpar});

  /// `null` enquanto os jogos são buscados.
  final int? quantidade;
  final VoidCallback onLimpar;

  String get _texto => switch (quantidade) {
    null => 'Buscando jogos...',
    0 => 'Nenhum jogo',
    1 => '1 jogo',
    final total => '$total jogos',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _texto,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(onPressed: onLimpar, child: const Text('Limpar')),
        ],
      ),
    );
  }
}

class _SemResultados extends StatelessWidget {
  const _SemResultados();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: tema.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Nenhum jogo encontrado', style: tema.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Tente outro time, dia ou horário.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AvisoFallback extends StatelessWidget {
  const _AvisoFallback({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: cores.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: cores.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cores.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CabecalhoDia extends StatelessWidget {
  const _CabecalhoDia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: CoresNba.vermelho),
          const SizedBox(width: 8),
          Text(
            texto,
            style: tema.textTheme.titleSmall?.copyWith(
              color: tema.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
