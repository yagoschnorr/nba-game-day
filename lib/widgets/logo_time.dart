import 'package:flutter/material.dart';

import '../tema.dart';

/// Logo de um time, carregada da CDN da ESPN quando o app roda (os arquivos
/// não ficam no repositório). Sem URL, sem conexão ou com erro no
/// download, mostra um círculo com a sigla.
class LogoTime extends StatelessWidget {
  const LogoTime({super.key, this.url, this.sigla, this.tamanho = 28});

  final String? url;
  final String? sigla;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final substituto = _Substituto(sigla: sigla, tamanho: tamanho);
    if (url == null) return substituto;

    // As logos da ESPN têm 500 px; decodificar no tamanho exibido economiza
    // memória.
    final pixels = (tamanho * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.network(
      url!,
      width: tamanho,
      height: tamanho,
      cacheWidth: pixels,
      fit: BoxFit.contain,
      semanticLabel: sigla == null ? 'Logo do time' : 'Logo $sigla',
      // Enquanto carrega, o substituto segura o espaço; depois a logo entra.
      frameBuilder: (context, child, frame, sincrono) =>
          sincrono || frame != null ? child : substituto,
      errorBuilder: (context, erro, pilha) => substituto,
    );
  }
}

class _Substituto extends StatelessWidget {
  const _Substituto({required this.sigla, required this.tamanho});

  final String? sigla;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CoresNba.azul.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: sigla == null
          ? Icon(
              Icons.sports_basketball,
              size: tamanho * 0.6,
              color: CoresNba.azul,
            )
          : FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  sigla!,
                  style: const TextStyle(
                    color: CoresNba.azul,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
    );
  }
}
