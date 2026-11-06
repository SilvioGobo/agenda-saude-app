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
- **Menu lateral** para o que se usa pouco (minhas metas, código de vínculo, smartwatch, sair). Abre
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
- Calendário: o toque vale a célula inteira (cerca de 42 × 56dp num celular de 360dp e
  49 × 56dp num de 411dp — um pouco abaixo dos 48dp de largura nos celulares mais
  estreitos, porque são 7 colunas); cada célula tem texto falado ("Dia 4: rotina
  parcial, com alerta de saúde").
- Com a fonte do celular muito grande, números lado a lado e botões "Mês anterior /
  Próximo mês" passam a ficar um embaixo do outro.

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
| `BotaoSelecionavel`         | escolha entre poucas opções (Sim/Não, perfil)             |
| `BarraAcoes`                | botões fixos na base (`bottomNavigationBar`) em telas longas, para a ação principal nunca sair da vista |
| `LogoAgendaSaude`           | marca nas telas de entrada                                |
