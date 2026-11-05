import '../utils/datas.dart';
import 'conferencia.dart';
import 'jogo.dart';

/// Busca e filtros da Home. Um jogo precisa passar em todos os critérios;
/// dentro de um critério, basta combinar com um dos itens escolhidos.
class FiltroJogos {
  const FiltroJogos({
    this.texto = '',
    this.periodo,
    this.conferencias = const {},
    this.horarios = const {},
    this.times = const {},
  });

  /// Trecho do nome ou da sigla de um dos times.
  final String texto;

  /// Dias escolhidos; `null` mantém a lista padrão da Home.
  final Periodo? periodo;

  final Set<FiltroConferencia> conferencias;

  /// Horários de início em Brasília, como devolvidos por [formatarHora].
  final Set<String> horarios;

  /// Nomes dos times. Vale tanto como mandante quanto como visitante.
  final Set<String> times;

  /// Quantos itens estão marcados no painel de filtros.
  int get selecoes =>
      (periodo == null ? 0 : 1) +
      conferencias.length +
      horarios.length +
      times.length;

  bool get ativo => texto.trim().isNotEmpty || selecoes > 0;

  List<Jogo> aplicar(List<Jogo> jogos) => jogos.where(_aceita).toList();

  bool _aceita(Jogo jogo) =>
      _combinaComTexto(jogo) &&
      (periodo == null || estaNoPeriodo(jogo.dataHora, periodo!)) &&
      (conferencias.isEmpty || conferencias.any((c) => c.aceita(jogo))) &&
      (horarios.isEmpty || horarios.contains(formatarHora(jogo.dataHora))) &&
      (times.isEmpty ||
          times.contains(jogo.mandante) ||
          times.contains(jogo.visitante));

  bool _combinaComTexto(Jogo jogo) {
    final busca = texto.trim().toLowerCase();
    if (busca.isEmpty) return true;
    return [
      jogo.mandante,
      jogo.visitante,
      jogo.siglaMandante,
      jogo.siglaVisitante,
    ].any((nome) => nome?.toLowerCase().contains(busca) ?? false);
  }

  /// Cópia com os campos informados. O período muda por [comPeriodo], porque
  /// `null` aqui significaria "manter".
  FiltroJogos copiarCom({
    String? texto,
    Set<FiltroConferencia>? conferencias,
    Set<String>? horarios,
    Set<String>? times,
  }) => FiltroJogos(
    texto: texto ?? this.texto,
    periodo: periodo,
    conferencias: conferencias ?? this.conferencias,
    horarios: horarios ?? this.horarios,
    times: times ?? this.times,
  );

  FiltroJogos comPeriodo(Periodo? novo) => FiltroJogos(
    texto: texto,
    periodo: novo,
    conferencias: conferencias,
    horarios: horarios,
    times: times,
  );
}

/// Um time que aparece no painel de filtros.
typedef TimeFiltro = ({String nome, String? sigla, String? logo});

/// O que pode ser marcado no painel de filtros: o que existe em [jogos] e o
/// que já está marcado em `filtro`. Um item marcado continua na lista mesmo
/// se sumir dos jogos (ao trocar o período, por exemplo); senão, ele seguiria
/// filtrando sem que desse para desmarcá-lo.
///
/// Os horários são só os dos jogos que ainda vão começar: a lista continua
/// mostrando os que já aconteceram, mas filtrar por um horário que passou não
/// ajuda quem procura o que assistir. A exceção é o período todo no passado,
/// em que nada vai começar e os horários servem para consultar resultados.
class OpcoesFiltro {
  factory OpcoesFiltro.de(
    List<Jogo> jogos,
    FiltroJogos filtro, {
    required DateTime agora,
  }) {
    final periodo = filtro.periodo;
    final periodoPassado =
        periodo != null && periodo.fim.isBefore(apenasDia(agora));
    final horarios = <String>{...filtro.horarios};
    final times = <String, TimeFiltro>{
      for (final nome in filtro.times)
        nome: (nome: nome, sigla: null, logo: null),
    };
    for (final jogo in jogos) {
      if (periodoPassado || jogo.dataHora.isAfter(agora)) {
        horarios.add(formatarHora(jogo.dataHora));
      }
      times[jogo.mandante] = (
        nome: jogo.mandante,
        sigla: jogo.siglaMandante,
        logo: jogo.logoMandante,
      );
      times[jogo.visitante] = (
        nome: jogo.visitante,
        sigla: jogo.siglaVisitante,
        logo: jogo.logoVisitante,
      );
    }
    return OpcoesFiltro._(
      horarios: horarios.toList()
        ..sort((a, b) => _ordemNaNoite(a).compareTo(_ordemNaNoite(b))),
      times: times.values.toList()..sort((a, b) => a.nome.compareTo(b.nome)),
    );
  }

  const OpcoesFiltro._({required this.horarios, required this.times});

  final List<String> horarios;
  final List<TimeFiltro> times;

  /// Minutos de um horário como "21h30", com a madrugada depois das 23h59:
  /// para o torcedor, o jogo da 0h é o último da noite, não o primeiro do dia.
  static int _ordemNaNoite(String horario) {
    final partes = horario.split('h');
    final hora = int.parse(partes[0]);
    final minuto = partes[1].isEmpty ? 0 : int.parse(partes[1]);
    return (hora < 6 ? hora + 24 : hora) * 60 + minuto;
  }
}
