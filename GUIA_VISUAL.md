# Guia visual — Agenda Saúde

Referência de cores, tamanhos e padrões de tela do app. O público principal é idoso,
então tudo aqui parte do requisito **NF004** do TCC: fontes de alta legibilidade,
botões destacados e contraste adequado.

Fonte da verdade no código:

- `agenda_saude_app/lib/core/theme/app_theme.dart` — tema Material 3 (botões, cards, campos)
- `agenda_saude_app/lib/core/theme/app_cores.dart` — cor-semente e cores semânticas
- `agenda_saude_app/lib/ui/shared/` — widgets reutilizáveis já no padrão

Se mudar algum valor no código, atualize este guia junto.

## Cores

### Marca (geradas pelo Material 3)

A paleta de marca vem de `ColorScheme.fromSeed` com a semente verde-água `#14B8A6`
(a mesma dos mockups do TCC). No código, use sempre `Theme.of(context).colorScheme.*`,
nunca o hex direto.

| Papel                  | Token                  | Hex       | Uso                                         |
| ---------------------- | ---------------------- | --------- | ------------------------------------------- |
| Cor principal          | `primary`              | `#006B5F` | botões principais, ícones, links            |
| Texto sobre principal  | `onPrimary`            | `#FFFFFF` | texto/ícone de botão preenchido             |
| Container principal    | `primaryContainer`     | `#9EF2E3` | botão secundário (tonal), círculo do coração |
| Texto sobre container  | `onPrimaryContainer`   | `#00201C` | texto do botão secundário                   |
| Fundo das telas        | `surface`              | `#F4FBF8` |                                             |
| Fundo dos cards        | `surfaceContainerLow`  | `#EFF5F2` |                                             |
| Texto principal        | `onSurface`            | `#161D1B` | títulos e textos                            |
| Texto secundário       | `onSurfaceVariant`     | `#3F4946` | descrições, legendas, "Medido às..."        |

Evite `outline` (`#6F7976`) para texto: fica em 4,3:1, abaixo do mínimo.

### Semânticas (`AppCores`)

Estado de saúde e avisos. Cada uma tem o trio cor / container / onContainer. Todas
têm contraste de pelo menos **4,5:1** (WCAG AA para texto comum, AAA para texto
grande) sobre o fundo, sobre os cards e sobre o próprio container.

| Significado | Cor               | Container         | Texto no container | Onde aparece                                 |
| ----------- | ----------------- | ----------------- | ------------------ | -------------------------------------------- |
| Sucesso     | `sucesso` `#146C2E` | `#D3F5D9`       | `#002108`          | "ESTÁVEL", smartwatch "Conectado"            |
| Aviso       | `aviso` `#8B5000`   | `#FFDCBE`       | `#2D1600`          | smartwatch desconectado, falha de sincronização |
| Perigo      | `perigo` `#BA1A1A`  | `#FFDAD6`       | `#410002`          | BPM fora da zona, mensagens de erro          |

Regras:

- **Não usar `Colors.green` / `Colors.red` / `Colors.orange`**: os tons padrão ficam
  entre 2,4:1 e 3,5:1 sobre o fundo claro e reprovam no contraste.
- **Vermelho é só para alerta de saúde e erro.** Problema de conexão com o
  smartwatch é aviso (laranja), para o vermelho não perder força.
- **Nunca informar só pela cor**: todo status tem também ícone e texto
  ("ESTÁVEL", "BATIMENTOS ALTOS").

## Tipografia

Fonte padrão do Material 3 (Roboto no Android). Tamanhos em sp, que crescem junto
com a opção de fonte do celular.

| Tamanho | Peso      | Uso                                                          |
| ------- | --------- | ------------------------------------------------------------ |
| 76      | bold      | número do BPM no painel                                      |
| 44      | bold      | código de vínculo (espaçamento entre letras 10)              |
| 28      | bold      | título da tela (`TituloTela`) e saudação "Olá, José"         |
| 22      | bold      | título de card, status ("ESTÁVEL"), título de alerta         |
| 20      | bold/w600 | botão grande (`BotaoGrande`), item do menu                   |
| 18      | regular   | texto de corpo, descrições, botões padrão (`ElevatedButton`) |
| 16      | regular   | texto secundário (legenda de item do menu) — **mínimo**      |
| 14      | —         | só etiquetas pequenas (chips); evitar em texto novo          |

Textos longos de orientação usam altura de linha `1.35`.

## Tamanhos e formas

