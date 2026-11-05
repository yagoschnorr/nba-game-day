// Formatação de datas em português, sem o pacote intl.
//
// O app mostra tudo no horário de Brasília, qualquer que seja o fuso do
// aparelho (o emulador do Android, por exemplo, costuma ficar em UTC). Por
// isso, os campos de dia e hora de um instante só devem ser lidos depois de
// passar por [emBrasilia].

const _diasSemana = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Brasília fica em UTC−3 o ano todo: o Brasil não tem horário de verão
/// desde 2019.
const fusoBrasilia = Duration(hours: -3);

/// Cópia de [instante] cujos campos (`day`, `hour`...) são os de Brasília.
/// Serve só para ler esses campos: não representa mais o mesmo instante.
DateTime emBrasilia(DateTime instante) => instante.toUtc().add(fusoBrasilia);

/// Meia-noite em Brasília do dia informado.
DateTime diaDeBrasilia(int ano, int mes, int dia) =>
    DateTime.utc(ano, mes, dia).subtract(fusoBrasilia);

/// Meia-noite em Brasília do dia de [data], para comparar datas ignorando o
/// horário.
DateTime apenasDia(DateTime data) {
  final brasilia = emBrasilia(data);
  return diaDeBrasilia(brasilia.year, brasilia.month, brasilia.day);
}

/// Intervalo de dias de Brasília, incluindo [inicio] e [fim], que vêm de
/// [apenasDia] ou [diaDeBrasilia].
typedef Periodo = ({DateTime inicio, DateTime fim});

bool estaNoPeriodo(DateTime instante, Periodo periodo) {
  final dia = apenasDia(instante);
  return !dia.isBefore(periodo.inicio) && !dia.isAfter(periodo.fim);
}

/// "05/11", ou "05/11 a 20/11" quando há mais de um dia.
String formatarPeriodo(Periodo periodo) {
  String diaEMes(DateTime data) {
    final brasilia = emBrasilia(data);
    final dia = brasilia.day.toString().padLeft(2, '0');
    final mes = brasilia.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }

  return periodo.inicio == periodo.fim
      ? diaEMes(periodo.inicio)
      : '${diaEMes(periodo.inicio)} a ${diaEMes(periodo.fim)}';
}

/// "21h30", ou "23h" quando os minutos são zero.
String formatarHora(DateTime data) {
  final brasilia = emBrasilia(data);
  final minutos = brasilia.minute.toString().padLeft(2, '0');
  return brasilia.minute == 0
      ? '${brasilia.hour}h'
      : '${brasilia.hour}h$minutos';
}

/// "Hoje", "Amanhã", "Ontem" ou "Quinta, 5 de novembro".
String formatarDia(DateTime data, {DateTime? agora}) {
  final hoje = apenasDia(agora ?? DateTime.now());
  final diferenca = apenasDia(data).difference(hoje).inDays;
  if (diferenca == 0) return 'Hoje';
  if (diferenca == 1) return 'Amanhã';
  if (diferenca == -1) return 'Ontem';
  final brasilia = emBrasilia(data);
  return '${_diasSemana[brasilia.weekday - 1]}, ${brasilia.day} de '
      '${_meses[brasilia.month - 1]}';
}

/// "Hoje, 21h30" ou "Quinta, 5 de novembro, 21h30".
String formatarDiaEHora(DateTime data, {DateTime? agora}) =>
    '${formatarDia(data, agora: agora)}, ${formatarHora(data)}';
