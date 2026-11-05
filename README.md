# NBA Game Day

App Flutter (Android) com a agenda dos próximos jogos da NBA no horário do Brasil e notificações push via Firebase Cloud Messaging (FCM).

Atividade Prática — Notificações Push · Programação para Dispositivos Móveis.

## Finalidade

Ajudar o torcedor brasileiro a não perder jogos da NBA. Os jogos acontecem à noite em horários variados e o fuso horário confunde. Por isso o app mostra a agenda de hoje, amanhã e depois de amanhã já convertida para o horário de Brasília, qualquer que seja o fuso do aparelho, e as notificações avisam na hora certa, sem o usuário precisar abrir o app.

| Desafio | Notificação | Por que existe |
|---|---|---|
| 1 — Simples | Resumo da rodada do dia | Avisa no começo da noite quantos jogos há e quando começa o primeiro. Informação curta, sem imagem nem navegação. |
| 2 — Com imagem | "Jogo da Noite" | O confronto em destaque ganha um banner que chama atenção na bandeja. |
| 3 — Com navegação | "Começa em 30 minutos" | O aviso é sobre **um** jogo, então o toque abre os detalhes **daquele** jogo, e não a tela inicial. |

## Fonte dos dados

- **Principal: API pública da ESPN** (`site.api.espn.com/.../nba/scoreboard?dates=AAAAMMDD`). Não é oficial nem documentada, mas é a usada pelo próprio site da ESPN e não exige chave. O formato observado está em [`docs/espn_formato.md`](docs/espn_formato.md).
  - O app consulta de ontem até depois de amanhã e filtra pela **data de Brasília**. Jogos tarde nos EUA pertencem ao "dia americano" anterior, mas no Brasil caem na madrugada seguinte.
  - O parser é defensivo: um evento incompleto é descartado sem derrubar a lista.
- **Fallback: dados de demonstração** embutidos no código (`lib/data/jogos_mock.dart`), com datas relativas a hoje. São usados quando:
  - todas as requisições falham → aviso "Sem conexão com a ESPN";
  - a ESPN responde, mas não há jogos no período → aviso "Sem jogos nos próximos dias";
  - o app é iniciado com `--dart-define=FONTE_DADOS=mock` → aviso "Modo demonstração".

## Telas

O visual usa as **cores oficiais da NBA** (definidas em `lib/tema.dart`): azul `#1D428A` na AppBar e nos títulos do dia, vermelho `#C8102E` nos destaques (faixa da AppBar, marcador dos dias, card e selo do "Jogo da Noite", "Ao vivo", ícones, carregamento e botão principal), preto `#000000` para texto e jogos encerrados e branco `#FFFFFF` nos cards.

O título da Home usa a logo da NBA seguida de "GAME DAY". A fonte oficial da NBA é proprietária, então o texto usa a **Anton** (`assets/fonts/`, licença SIL OFL), uma fonte condensada parecida com as letras da logo.

O botão de sol/lua na AppBar da Home alterna entre os **modos claro e escuro**. No escuro, o fundo é preto, os títulos, ícones e textos vermelhos usam tons mais claros para manter a leitura e as logos ficam em círculos brancos. A escolha não é salva: ao reabrir, o app volta ao modo claro.

- **Home:** jogos agrupados por dia ("Hoje", "Amanhã", data do 3º dia), com horário de Brasília, arena, status e placar. Inclui puxar para atualizar e um aviso quando os dados são de demonstração. A **barra de busca** encontra jogos pelo nome ou sigla do time, e o botão ao lado dela abre o **painel de filtros**:
  - **Data:** atalhos (Hoje, Amanhã, Próximos 7 dias) ou um calendário para escolher qualquer período de até 31 dias, passado ou futuro. Fora dos 3 dias da lista padrão, o app busca esses dias na ESPN, um por requisição, porque a API não aceita intervalo de datas.
  - **Conferência:** Leste, Oeste (jogos com pelo menos um time da conferência) ou Leste x Oeste (só confrontos entre as duas). A API do scoreboard não traz a conferência, então os times ficam em `lib/models/conferencia.dart`.
  - **Horário e times:** tirados dos jogos do período. Os horários são só os dos jogos que ainda vão começar, exceto em períodos todos no passado, que mostram todos. A lista continua trazendo também os jogos que já aconteceram. Filtros diferentes valem juntos; dentro de um mesmo filtro, basta combinar com um dos itens marcados.
