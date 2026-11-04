import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/jogos_repository.dart';
import '../models/jogo.dart';
import '../services/notification_service.dart';
import '../utils/datas.dart';

/// Abre o painel com as informações usadas para montar as notificações no
/// Firebase Console.
Future<void> mostrarDemoSheet(
  BuildContext context,
  JogosRepository repository,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DemoSheet(repository: repository),
);

class DemoSheet extends StatelessWidget {
  const DemoSheet({super.key, required this.repository});

  final JogosRepository repository;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => FutureBuilder<void>(
        future: repository.carregar(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Painel de demonstração',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _Titulo('Token FCM'),
              _TokenFcm(servico: notificationService),
              const SizedBox(height: 16),
              const _Titulo('Fonte de dados'),
              _FonteDados(repository: repository),
              const SizedBox(height: 16),
              const _Titulo('Jogos de hoje'),
              ..._jogosDeHoje(context),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _jogosDeHoje(BuildContext context) {
    final hoje = apenasDia(repository.agora());
    final jogos = repository.jogos
        .where((j) => apenasDia(j.dataHora) == hoje)
        .toList();
    if (jogos.isEmpty) {
      return const [
        Text(
          'Nenhum jogo hoje. Para testar a navegação, use um ID de '
          'demonstração: mock-1, mock-2 ou mock-3.',
        ),
      ];
    }
    return [for (final jogo in jogos) _LinhaJogo(jogo: jogo)];
  }
}

/// Token para colar em "Enviar mensagem de teste" no Firebase Console.
class _TokenFcm extends StatelessWidget {
  const _TokenFcm({required this.servico});

  final NotificationService servico;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: servico.token,
      builder: (context, token, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (token == null)
            const Text(
              'Token ainda não disponível. Confira a conexão e abra o '
              'painel de novo.',
            )
          else ...[
            SelectableText(
              token,
              style: tema.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: BotaoCopiar(texto: token, rotulo: 'Copiar'),
            ),
          ],
          ValueListenableBuilder<AuthorizationStatus?>(
            valueListenable: servico.permissao,
            builder: (context, permissao, _) => Text(
              'Notificações: ${_descreverPermissao(permissao)}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _descreverPermissao(AuthorizationStatus? status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => 'permitidas',
        AuthorizationStatus.denied =>
          'bloqueadas (libere nas configurações do Android)',
        _ => 'aguardando resposta',
      };
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        texto,
        style: tema.textTheme.titleSmall?.copyWith(
          color: tema.colorScheme.tertiary,
        ),
      ),
    );
  }
}

class _FonteDados extends StatelessWidget {
  const _FonteDados({required this.repository});

  final JogosRepository repository;

  @override
  Widget build(BuildContext context) {
    final ehEspn = repository.fonte == FonteDados.espn;
    final motivo = repository.motivoFallback;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ehEspn ? Icons.cloud_done_outlined : Icons.science_outlined,
      ),
      title: Text(ehEspn ? 'ESPN' : 'Dados de demonstração (mock)'),
      subtitle: ehEspn
          ? null
          : Text(
              motivo == null ? 'Forçado (FONTE_DADOS=mock)' : 'Motivo: $motivo',
            ),
    );
  }
}

class _LinhaJogo extends StatelessWidget {
  const _LinhaJogo({required this.jogo});

  final Jogo jogo;

  @override
  Widget build(BuildContext context) {
    final mandante = jogo.siglaMandante ?? jogo.mandante;
    final visitante = jogo.siglaVisitante ?? jogo.visitante;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$mandante x $visitante · ${formatarHora(jogo.dataHora)}'),
      subtitle: SelectableText(
        'ID: ${jogo.id}',
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      trailing: BotaoCopiar(texto: jogo.id, rotulo: 'Copiar ID'),
    );
  }
}

/// Copia [texto] para a área de transferência e confirma trocando o ícone
/// por alguns segundos (um SnackBar ficaria escondido atrás do painel).
class BotaoCopiar extends StatefulWidget {
  const BotaoCopiar({super.key, required this.texto, required this.rotulo});

  final String texto;
  final String rotulo;

  @override
  State<BotaoCopiar> createState() => _BotaoCopiarState();
}

class _BotaoCopiarState extends State<BotaoCopiar> {
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.texto));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _copiar,
      icon: Icon(_copiado ? Icons.check : Icons.copy, size: 18),
      label: Text(_copiado ? 'Copiado' : widget.rotulo),
    );
  }
}
