# Formato da API da ESPN (scoreboard da NBA)

Levantamento feito em 03/11/2026 a partir de respostas reais. A API não é oficial nem documentada, então este arquivo registra o que foi **observado**. O parser (`lib/data/espn_api.dart`) segue estes caminhos.

## Endpoint

```
GET https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=AAAAMMDD
```

- Não exige chave. Responde `200` com JSON, inclusive em dia sem jogos.
- `dates` é o **dia americano** (horário de Nova York), e não o dia em UTC nem o de Brasília. Exemplo: `dates=20261102` traz jogos com `date` entre `2026-11-03T00:00Z` e `2026-11-03T03:00Z`.
- **Não aceita intervalo:** `dates=20261105-20261112` responde `400` (`"Failed to get events endpoint."`), com ou sem `limit`. Por isso, o filtro de período do app faz uma requisição por dia.
- **Não traz a conferência dos times:** nem em `c.team` nem em `comp`, onde `conferenceCompetition` só indica se é um jogo de conferência. A divisão usada em `lib/models/conferencia.dart` foi conferida em 05/11/2026 em `site.api.espn.com/apis/v2/sports/basketball/nba/standings`, que tem os nomes iguais a `c.team.displayName`.

## Fixtures salvas em `test/fixtures/`

| Arquivo | Requisição | Conteúdo |
|---|---|---|
| `espn_scoreboard.json` | `dates=20261102` | 15 jogos **encerrados**, com placar. Três deles caem na madrugada de 03/11 em Brasília. |
| `espn_scoreboard_agendados.json` | `dates=20261104` | 14 jogos **agendados**, com placar `"0"`. |
| `espn_scoreboard_vazio.json` | `dates=20261103` | Dia **sem jogos**: `events` é uma lista vazia. |

Não há fixture de jogo **em andamento**, porque nenhum estava acontecendo na hora da coleta.

## Caminhos de chave

Raiz: `{ "leagues": [...], "events": [...], "provider": {...} }`. Abaixo, `comp` é `event.competitions[0]` (sempre há exatamente uma competição por evento) e `c` é cada item de `comp.competitors` (sempre dois).

| Campo do `Jogo` | Caminho | Exemplo | Observações |
|---|---|---|---|
| lista de eventos | `events` | `[...]` | Lista vazia em dia sem jogos. |
| `id` | `event.id` | `"401909907"` | String numérica. Igual a `comp.id`. |
| `dataHora` | `event.date` | `"2026-11-03T00:00Z"` | UTC, **sem segundos**. Igual a `comp.date` em todos os eventos observados. O app guarda esse instante e converte para Brasília ao exibir (`lib/utils/datas.dart`). |
| mandante / visitante | `c.homeAway` | `"home"` / `"away"` | Identifica cada lado. **Não confiar na ordem da lista.** |
| nome do time | `c.team.displayName` | `"Cleveland Cavaliers"` | |
| sigla | `c.team.abbreviation` | `"CLE"`, `"UTAH"`, `"GS"` | Nem sempre tem 3 letras. |
| logo | `c.team.logo` | `"https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/cle.png"` | PNG 500×500 com fundo transparente, na CDN da ESPN. Também existe `c.team.logoDark`. Presente nos 30 times das fixtures. O parser só aceita `https` em `espncdn.com` e seus subdomínios. |
| cor | `c.team.color` | `"860038"` | Hex **sem `#`**. Também existe `c.team.alternateColor`. |
| arena | `comp.venue.fullName` | `"Rocket Arena"` | |
| cidade | `comp.venue.address.city` | `"Cleveland"` | O estado fica em `comp.venue.address.state` (`"OH"`). |
| status | `comp.status.type.state` | `"pre"`, `"post"` | Ver a tabela de status abaixo. `event.status` tem o mesmo conteúdo. |
| placar | `c.score` | `"112"` | String. Nos jogos agendados vem `"0"`. |

## Status

| `state` | `name` observado | `completed` | Status no app |
|---|---|---|---|
| `pre` | `STATUS_SCHEDULED` | `false` | Agendado |
| `in` | (não observado) | `false` | Ao vivo |
| `post` | `STATUS_FINAL` | `true` | Encerrado |

O app decide pelo `state`, que só tem esses três valores, e não pelo `name`, que varia (intervalo, adiado etc.). Os textos de `description` e `detail` vêm em inglês (`"Final"`, `"Wed, November 4th at 7:00 PM EST"`) e não são exibidos.

## Regras que o parser precisa seguir

1. **Placar só quando `state != "pre"`.** Jogos agendados trazem `"0"`, que não deve ser mostrado como placar 0 x 0.
2. **Campos essenciais:** `event.id`, `event.date` e os dois competidores com `homeAway` e `team.displayName`. Sem algum deles, o evento é descartado.
3. **Campos opcionais:** siglas, cores, logos, arena, cidade e placar. Viram `null` quando ausentes (ou string vazia, no caso de arena e cidade, que não são anuláveis no modelo). Nas fixtures, todos os 29 eventos têm todos esses campos.
4. **Cores iguais:** há confrontos em que os dois times têm a mesma `color` (ex.: PHI @ DET, ambos `1d428a`). Nesse caso, usar a `alternateColor` do visitante, para o gradiente do cabeçalho não ficar chapado.
5. **Formato da data:** `DateTime.parse` do Dart aceita `"2026-11-03T03:00Z"` sem segundos e devolve UTC (conferido no Dart 3.13). O app não usa `.toLocal()`, que depende do fuso do aparelho: `emBrasilia()` subtrai 3 horas e dá 03/11 às 0h.

## Exemplos de conversão para conferir à mão

Em novembro, Nova York está em EST (UTC−5) e Brasília em UTC−3, então a diferença é de 2 horas.

| Jogo (id) | `event.date` (UTC) | Nova York | Brasília |
|---|---|---|---|
| OKC @ CLE (`401909907`) | `2026-11-03T00:00Z` | 02/11, 19h | **02/11, 21h** |
| POR @ DEN (`401909918`) | `2026-11-03T02:00Z` | 02/11, 21h | **02/11, 23h** |
| MIA @ LAL (`401909921`) | `2026-11-03T03:00Z` | 02/11, 22h | **03/11, 0h** (madrugada do dia seguinte) |
| PHI @ DET (`401909922`) | `2026-11-05T00:00Z` | 04/11, 19h | **04/11, 21h** |

O caso MIA @ LAL é o motivo de o app pedir também a data de "ontem" e filtrar pela data de Brasília: o jogo pertence ao dia americano 02/11, mas no Brasil ele acontece em 03/11.