- **Detalhes:** cabeçalho com gradiente nas cores dos times (mesmo visual do banner da notificação), data e horário, arena, cidade, status, placar e prévia (só nos dados de demonstração). Tem estados de carregamento e "Jogo não encontrado".
- **Painel de demonstração** (ícone 🔧 na AppBar): token FCM copiável, status da permissão, fonte dos dados e os jogos de hoje com o **ID copiável**, usado na Notificação 3.

**Logos dos times:** a Home e os detalhes mostram a logo de cada time, usando a URL que a própria API da ESPN devolve (`team.logo`). As logos são marcas registradas dos times: por isso, no app, são carregadas da CDN da ESPN quando ele roda, em vez de ficarem nos arquivos do projeto. A exceção é o banner do Jogo da Noite, que traz as logos do confronto e fica em `assets/banners/`, porque o FCM precisa de uma imagem pronta. Sem conexão, aparece um círculo com a sigla do time no lugar. A logo da NBA no título segue a mesma regra: vem da CDN da ESPN e, sem conexão, é trocada pelo texto "NBA".

## Como as notificações funcionam no app

Tudo fica em [`lib/services/notification_service.dart`](lib/services/notification_service.dart):

| Estado do app | Comportamento |
|---|---|
| Segundo plano / fechado, sem `jogo_id` | O Android mostra a notificação (com imagem, se houver); o toque abre o app. |
| Segundo plano, toque com `jogo_id` | `onMessageOpenedApp` → abre `/jogo` com o ID. |
| Fechado (removido dos recentes), toque com `jogo_id` | `getInitialMessage()` → abre `/jogo` depois do primeiro frame; voltar leva à Home. |
| Primeiro plano | `onMessage` → SnackBar com título e texto; se houver `jogo_id`, a ação **Ver** abre o jogo. |

- **Mesma rota em todos os casos:** a navegação usa a rota `/jogo`, a mesma do toque no card da Home. A tela de detalhes espera o carregamento dos jogos quando o app é aberto pela notificação.
- **Dados personalizados:** a chave é **`jogo_id`**, lida com `trim()`.
- **Toques repetidos:** são ignorados pelo `messageId`.
- **Token FCM:** o app usa `getToken()`. No `firebase_messaging` 17 ele está marcado como obsoleto em favor de `register()`, mas a API nova devolve um Firebase Installation ID, e não o token que o Firebase Console pede em "Enviar mensagem de teste".

## Como rodar

Pré-requisitos: Flutter (stable) e um aparelho Android, ou emulador **com Google Play**, porque imagens sem Google Play não recebem FCM.

```bash
flutter pub get
flutter run                                  # dados da ESPN (com fallback)
flutter run --dart-define=FONTE_DADOS=mock   # força os dados de demonstração
flutter run --release                        # recomendado para gravar o vídeo
flutter test                                 # testes do parser e do repositório
flutter analyze
```

O token FCM aparece no painel 🔧. Em modo debug, ele também sai no log, na linha `[FCM] token: ...`; no build de release, ele não é registrado no log.

### Configuração do Firebase

O projeto já vem configurado (`flutterfire configure`, só Android). `android/app/google-services.json` e `lib/firebase_options.dart` são **configurações de cliente** do Firebase, feitas para ir dentro do app. Elas não são credenciais secretas e podem ser versionadas neste trabalho. Para usar outro projeto Firebase, rode `flutterfire configure` de novo.

## Enviando as notificações (Firebase Console)

Caminho: **Messaging → Nova campanha → Notificações** → preencher → **Enviar mensagem de teste** → colar o token do painel 🔧 → **+** → **Testar**. Para ver na bandeja, o app precisa estar em segundo plano ou fechado.

### Notificação 1 — Desafio 1 (simples)

- **Título:** `🏀 Rodada de hoje`
- **Texto (modelo):** `<N> jogos hoje, a partir das <hora do 1º jogo>. <Time A> x <Time B> abre a noite!`
- **Fallback:** `3 jogos hoje, a partir das 21h30. Celtics x Lakers abre a noite!`
- Sem imagem e sem dados personalizados.

### Notificação 2 — Desafio 2 (com imagem)

- **Título (modelo):** `⭐ Jogo da Noite: <Time A> x <Time B>`
- **Texto (modelo):** `O destaque da rodada começa às <hora>. Confira os detalhes no app!`
- **Imagem:** `https://raw.githubusercontent.com/yagoschnorr/nba-game-day/main/assets/banners/jogo_da_noite.png`
- **Fallback:** título `⭐ Jogo da Noite: Celtics x Lakers`, texto `O maior clássico da NBA começa às 21h30. Confira a prévia!`, imagem `https://raw.githubusercontent.com/yagoschnorr/nba-game-day/main/assets/banners/mock_1.png`
- Sem dados personalizados, para manter os desafios separados.