| Elemento                             | Medida                                  |
| ------------------------------------ | --------------------------------------- |
| Botão grande de atalho (`BotaoGrande`) | 72dp de altura, ícone 30, formato pílula |
| Botões padrão (Elevated/Filled/Outlined) | 56dp de altura, formato pílula         |
| Item do menu lateral                 | 72dp de altura, ícone 32                |
| Menor alvo de toque                  | 48 × 48dp                               |
| Cards                                | cantos 20, sem sombra, `surfaceContainerLow` |
| Campos de texto                      | cantos 16, preenchidos, sem borda       |
| Margem lateral das telas             | 24dp                                    |
| Espaçamentos verticais               | 8 / 12 / 16 / 24 / 32                   |

## Botões: qual usar

- `BotaoGrande` (preenchido verde-água): a ação principal da tela. Ex.: "Minha Rotina".
- `BotaoGrande(principal: false)` (tonal, verde-água claro): segunda ação de destaque.
  Ex.: "Falar com Acompanhante", "Copiar código".
- `FilledButton`: ação principal **dentro de um card**, que precisa se destacar do
  fundo dele. Ex.: "Conectar smartwatch".
- `OutlinedButton`: ação secundária ou de cancelar.
- `ElevatedButton`: padrão das telas de cadastro/login. Fica claro sobre fundo claro,
  então não use dentro de cards.
- `BotaoLigar`: ligar para alguém (abre o discador com o número). Mesmo tamanho do
  `BotaoGrande`; verde (`AppCores.sucesso`) para ligar para uma pessoa e branco com
  texto vermelho para o SAMU (192) na tela de emergência.

## Tela de emergência (Figura 16)

A única tela com fundo todo vermelho (`AppCores.perigo`), para interromper o
acompanhante: título "ALERTA CRÍTICO" e nome do paciente em branco, quadro branco com
o motivo, o BPM crítico em 76 e o que fazer, e os botões grandes "LIGAR PARA [NOME]"
(só se o paciente tem telefone), "LIGAR PARA O SAMU (192)" e "VER LOCALIZAÇÃO". O
"Voltar" da barra fica branco.

## Navegação

- **Painel como centro**: cada tela principal (painel do paciente/acompanhante) tem
  botões grandes que abrem telas; de cada tela se volta com "Voltar".
- **Relatórios**: o paciente abre pelo botão grande "Meus Relatórios" do painel e o
  acompanhante pelo botão "Ver relatórios" do card do paciente. É a mesma tela
  ("Ontem" e "Mês") para os dois; os textos dos relatórios não dizem "você" nem citam o
  nome, para servirem aos dois — só o título da tela muda.
- **Menu lateral** para o que se usa pouco (minhas metas, código de vínculo, smartwatch,
  localização, lembretes, acessibilidade, sair). Abre
  só pelo botão **"Menu" com ícone + texto** (`BotaoBarraSuperior.menu`); o gesto de
  arrastar da borda fica desligado, porque se confunde com o "voltar" do Android.
- **Subtelas**: barra superior só com "Voltar" escrito (`BotaoBarraSuperior.voltar`) e
  o título grande no corpo (`TituloTela`), não no AppBar.
- **Nada crítico fica escondido no menu**: alerta de BPM e problema do smartwatch
  aparecem no painel.
- **Ações que não dá para desfazer de imediato** (sair, desvincular) pedem confirmação
  com botões grandes (`mostrarDialogoConfirmacao`).

## Acessibilidade (checklist para tela nova)

- [ ] Texto ≥ 16sp (corpo 18sp) e contraste ≥ 4,5:1, usando as cores deste guia
- [ ] Alvos de toque ≥ 48dp; ações principais com 56–72dp
- [ ] Ícones acompanhados de texto
- [ ] Layout não estoura com a fonte do celular em 200% (ver teste em
      `test/ui/paciente/paciente_view_test.dart`): use `Expanded`/`Flexible`,
      `maxLines` com quebra e `FittedBox(fit: BoxFit.scaleDown)` em números grandes
- [ ] Números e códigos com `Semantics(label: ...)` legível em voz alta
      (ex.: "72 por minuto", código soletrado)
- [ ] Alertas com `Semantics(liveRegion: true)` para o leitor de tela anunciar

## Relatórios (`lib/ui/relatorios/`)

Gráfico e calendário próprios, sem biblioteca. Mesmas regras de cor e acessibilidade
do resto do app:

