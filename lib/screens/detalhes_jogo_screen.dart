import 'package:flutter/material.dart';

import '../data/jogos_repository.dart';
import '../models/jogo.dart';
import '../utils/datas.dart';
import '../widgets/cabecalho_confronto.dart';

/// Detalhes de um jogo, aberta pelo card da Home ou pelo toque na
/// notificação (rota "/jogo", argumento: id do jogo).
class DetalhesJogoScreen extends StatefulWidget {
  const DetalhesJogoScreen({
    super.key,
    required this.id,
    required this.repository,
  });

  final String id;
  final JogosRepository repository;

  @override
  State<DetalhesJogoScreen> createState() => _DetalhesJogoScreenState();
}

class _DetalhesJogoScreenState extends State<DetalhesJogoScreen> {
  // Se o app foi aberto pela notificação, buscarPorId espera o carregamento.
  late final Future<Jogo?> _busca = widget.repository.buscarPorId(widget.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do jogo')),
      body: FutureBuilder<Jogo?>(
        future: _busca,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final jogo = snapshot.data;
          if (jogo == null) return const _JogoNaoEncontrado();
          return _Conteudo(jogo: jogo);
        },
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.jogo});

  final Jogo jogo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // Um jogo mock pode ser aberto mesmo com a ESPN ativa (jogo_id = mock-3),
    // por isso a fonte é decidida pelo próprio jogo.
    final ehMock = jogo.id.startsWith('mock-');

    return ListView(
      children: [
        CabecalhoConfronto(jogo: jogo, quando: formatarDiaEHora(jogo.dataHora)),
        if (jogo.temPlacar)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              '${jogo.placarMandante}  x  ${jogo.placarVisitante}',
              textAlign: TextAlign.center,
              style: tema.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _Info(
          icone: Icons.event,
          rotulo: 'Data e horário',
          valor: formatarDiaEHora(jogo.dataHora),
        ),
        if (jogo.arena.isNotEmpty)
          _Info(
            icone: Icons.stadium_outlined,
            rotulo: 'Arena',
            valor: jogo.arena,
          ),
        if (jogo.cidade.isNotEmpty)
          _Info(
            icone: Icons.place_outlined,
            rotulo: 'Cidade',
            valor: jogo.cidade,
          ),
        _Info(icone: Icons.info_outline, rotulo: 'Status', valor: jogo.status),
        if (jogo.previa != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prévia', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(jogo.previa!, style: tema.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            ehMock ? 'Dados de demonstração' : 'Dados: ESPN',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.rotulo, required this.valor});

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone),
      title: Text(valor),
      subtitle: Text(rotulo),
    );
  }
}

class _JogoNaoEncontrado extends StatelessWidget {
  const _JogoNaoEncontrado();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: tema.colorScheme.outline),
            const SizedBox(height: 16),
            Text('Jogo não encontrado', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Ele pode já ter saído da agenda ou o ID não existe.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((rota) => rota.isFirst),
              child: const Text('Voltar para o início'),
            ),
          ],
        ),
      ),
    );
  }
}
