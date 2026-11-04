import 'package:flutter/material.dart';

import '../models/jogo.dart';
import '../tema.dart';
import 'logo_time.dart';
import '../utils/datas.dart';

class JogoCard extends StatelessWidget {
  const JogoCard({super.key, required this.jogo, this.onTap});

  final Jogo jogo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    // A ESPN pode não trazer arena ou cidade; nesse caso a linha some.
    final local = [
      jogo.arena,
      jogo.cidade,
    ].where((t) => t.isNotEmpty).join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: jogo.destaque
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: CoresNba.vermelho, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatarHora(jogo.dataHora),
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _etiquetaStatus(jogo.status, cores),
                  if (jogo.destaque)
                    const _Etiqueta(
                      texto: '⭐ Jogo da Noite',
                      cor: CoresNba.vermelho,
                      corTexto: CoresNba.branco,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _LinhaTime(
                nome: jogo.mandante,
                placar: jogo.placarMandante,
                logo: jogo.logoMandante,
                sigla: jogo.siglaMandante,
              ),
              const SizedBox(height: 4),
              _LinhaTime(
                nome: jogo.visitante,
                placar: jogo.placarVisitante,
                logo: jogo.logoVisitante,
                sigla: jogo.siglaVisitante,
              ),
              if (local.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: cores.tertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        local,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: cores.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaTime extends StatelessWidget {
  const _LinhaTime({required this.nome, this.placar, this.logo, this.sigla});

  final String nome;
  final int? placar;
  final String? logo;
  final String? sigla;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estilo = tema.textTheme.bodyLarge;
    final escuro = tema.brightness == Brightness.dark;
    return Row(
      children: [
        // No escuro, o círculo branco mantém visíveis as logos pretas ou
        // azul-escuras, como no cabeçalho dos detalhes.
        if (escuro)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: CoresNba.branco,
              shape: BoxShape.circle,
            ),
            // Mesmo tamanho do tema claro: a imagem em cache é reaproveitada
            // e as logos não piscam ao trocar de tema.
            child: LogoTime(url: logo, sigla: sigla),
          )
        else
          LogoTime(url: logo, sigla: sigla),
        const SizedBox(width: 12),
        Expanded(child: Text(nome, style: estilo)),
        if (placar != null)
          Text('$placar', style: estilo?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Agendado em azul suave, ao vivo em vermelho e encerrado com a cor do
/// texto do tema (preto no claro, branco no escuro).
Widget _etiquetaStatus(String status, ColorScheme cores) => switch (status) {
  'Ao vivo' => _Etiqueta(
    texto: status,
    cor: CoresNba.vermelho,
    corTexto: CoresNba.branco,
  ),
  'Encerrado' => _Etiqueta(
    texto: status,
    cor: cores.onSurface,
    corTexto: cores.surface,
  ),
  _ => _Etiqueta(
    texto: status,
    cor: cores.primary.withValues(alpha: 0.16),
    corTexto: cores.primary,
  ),
};

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.texto,
    required this.cor,
    required this.corTexto,
  });

  final String texto;
  final Color cor;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: corTexto, fontWeight: FontWeight.w600),
      ),
    );
  }
}