| Situação do dia (calendário)  | Fundo / ícone                                          |
| ----------------------------- | ------------------------------------------------------ |
| Rotina completa               | `sucessoContainer` + `check_circle` verde              |
| Rotina parcial                | `avisoContainer` + `incomplete_circle` laranja         |
| Sem registro                  | cinza + `remove_circle_outline`                        |
| Hoje / dia que não chegou     | sem fundo, sem ícone (hoje tem borda)                  |
| Alerta de saúde no dia        | `warning` vermelho ao lado do ícone da situação        |

- **Gráfico de barras** (`GraficoDiario`): uma barra por dia, sempre com legenda das
  cores e das linhas de referência (meta de água, limites 70 e 180 mg/dL) e uma frase
  para o leitor de tela. Verde = meta batida / na faixa; cinza = abaixo da meta;
  laranja = glicemia alta; vermelho = glicemia baixa ou muito alta.
- **Gráfico de linha do BPM** (`GraficoBatimentos`, só no relatório do dia): a curva das
  24 horas com a **zona de segurança como faixa verde** (`sucessoContainer`), a linha da
  média a cada 10 minutos (`primary`) com uma barra fina atrás do menor ao maior BPM, e
  **buraco** onde o relógio ficou mais de 1 h sem medir. Os alertas se distinguem pela
  **forma**, não só pela cor: círculo vermelho = emergência, losango laranja = atenção,
  e a legenda embaixo diz o que é cada coisa (só os tipos que existem no dia). Os números
  do eixo usam a fonte do tema a 16sp e, com a fonte do celular muito grande, pulam de
  dois em dois sem nunca tirar os limites da zona; a altura do gráfico cresce junto. O
  leitor de tela ouve uma descrição em frases (variação, leituras fora da zona e cada
  alerta com a hora), e o desenho fica fora da árvore de semântica.
