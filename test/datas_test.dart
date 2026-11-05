import 'package:flutter_test/flutter_test.dart';
import 'package:nba_game_day/utils/datas.dart';

void main() {
  group('formatarHora', () {
    test('converte o instante UTC para Brasília', () {
      expect(formatarHora(DateTime.utc(2026, 11, 3, 0, 0)), '21h');
      expect(formatarHora(DateTime.utc(2026, 11, 3, 0, 30)), '21h30');
      expect(formatarHora(DateTime.utc(2026, 11, 3, 3, 5)), '0h05');
    });

    test('não depende de como o instante está representado', () {
      final instante = DateTime.utc(2026, 11, 3, 0, 30);
      expect(formatarHora(instante.toLocal()), formatarHora(instante));
    });
  });

  group('apenasDia', () {
    test('o dia vira à meia-noite de Brasília', () {
      expect(
        apenasDia(DateTime.utc(2026, 11, 3, 2, 59)),
        apenasDia(DateTime.utc(2026, 11, 2, 3, 0)),
      );
      expect(
        apenasDia(DateTime.utc(2026, 11, 3, 3, 0)),
        isNot(apenasDia(DateTime.utc(2026, 11, 3, 2, 59))),
      );
    });

    test('aplicar duas vezes não muda o dia', () {
      final dia = apenasDia(DateTime.utc(2026, 11, 3, 1));
      expect(apenasDia(dia), dia);
    });
  });

  group('formatarDia', () {
    // 22h de 02/11 em Brasília; em UTC já é 03/11.
    final agora = DateTime.utc(2026, 11, 3, 1);

    test('usa o dia de Brasília para hoje, amanhã e ontem', () {
      final hoje = DateTime.utc(2026, 11, 3, 2); // 02/11, 23h
      final amanha = DateTime.utc(2026, 11, 3, 3); // 03/11, 0h
      final ontem = DateTime.utc(2026, 11, 2, 2); // 01/11, 23h
      expect(formatarDia(hoje, agora: agora), 'Hoje');
      expect(formatarDia(amanha, agora: agora), 'Amanhã');
      expect(formatarDia(ontem, agora: agora), 'Ontem');
    });

    test('escreve a data de Brasília quando está mais longe', () {
      // Em UTC já seria sexta, 6 de novembro.
      final jogo = DateTime.utc(2026, 11, 6, 2);
      expect(formatarDia(jogo, agora: agora), 'Quinta, 5 de novembro');
    });
  });

  group('período', () {
    final dia5 = diaDeBrasilia(2026, 11, 5);
    final dia7 = diaDeBrasilia(2026, 11, 7);

    test('inclui o primeiro e o último dia inteiros, em Brasília', () {
      final periodo = (inicio: dia5, fim: dia7);
      expect(estaNoPeriodo(DateTime.utc(2026, 11, 5, 3), periodo), isTrue);
      expect(estaNoPeriodo(DateTime.utc(2026, 11, 8, 2, 59), periodo), isTrue);
      expect(estaNoPeriodo(DateTime.utc(2026, 11, 5, 2, 59), periodo), isFalse);
      expect(estaNoPeriodo(DateTime.utc(2026, 11, 8, 3), periodo), isFalse);
    });

    test('escreve um dia ou o intervalo', () {
      expect(formatarPeriodo((inicio: dia5, fim: dia5)), '05/11');
      expect(formatarPeriodo((inicio: dia5, fim: dia7)), '05/11 a 07/11');
    });
  });

  test('formatarDiaEHora junta o dia e a hora de Brasília', () {
    expect(
      formatarDiaEHora(
        DateTime.utc(2026, 11, 3, 3),
        agora: DateTime.utc(2026, 11, 3, 1),
      ),
      'Amanhã, 0h',
    );
  });
}
