import 'package:flutter/material.dart';

import '../app.dart' show rotaJogo;
import '../data/jogos_repository.dart';
import '../models/jogo.dart';
import '../tema.dart';
import '../utils/datas.dart';
import '../widgets/demo_sheet.dart';
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

  Future<void> _recarregar() async {
    await widget.repository.recarregar();
    if (mounted) setState(() {});
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
          return RefreshIndicator(
            color: CoresNba.vermelho,
            onRefresh: _recarregar,
            child: _ListaPorDia(
              jogos: widget.repository.jogos,
              aviso: _textoAviso(widget.repository),
            ),
          );
        },
      ),
    );
  }

  /// Aviso exibido no topo quando a lista é de dados de demonstração.
  static String? _textoAviso(JogosRepository repository) {
    if (repository.fonte != FonteDados.mock) return null;
    return switch (repository.motivoFallback) {
      JogosRepository.motivoSemConexao =>
        'Sem conexão com a ESPN — exibindo dados de demonstração',
      JogosRepository.motivoSemJogos =>
        'Sem jogos nos próximos dias — exibindo dados de demonstração',
      _ => 'Modo demonstração — exibindo dados de demonstração',
    };
  }
}

/// Lista com um cabeçalho por dia (data local): "Hoje", "Amanhã", ...
class _ListaPorDia extends StatelessWidget {
  const _ListaPorDia({required this.jogos, this.aviso});

  final List<Jogo> jogos;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final itens = <Widget>[if (aviso != null) _AvisoFallback(texto: aviso!)];
    DateTime? diaAtual;
    for (final jogo in jogos) {
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
      padding: const EdgeInsets.only(bottom: 16),
      children: itens,
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