- Calendário: o toque vale a célula inteira (cerca de 42 × 56dp num celular de 360dp e
  49 × 56dp num de 411dp — um pouco abaixo dos 48dp de largura nos celulares mais
  estreitos, porque são 7 colunas); cada célula tem texto falado ("Dia 4: rotina
  parcial, com alerta de saúde").
- Com a fonte do celular muito grande, números lado a lado e botões "Mês anterior /
  Próximo mês" passam a ficar um embaixo do outro.

## Lembretes (`lib/ui/lembretes/`) e Acessibilidade (`lib/ui/configuracoes/`)

Telas abertas pelo menu lateral, no mesmo molde das de smartwatch e localização:

- **Estado em texto e ícone, nunca só em cor**: "Lembretes ligados" / "Narrador ligado"
  em verde (`AppCores.sucesso`) com ícone de sino ou de voz; desligado em cinza
  (`onSurfaceVariant`) com o ícone cortado. Embaixo, **um botão grande que troca o
  estado**: `FilledButton` "Ligar …" quando está desligado e `OutlinedButton` "Desligar …"
  quando está ligado (nada de interruptor pequeno).
- **Avisos que pedem uma ação** (notificações desativadas, alarmes exatos, voz em
  português ausente) são cartões laranja (`AppCores.aviso`) com a explicação e, quando
  dá para resolver, um `FilledButton` ("Ativar notificações", "Permitir alarmes").
- **Lista de horários**: cartão por lembrete com o horário em 26 bold na cor principal e
  o que fazer ao lado ("Tomar Losartana 50 mg"); a frase falada junta tudo ("…, às 8
  horas"). "Mudar horário" (só glicemia e insulina; o dos remédios é em "Meus remédios")
  abre o relógio (`mostrarSeletorDeHorario`) no horário de agora do aviso, com o título
  "HORÁRIO DA GLICEMIA" ou "HORÁRIO DA INSULINA" (curto, para caber numa linha e não
  encolher o relógio). Depois de mudar, o cartão ganha um segundo botão, "Voltar para
  07:00", que some quando o aviso volta ao horário padrão; cada mudança confirma com um
  aviso embaixo ("Horário mudado para 06:30."), porque a lista se reordena pelo horário.
- **Velocidade da voz**: três `BotaoSelecionavel` um embaixo do outro (Devagar, Normal,
  Rápido, com check no escolhido) e "Testar voz"; tocar em uma velocidade já fala um exemplo.
- **Ouvir esta tela** (`BotaoOuvirTela`): botão de contorno de 56dp, com ícone de alto-falante,
  **logo abaixo do título** do painel, da rotina, dos relatórios e da lista de notificações.
  Enquanto a voz fala vira botão preenchido "Parar de ouvir", com o ícone de parar. Só
  aparece com o narrador ligado e **some com o TalkBack ligado** (a tela de Acessibilidade
  explica o porquê), sem deixar buraco no lugar. Na tela de emergência (fundo vermelho)
  o contorno e o texto ficam brancos, e a tela fala sozinha ao abrir.
- **O que o narrador lê**: um resumo **curto**, não a tela inteira. O que importa agora, em
  frases curtas e nesta ordem: o alerta primeiro, depois o que FALTA (na rotina, só o que
  falta; o que já foi feito vira uma contagem), e por fim para onde ir. Sem siglas que a
  voz lê mal: "batimentos por minuto" (não "BPM"), "miligramas por decilitro" (não
  "mg/dL"), "50 miligramas" (não "50mg"), horas por extenso ("14 horas e 5 minutos") e o
  192 como "um, nove, dois". Cada texto fica numa função `narrar...` (`narracao_*.dart`)
  com teste que limita o número de palavras (50 a 95, de 15 a 40 segundos de fala).

## Widgets compartilhados (`lib/ui/shared/`)

| Widget                      | Para quê                                                  |
| --------------------------- | --------------------------------------------------------- |
| `BotaoGrande`               | atalho principal da tela (72dp)                           |
| `BotaoLigar`                | botão de 72dp que abre o discador com o número (cor escolhida por quem usa) |
| `BotaoBarraSuperior`        | "Menu" / "Voltar" com ícone + texto na barra superior     |
| `TituloTela`                | título 28 no topo do conteúdo, com subtítulo opcional     |
| `CardStatus`                | selo de status colorido ("ESTÁVEL")                       |
| `CaixaAlerta`                | caixa vermelha de alerta de saúde com orientação          |
| `mostrarDialogoConfirmacao` | pergunta "tem certeza?" com botões grandes                |
| `mostrarSeletorDeHorario`   | relógio do Flutter para escolher um horário, sem digitar: 24 h, só o relógio (sem o ícone de teclado), título em caixa alta e botões maiores pelo `timePickerTheme`; devolve "HH:MM" |
| `BotaoSelecionavel`         | escolha entre poucas opções (Sim/Não, perfil)             |
| `BarraAcoes`                | botões fixos na base (`bottomNavigationBar`) em telas longas, para a ação principal nunca sair da vista |
| `LogoAgendaSaude`           | marca nas telas de entrada                                |
| `PerguntaFormulario`        | pergunta numerada em caixa alta que abre cada bloco de um formulário da Rotina (sono, exercício) |
| `ErroFormulario`            | erro de formulário: caixa alta, ícone e vermelho, anunciado pelo leitor de tela |
| `BotaoSalvar`               | "SALVAR" de 72dp que fecha um formulário da Rotina; vira indicador de progresso enquanto grava |
| `ContadorGrande`            | valor grande com "Menos" / "Mais" de 64dp, para números sem teclado (horas de sono, minutos de exercício); os botões descem um para baixo do outro com a fonte aumentada |
| `BotaoOuvirTela`            | "Ouvir esta tela": lê em voz alta um resumo curto da tela (só com o narrador ligado; some com o TalkBack); vira "Parar de ouvir" enquanto fala |
| `rotaComNarrador`           | rota que leva o narrador de voz para a tela aberta por cima (as telas novas não herdam os providers da que as abriu) |

## Rotina (`lib/ui/rotina/`)

Um cartão compacto por atividade na "Minha Rotina", na ordem do dia: hidratação,
medicações, refeições, glicemia e insulina (só para diabéticos), sono, exercício. O que é
de um toque (copo d'água, tomar um remédio) resolve no próprio cartão; o que tem várias
perguntas abre uma tela própria (registrar o sono, registrar um exercício, "Meus
remédios"), que volta com um aviso ("Sono registrado.").

- **Medicações**: uma linha por dose com **caixa de seleção grande** (44dp), como na
  Figura 14 do TCC; marcada fica com fundo e borda verdes e o texto "Tomado às 08:10".
- **Telas de registro**: perguntas numeradas em caixa alta (`PerguntaFormulario`), opções
  em botões de 64dp com check no escolhido (`BotaoSelecionavel`) e "SALVAR" no fim
  (`BotaoSalvar`). Nada de campo de texto quando uma escolha resolve: o horário de um
  remédio (e o de um lembrete) se escolhe no relógio (`mostrarSeletorDeHorario`), e não
  digitando.
- **Semana de exercício**: começa no domingo, como o calendário dos relatórios.
