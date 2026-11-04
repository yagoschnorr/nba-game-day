import 'package:flutter/material.dart';

import '../models/jogo.dart';
import '../tema.dart';
import 'logo_time.dart';

/// Cabeçalho visual do confronto: gradiente nas cores dos times, nomes e "x"
/// no centro. O banner da notificação do Desafio 2 (tools/gerar_banner.py)
/// segue este mesmo desenho.
class CabecalhoConfronto extends StatelessWidget {
  const CabecalhoConfronto({super.key, required this.jogo, this.quando});

  final Jogo jogo;

  /// Texto abaixo do confronto, ex.: "Hoje, 21h30".
  final String? quando;

  /// Quando a fonte não traz as cores dos times, usa o azul e o vermelho
  /// da NBA.
  static const corPadraoMandante = CoresNba.azul;
  static const corPadraoVisitante = CoresNba.vermelho;

  @override
  Widget build(BuildContext context) {
    final corMandante = corDeHex(jogo.corMandante) ?? corPadraoMandante;
    final corVisitante = corDeHex(jogo.corVisitante) ?? corPadraoVisitante;
    final textos = Theme.of(context).textTheme;
    const branco = CoresNba.branco;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [corMandante, corVisitante],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Time(
                  nome: jogo.mandante,
                  sigla: jogo.siglaMandante,
                  logo: jogo.logoMandante,
                  alinhamento: CrossAxisAlignment.start,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'x',
                  style: textos.headlineMedium?.copyWith(
                    color: branco,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Expanded(
                child: _Time(
                  nome: jogo.visitante,
                  sigla: jogo.siglaVisitante,
                  logo: jogo.logoVisitante,
                  alinhamento: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          if (quando != null) ...[
            const SizedBox(height: 16),
            Text(quando!, style: textos.titleMedium?.copyWith(color: branco)),
          ],
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({
    required this.nome,
    this.sigla,
    this.logo,
    required this.alinhamento,
  });

  final String nome;
  final String? sigla;
  final String? logo;
  final CrossAxisAlignment alinhamento;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final alinhamentoTexto = alinhamento == CrossAxisAlignment.start
        ? TextAlign.left
        : TextAlign.right;

    return Column(
      crossAxisAlignment: alinhamento,
      children: [
        if (logo != null) ...[
          // Fundo branco: muitas logos usam a própria cor do time e
          // sumiriam sobre o gradiente.
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: CoresNba.branco,
              shape: BoxShape.circle,
            ),
            // Sem sigla no substituto: ela já aparece grande logo abaixo.
            child: LogoTime(url: logo, tamanho: 48),
          ),
          const SizedBox(height: 8),
        ],
        if (sigla != null)
          Text(
            sigla!,
            style: textos.headlineLarge?.copyWith(
              color: CoresNba.branco,
              fontWeight: FontWeight.bold,
            ),
          ),
        Text(
          nome,
          textAlign: alinhamentoTexto,
          style: textos.titleSmall?.copyWith(color: CoresNba.branco),
        ),
      ],
    );
  }
}

/// Converte "#007A33" (ou "007A33") em [Color]; `null` se inválido.
Color? corDeHex(String? hex) {
  if (hex == null) return null;
  final limpo = hex.replaceFirst('#', '');
  if (limpo.length != 6) return null;
  final valor = int.tryParse(limpo, radix: 16);
  return valor == null ? null : Color(0xFF000000 | valor);
}
