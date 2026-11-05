import 'package:flutter/material.dart';

import '../data/busca_jogos.dart';
import '../models/conferencia.dart';
import '../models/filtro_jogos.dart';
import '../tema.dart';
import '../utils/datas.dart';
import 'logo_time.dart';

/// Campo de busca por time e botão que abre o painel de filtros.
class BarraBusca extends StatelessWidget {
  const BarraBusca({
    super.key,
    required this.controller,
    required this.selecoes,
    required this.onBuscar,
    required this.onAbrirFiltros,
  });

  final TextEditingController controller;

  /// Quantos filtros estão marcados; aparece no selo do botão.
  final int selecoes;
  final ValueChanged<String> onBuscar;
  final VoidCallback onAbrirFiltros;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onBuscar,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar time',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          controller.clear();
                          onBuscar('');
                        },
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Badge.count(
              count: selecoes,
              isLabelVisible: selecoes > 0,
              backgroundColor: CoresNba.vermelho,
              textColor: CoresNba.branco,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filtrar jogos',
            onPressed: onAbrirFiltros,
          ),
        ],
      ),
    );
  }
}

/// Abre o painel de filtros. As marcações valem na hora: a lista atrás do
/// painel e o botão "Ver jogos" acompanham [busca].
Future<void> mostrarFiltrosSheet(
  BuildContext context, {
  required BuscaJogos busca,
  required DateTime agora,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FiltrosSheet(busca: busca, agora: agora),
);

class _FiltrosSheet extends StatelessWidget {
  const _FiltrosSheet({required this.busca, required this.agora});

  final BuscaJogos busca;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListenableBuilder(
        listenable: busca,
        builder: (context, _) {
          final atual = busca.filtro;
          final opcoes = OpcoesFiltro.de(
            busca.jogosDoPeriodo,
            atual,
            agora: agora,
          );
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      'Filtrar jogos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _SecaoPeriodo(busca: busca, agora: agora),
                    _Secao(
                      titulo: 'Conferência',
                      chips: [
                        for (final opcao in FiltroConferencia.values)
                          FilterChip(
                            label: Text(opcao.rotulo),
                            selected: atual.conferencias.contains(opcao),
                            onSelected: (_) => busca.atualizar(
                              (f) => f.copiarCom(
                                conferencias: _alternado(f.conferencias, opcao),
                              ),
                            ),
                          ),
                      ],
                    ),
                    _Secao(
                      titulo: 'Horário (Brasília)',
                      vazio: 'Nenhum jogo por começar.',
                      chips: [
                        for (final horario in opcoes.horarios)
                          FilterChip(
                            label: Text(horario),
                            selected: atual.horarios.contains(horario),
                            onSelected: (_) => busca.atualizar(
                              (f) => f.copiarCom(
                                horarios: _alternado(f.horarios, horario),
                              ),
                            ),
                          ),
                      ],
                    ),
                    _Secao(
                      titulo: 'Times',
                      chips: [
                        for (final time in opcoes.times)
                          FilterChip(
                            avatar: _LogoChip(time: time),
                            showCheckmark: false,
                            label: Text(time.nome),
                            selected: atual.times.contains(time.nome),
                            onSelected: (_) => busca.atualizar(
                              (f) => f.copiarCom(
                                times: _alternado(f.times, time.nome),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: atual.selecoes == 0
                            ? null
                            : busca.limparSelecoes,
                        child: const Text('Limpar'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            busca.carregando
                                ? 'Buscando jogos...'
                                : _textoVerJogos(busca.resultado.length),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Set<T> _alternado<T>(Set<T> itens, T item) =>
      itens.contains(item) ? ({...itens}..remove(item)) : {...itens, item};

  static String _textoVerJogos(int quantidade) =>
      quantidade == 1 ? 'Ver 1 jogo' : 'Ver $quantidade jogos';
}

/// Atalhos para os períodos mais comuns e o calendário para qualquer outro.
class _SecaoPeriodo extends StatelessWidget {
  const _SecaoPeriodo({required this.busca, required this.agora});

  final BuscaJogos busca;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final hoje = apenasDia(agora);
    final amanha = hoje.add(const Duration(days: 1));
    final atalhos = <String, Periodo>{
      'Hoje': (inicio: hoje, fim: hoje),
      'Amanhã': (inicio: amanha, fim: amanha),
      'Próximos 7 dias': (inicio: hoje, fim: hoje.add(const Duration(days: 6))),
    };
    final periodo = busca.filtro.periodo;
    final doCalendario = periodo != null && !atalhos.containsValue(periodo);

    return _Secao(
      titulo: 'Data',
      chips: [
        for (final MapEntry(key: rotulo, value: atalho) in atalhos.entries)
          FilterChip(
            label: Text(rotulo),
            selected: periodo == atalho,
            onSelected: (marcado) =>
                busca.escolherPeriodo(marcado ? atalho : null),
          ),
        FilterChip(
          avatar: const Icon(Icons.calendar_month, size: 18),
          showCheckmark: false,
          label: Text(
            doCalendario ? formatarPeriodo(periodo) : 'Escolher datas',
          ),
          selected: doCalendario,
          onSelected: (_) => _abrirCalendario(context),
          onDeleted: doCalendario ? () => busca.escolherPeriodo(null) : null,
          deleteButtonTooltipMessage: 'Tirar período',
        ),
      ],
    );
  }

  Future<void> _abrirCalendario(BuildContext context) async {
    final hoje = _noCalendario(agora);
    final periodo = busca.filtro.periodo;
    final escolhido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      currentDate: hoje,
      initialDateRange: periodo == null
          ? null
          : DateTimeRange(
              start: _noCalendario(periodo.inicio),
              end: _noCalendario(periodo.fim),
            ),
      helpText: 'Até ${BuscaJogos.maxDias} dias. Um dia só: toque 2 vezes',
      selectableDayPredicate: _dentroDoLimite,
      // Sem digitação: nela, início e fim chegam juntos e o limite de dias
      // não teria como valer.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (escolhido == null) return;
    final inicio = escolhido.start;
    final fim = escolhido.end;
    await busca.escolherPeriodo((
      inicio: diaDeBrasilia(inicio.year, inicio.month, inicio.day),
      fim: diaDeBrasilia(fim.year, fim.month, fim.day),
    ));
  }

  /// O calendário trabalha com o dia do aparelho. Esta data tem os mesmos
  /// números do dia de Brasília, para ele marcar o "hoje" certo em qualquer
  /// fuso.
  static DateTime _noCalendario(DateTime instante) {
    final brasilia = emBrasilia(instante);
    return DateTime(brasilia.year, brasilia.month, brasilia.day);
  }

  /// Depois de tocar no primeiro dia, bloqueia o que passa do limite.
  static bool _dentroDoLimite(DateTime dia, DateTime? inicio, DateTime? fim) {
    if (inicio == null || fim != null || dia.isBefore(inicio)) return true;
    return dia.difference(inicio).inDays < BuscaJogos.maxDias;
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.chips, this.vazio});

  final String titulo;
  final List<Widget> chips;

  /// Texto no lugar dos chips quando não há nenhum.
  final String? vazio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          titulo,
          style: tema.textTheme.titleSmall?.copyWith(
            color: tema.colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 8),
        if (chips.isEmpty && vazio != null)
          Text(vazio!, style: tema.textTheme.bodyMedium)
        else
          Wrap(spacing: 8, runSpacing: 4, children: chips),
      ],
    );
  }
}

/// Logo em círculo branco, para as logos escuras aparecerem no tema escuro.
class _LogoChip extends StatelessWidget {
  const _LogoChip({required this.time});

  final TimeFiltro time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(
        color: CoresNba.branco,
        shape: BoxShape.circle,
      ),
      child: LogoTime(url: time.logo, sigla: time.sigla, tamanho: 18),
    );
  }
}
