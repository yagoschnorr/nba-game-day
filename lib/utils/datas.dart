// Formatação de datas em português, sem o pacote intl.

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

/// Só o dia (meia-noite), para comparar datas ignorando o horário.
DateTime apenasDia(DateTime data) => DateTime(data.year, data.month, data.day);

/// "21h30", ou "23h" quando os minutos são zero.
String formatarHora(DateTime data) {
  final minutos = data.minute.toString().padLeft(2, '0');
  return data.minute == 0 ? '${data.hour}h' : '${data.hour}h$minutos';
}

/// "Hoje", "Amanhã", "Ontem" ou "Quinta, 5 de novembro".
String formatarDia(DateTime data, {DateTime? agora}) {
  final hoje = apenasDia(agora ?? DateTime.now());
  final diferenca = apenasDia(data).difference(hoje).inDays;
  if (diferenca == 0) return 'Hoje';
  if (diferenca == 1) return 'Amanhã';
  if (diferenca == -1) return 'Ontem';
  return '${_diasSemana[data.weekday - 1]}, ${data.day} de ${_meses[data.month - 1]}';
}

/// "Hoje, 21h30" ou "Quinta, 5 de novembro, 21h30".
String formatarDiaEHora(DateTime data, {DateTime? agora}) =>
    '${formatarDia(data, agora: agora)}, ${formatarHora(data)}';