### Notificação 3 — Desafio 3 (com navegação)

- **Título:** `⏰ Começa em 30 minutos`
- **Texto (modelo):** `<Time A> x <Time B> às <hora>. Toque para ver os detalhes do jogo.`
- **Opções adicionais → Dados personalizados:** chave `jogo_id`, valor = ID copiado do painel 🔧.
- **Fallback:** texto `Nuggets x Thunder às 23h. Toque para ver os detalhes do jogo.`, `jogo_id = mock-3`. IDs `mock-*` funcionam mesmo com a ESPN ativa.

## Gerando banners (Desafio 2)

O script [`tools/gerar_banner.py`](tools/gerar_banner.py) usa Pillow (`pip install pillow`). Ele gera um PNG de 1024×512 com o mesmo desenho do cabeçalho dos detalhes, incluindo as logos, que podem ser URLs da CDN da ESPN ou arquivos locais. O script **falha se o arquivo passar de 1 MB**, o limite do FCM para imagens.

```bash
python3 tools/gerar_banner.py --mandante "Boston Celtics" --visitante "Los Angeles Lakers" \
  --quando "Hoje, 21h30" --cor-mandante "#007A33" --cor-visitante "#552583" \
  --sigla-mandante BOS --sigla-visitante LAL \
  --logo-mandante https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/bos.png \
  --logo-visitante https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/lal.png \
  --saida assets/banners/jogo_da_noite.png
```

Cores, siglas e logos são opcionais. Sem as cores dos times, o banner usa o azul e o vermelho da NBA, como o cabeçalho do app. A imagem precisa estar num **repositório público** para o FCM baixá-la: faça commit e push e teste a URL `raw.githubusercontent.com` no navegador do celular antes de enviar.

## Roteiro do dia da gravação

Como os jogos mudam todo dia, os textos são preenchidos na hora:

1. Abrir o app e conferir no painel 🔧 que a fonte é **ESPN**.
2. Escolher o Jogo da Noite (Notificação 2) e um jogo para a Notificação 3; pode ser o mesmo.
3. Gerar o banner `jogo_da_noite.png` com os times, as cores e o horário escolhidos, fazer commit e push e testar a URL no celular.
4. Copiar no painel 🔧 o ID do jogo da Notificação 3.
5. Preencher os modelos acima.

Se não houver jogos no dia ou a ESPN estiver fora, o app entra no fallback e usam-se as versões **fallback** de cada notificação.

Ordem sugerida no vídeo: finalidade e decisões → Desafio 1 (app em segundo plano) → Desafio 2 (expandir a notificação para mostrar o banner e abrir o jogo no app) → Desafio 3 em segundo plano → Desafio 3 com o app fechado (removido dos recentes, sem "Forçar parada") → extras (SnackBar com o app aberto, fallback em modo avião) → trecho do `notification_service.dart`.

## Estrutura

```
lib/
├── main.dart                      # Firebase, handler de background, runApp
├── app.dart                       # MaterialApp, navigatorKey, rotas "/" e "/jogo"
├── tema.dart                      # cores oficiais da NBA e temas claro e escuro
├── firebase_options.dart          # gerado pelo flutterfire configure
├── models/                        # jogo, filtro_jogos (busca e filtros da Home), conferencia
├── data/
│   ├── espn_api.dart              # requisições e parser da ESPN
│   ├── jogos_mock.dart            # dados de demonstração (fallback)
│   ├── jogos_repository.dart      # escolha da fonte, cache, buscarPorId, buscarPeriodo
│   └── busca_jogos.dart           # estado da busca da Home e consulta por período
├── services/notification_service.dart
├── screens/                       # home_screen, detalhes_jogo_screen
├── widgets/                       # jogo_card, cabecalho_confronto, logo_time, titulo_app, demo_sheet, filtros_jogos
└── utils/datas.dart               # datas em português, sem o pacote intl
test/                              # parser e repositório (com respostas reais da ESPN), datas, filtros e Home
tools/gerar_banner.py
docs/espn_formato.md
assets/banners/
assets/fonts/                      # Anton e sua licença (OFL)
```

## Limitações conhecidas

- A API da ESPN não é oficial e pode mudar sem aviso; o parser defensivo e o fallback existem por isso.
- "Forçar parada" nas configurações do Android bloqueia as mensagens até o app ser aberto de novo. Para testar com o app fechado, basta removê-lo dos recentes.
- O app foi feito e testado só para Android.
