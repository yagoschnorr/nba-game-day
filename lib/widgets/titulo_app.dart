import 'package:flutter/material.dart';

import '../tema.dart';

/// Título da Home: logo da NBA seguida de "GAME DAY".
///
/// Como as logos dos times, a logo vem da CDN da ESPN e não fica no
/// repositório. Sem conexão, aparece "NBA" escrito no lugar dela.
class TituloApp extends StatelessWidget {
  const TituloApp({super.key});

  static const _urlLogo =
      'https://a.espncdn.com/i/teamlogos/leagues/500/nba.png';
  static const _estilo = TextStyle(
    fontFamily: 'Anton',
    fontSize: 24,
    letterSpacing: 1,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NBA Game Day',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // O fundo branco separa a metade azul da logo da AppBar azul.
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: CoresNba.branco,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Image.network(
              _urlLogo,
              width: 22,
              height: 44,
              // A imagem é quadrada, com margens transparentes dos lados.
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'NBA',
                  style: _estilo.copyWith(color: CoresNba.azul),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('GAME DAY', style: _estilo),
        ],
      ),
    );
  }
}
