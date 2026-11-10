# Agenda Saúde — TCC (Engenharia de Software, UNIGRAN)

Aplicativo móvel Flutter para monitoramento preventivo de idosos e pessoas com doenças
crônicas (diabéticos e cardiopatas). Conecta dois perfis: **Paciente** (registra rotina,
usa smartwatch) e **Acompanhante** (supervisiona remotamente, recebe alertas).

A especificação completa está em `TCC_1_FINAL - Gabriel Menegati_Silvio Daniel.pdf`
(requisitos RF001–RF008, casos de uso, diagrama de classes, mockups). O documento é a
fonte da verdade: em caso de dúvida sobre comportamento ou escopo, consulte-o antes de
inventar. O código Flutter fica em `agenda_saude_app/`.

## Stack (fixada pelo TCC — não trocar)

- **Flutter 3.32.8 via FVM** — sempre usar `fvm flutter ...` (nunca `flutter` direto)
- **NUNCA alterar a versão do Flutter/Dart**: não editar `.fvmrc`, não rodar `fvm use`,
  não mudar `environment.sdk` no `pubspec.yaml`, não rodar `fvm flutter upgrade` nem
  `flutter pub upgrade --major-versions`. O projeto é desenvolvido em dupla e a versão
  precisa ficar idêntica nas duas máquinas — qualquer mudança de versão quebra isso.
  Adicionar uma dependência nova no `pubspec.yaml` (ex.: `provider`) é normal e
  esperado conforme os módulos avançam; o que não pode mudar é a versão do
  Flutter/Dart em si.
- Dart 3.x, Material 3, seed color teal
- Idioma fixo em português do Brasil (`locale` do `MaterialApp` + `flutter_localizations`,
  que vem com o SDK): seletores de hora e de data, "Colar"/"Copiar" e o que o TalkBack
  diz deles saem em português, qualquer que seja o idioma do celular
- **Firebase (BaaS)**: Auth (login/cadastro), Cloud Firestore (dados + sync em tempo
  real), Cloud Messaging (notificações push) e Cloud Functions (`functions/` na raiz,
  Node 22, quem manda o push; exige o plano Blaze). Projeto: `tcc-agenda-saude`
- **Arquitetura: MVVM + Clean Architecture** — ViewModels com `ChangeNotifier` +
  `provider`; lógica de negócio independente de UI e de Firebase
- Bibliotecas previstas no documento: `provider`, `health` (BPM do smartwatch),
  `flutter_tts` (narrador), `cloud_firestore`, `firebase_messaging`.
  Adicionar cada uma só quando o módulo que a usa for iniciado.
- Testes: `flutter_test` + `fake_cloud_firestore` (unidade), `integration_test` (fluxo)

## Comandos

```bash
cd agenda_saude_app
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run
```

Cloud Functions (pasta `functions/` na raiz do repositório):

```bash
cd functions
npm ci
npm test                             # sem Firebase: Firestore e FCM falsos
firebase deploy --only functions     # roda o npm test antes; exige o plano Blaze
```

Security rules (pasta `firestore_rules_test/` na raiz; precisa do Java 21 para o
`firebase emulators:exec`):

```bash
cd firestore_rules_test
npm ci
npm run test:emulador                # sobe o emulador (projeto demo-rules) e roda os testes
```

Com o emulador já no ar (ex.: o jar rodando com o Java 17), `npm test` com
`FIRESTORE_EMULATOR_HOST=127.0.0.1:<porta>` roda os mesmos testes.

## Estrutura de pastas

Já existente (não reorganizar):

```
agenda_saude_app/lib/
  main.dart                 # init Firebase + runApp
  firebase_options.dart     # gerado pelo flutterfire (não editar à mão)
  domain/models/            # entidades do diagrama de classes — COMPLETO
  data/repositories/        # acesso ao Firestore — parcial
  ui/<feature>/             # <feature>_view.dart + <feature>_viewmodel.dart
```

Estrutura-alvo conforme o app crescer (uma pasta por tela/feature, sempre View +
ViewModel juntos):

```
lib/
  core/
    theme/          # tema acessível (NF004): fonte grande, alto contraste, botões grandes
    constants/      # zonas de segurança de BPM, metas de hidratação, momentos de glicemia
    services/       # tts_service, health_service, notification_service, push_service (wrappers de plugin)
  domain/models/    # já completo (ver abaixo)
  domain/metas/     # CalculadoraMetas + MetasPersonalizadas: metas a partir da triagem
  domain/refeicoes/ # RefeicoesPadrao: plano de refeições de quem não personalizou
  domain/alimentos/ # Alimento, Nutrientes, CatalogoAlimentos (busca por nome)
  domain/relatorios/ # ResumoDoDia, ResumoDoMes e CalculadoraRelatorios: as contas dos relatórios
  domain/medicacao/ # DosePlanejada e normalizarHorario: as doses do dia a partir dos remédios do paciente
  domain/lembretes/ # Lembrete e PlanejadorDeLembretes: o que lembrar, quando, e o que já foi cumprido hoje (RF 07.3)
  domain/acessibilidade/ # ConfiguracaoNarrador e VelocidadeNarracao (RF 07 e RF 08)
  domain/batimentos/ # MonitorZonaSeguranca: as regras dos alertas de BPM (app aberto e fechado)
  data/repositories/
    auth_repository.dart          # existente: wrapper do FirebaseAuth (RF001)
    paciente_repository.dart      # existente
    acompanhante_repository.dart  # existente (vincular/desvincular paciente)
    dados_repository.dart         # existente: DadosMedicosRepository (registros, BPM, alertas)
    relatorios_repository.dart    # existente: RelatoriosRepository (só lê, por período)
    preferencias_repository.dart  # existente: PreferenciasRepository (shared_preferences: só no aparelho)
  ui/
    auth/           # abertura, login, cadastro, recuperar senha, seleção de perfil (RF001)
    triagem/        # questionário adaptativo de comorbidades (RF002)
    paciente/       # painel principal: BPM em destaque, status, atalhos
    rotina/         # checklist diário: água, remédios, refeições, sono, exercício (RF003)
    insulina/       # glicemia + insulina — só visível se possuiDiabetes (RF008)
    acompanhante/   # painel com cards dos pacientes vinculados (RF005)
    relatorios/     # relatório do dia anterior e relatório mensal, para paciente e acompanhante (RF05)
    alertas/        # tela de emergência (overlay vermelho) + lista de notificações (RF006)
    configuracoes/  # acessibilidade: ativar narrador, velocidade da fala (RF007) e ler as telas em voz alta (RF 08.2)
    lembretes/      # "Meus lembretes": ligar/desligar os avisos, permissões e horários da glicemia (RF 07.3)
    metas/          # "Minhas metas": ver as metas calculadas, ajustar e recalcular
    shared/         # widgets reutilizáveis acessíveis (BotaoGrande, CardStatus, BotaoOuvirTela, etc.)
test/               # espelha lib/ (test/domain/models, test/data/repositories, test/ui)
integration_test/   # fluxos completos no emulador
```

Fora do app, na raiz do repositório: `functions/` (Cloud Functions em JavaScript:
`index.js` com o gatilho e a função agendada, `notificacao.js` (push), `pendencias.js`
(B9), `sem_dados.js` (B10) e `verificacoes.js` (uma execução da função agendada) com a
lógica, `test/` com `node --test` e um Firestore falso em `test/firestore_falso.js`) e
`firestore_rules_test/` (testes do `firestore.rules` no emulador, com
`@firebase/rules-unit-testing`; um arquivo `*.test.js` por regra).

## Modelo de dados (Firestore)

Convenções já estabelecidas nos repositories — manter:

- `usuarios/{uid}` — doc id = UID do Firebase Auth. Paciente e Acompanhante na mesma
  coleção, discriminados pelo campo `perfil` (`'Paciente'` | `'Acompanhante'`).
  Paciente tem `possuiDiabetes`, `possuiCardiopatia`, `codigoVinculo`,
  `acompanhantesVinculadosIds: List<String>`;
  Acompanhante tem `pacientesVinculadosIds: List<String>` e `fcmTokens: List<String>`,
  os aparelhos que recebem o push dos alertas (B6). O token entra ao abrir o painel (login
  ou sessão salva) e na renovação do FCM, e sai ao tocar em "Sair"
  (`AcompanhanteRepository.adicionarTokenPush`/`removerTokenPush`, só esse campo; fora do
  `toJson()`). O paciente consegue ler os tokens pelo `get` de "Falar com Acompanhante",
  mas um token sozinho não manda push: isso exige a conta de serviço do projeto. Os dois
  podem ter
  `telefone` (opcional em `Usuario`, `temTelefone`): sem ele as telas escondem o botão
  de ligar para a pessoa. O campo é pedido (opcional) no cadastro e gravado só com os
  dígitos e o DDD (`normalizarTelefone`, em `telefone_service.dart`); contas criadas
  antes disso não têm onde cadastrar o telefone depois.
  O Paciente também guarda `metas` (map, `MetasPersonalizadas`) e `limiteLiquidoMl`
  (restrição de líquido do médico, perguntada só a cardiopatas). As `metas` saem da
  `CalculadoraMetas` (`domain/metas/`): fórmulas consagradas (Mifflin-St Jeor, OMS,
  Lipschitz para idosos ≥ 60 anos) e **sem IA**, para o resultado ser auditável e
  testável. São calculadas ao concluir a triagem e recalculadas em "Minhas metas →
  Atualizar meu peso"; `metas.ajustadaManualmente` marca quando o paciente mexeu em
  água/passos/exercício (as metas de alimentação não são editáveis no app). O cálculo
  devolve `null` se faltar dado (contas antigas): as telas caem nos padrões.
  O plano de refeições (RF03.4) fica em `refeicoes` (lista de `RefeicaoPlanejada`:
  `id`, `nome`, `itens`; cada item é `ItemRefeicao`: `alimentoId`, `nome`,
  `quantidadeG`). `null` = nunca personalizou → `Paciente.planoDeRefeicoes` cai em
  `RefeicoesPadrao` (4 refeições; 6 para diabéticos, sem alimentos); lista vazia = o
  paciente tirou todas. O `id` liga a refeição aos registros do dia, então não muda ao
  renomear. Os nutrientes de uma refeição (e do dia) saem do catálogo de alimentos:
  `quantidadeG / 100 × valores por 100 g`, somados (`Nutrientes`).
  O Paciente guarda também os `medicamentos` (RF003): lista de `Medicamento` (`id`,
  `nome`, `dose`, `horarios` em "HH:MM"); lista vazia = nenhum remédio. Cada horário de
  cada remédio é uma dose (`DosePlanejada`) que a rotina mostra para marcar; o `id` liga
  o remédio aos registros do dia, então não muda ao editar. Gravada por
  `PacienteRepository.salvarMedicamentos` (update só desse campo). O horário é escolhido
  no relógio do Flutter (`mostrarSeletorDeHorario`, em `ui/shared/`): só o relógio, sem o
  modo de digitar, sempre em 24 h, abrindo nas 08:00. Os textos prontos do Flutter saem em
  português porque o `MaterialApp` usa o `flutter_localizations` com o pt-BR fixo. O
  "Mudar horário" dos lembretes (glicemia e insulina) usa o mesmo relógio, aberto no
  horário de agora do aviso; escolher o horário padrão é o mesmo que voltar a ele, e o
  cartão só mostra "Voltar para 07:00" com o aviso fora do padrão.
  Os **limites de alerta** (RF 06.1, B8) ficam em `limitesAlerta` (map, `LimitesAlerta`:
  `bpmMinimo`, `bpmMaximo`, `atualizadoPor` = UID de quem ajustou, `atualizadoEm`).
  `null`/ausente = zona padrão (60 a 100, ou 60 a 90 para cardiopatas). Quem ajusta é o
  acompanhante, pelo botão "Limites de alerta" do card (`LimitesAlertaView`, Menos/Mais
  de 5 em 5); salvar os mesmos valores da zona padrão apaga o campo. Faixas aceitas:
  mínimo de 40 a 90, máximo de 80 a 150, ao menos 20 entre os dois — as mesmas no app
  (`LimitesAlerta.saoValidos`; fora delas o app ignora o campo) e nas rules
  (`limitesAlertaValidos`). Gravado por `DadosMedicosRepository.salvarLimitesAlerta`
  (update só desse campo) e lido em tempo real por `streamLimitesAlerta`. Toda conta de
  zona passa por `ZonaSegurancaCardiaca` com `limites:` (monitor de alertas com o app
  aberto e fechado, painel do paciente, card, tela de emergência e relatórios). O app
  aberto do paciente escuta o campo: limite novo faz a próxima leitura reler a janela e
  retomar o episódio com a zona nova (o mesmo da leitura com o app fechado, que relê o
  paciente a cada execução). Como o plano de refeições, os limites não têm histórico:
  os relatórios de dias antigos usam a zona de hoje.
- **Catálogo de alimentos**: `assets/alimentos/taco.json`, 593 alimentos da TACO 4ª
  edição (NEPA/UNICAMP, 2011; reprodução permitida citando a fonte — a tela de busca
  cita) com kcal, proteína, gordura, carboidrato, fibra e sódio por 100 g. Embutido no
  app (busca offline, nada do paciente sai do aparelho) e lido por
  `AlimentosRepository`. `alimentoId` = número do alimento na TACO. Como foi extraído e
  o que ficou de fora (4 alimentos "em reavaliação", como leite integral) está em
  `assets/alimentos/LEIAME.md`. Nunca editar valores à mão: regerar da fonte.
- `codigos_vinculo/{codigo}` — doc id = o código de 6 caracteres; campos `pacienteId`,
  `nomePaciente`. É o índice que o Acompanhante consulta (só `get`, sem `list`) para
  achar o paciente antes do vínculo existir. `PacienteRepository.salvarPaciente` grava
  os dois docs no mesmo batch.
- **Vínculo (RF05.4) é bidirecional e atômico**: `AcompanhanteRepository.vincularPaciente`
  faz `arrayUnion` nos dois lados num único batch. As rules só deixam o acompanhante
  tocar em `acompanhantesVinculadosIds` do paciente (e só para entrar/sair ele mesmo);
  um `arrayUnion` sem mudança é negado, por isso o ViewModel checa "já vinculado" antes.
  No mesmo molde, o acompanhante vinculado (dos dois lados) só pode mexer em
  `limitesAlerta` do paciente (`soAlteraLimitesDeAlerta`), com o próprio UID em
  `atualizadoPor`.
  O paciente pode dar `get` (sem `list`) no doc de um Acompanhante que tem o UID dele
  em `pacientesVinculadosIds` (`ehAcompanhanteDoUsuarioLogado`): é de onde vêm o nome e
  o telefone em "Falar com Acompanhante" (`listarAcompanhantesDoPaciente`).
- `registros_diarios` — todas as subclasses de `RegistroBase` (água, sono, exercício,
  diabete, refeição), discriminadas pelo campo `tipo` gravado no `toJson()` de cada uma.
  `RegistroRefeicao` (`tipo: 'refeicao'`, `refeicaoId`, `nome`) = "esta refeição foi
  feita hoje": marcar cria o doc, desmarcar apaga. O paciente não descreve o que comeu.
  `RegistroMedicacao` (`tipo: 'medicacao'`, `medicamentoId`, `horario`, `nome`, `dose`) =
  "esta dose foi tomada hoje", no mesmo esquema (marcar cria, desmarcar apaga; `dataHora`
  é quando marcou). `RegistroSono` (`tipo: 'sono'`): o paciente registra a noite ao
  acordar, então `dataHora` e `dataFim` guardam o mesmo instante (o do registro) e a noite
  conta no dia em que ele acordou, o que mantém as consultas por dia (e os índices) como
  nos outros tipos; um por dia, corrigido no mesmo documento (`atualizarRegistro`).
  `RegistroExercicio` (`tipo: 'exercicio'`, `tipoExercicio`, `duracaoMinutos`,
  `intensidade`): vários por dia; a meta é por semana (de domingo a sábado, como o
  calendário dos relatórios; 150 min por padrão, `Paciente.metaExercicioMinutosSemana`) e os
  minutos contam pelo valor de face, sem ponderar pela intensidade.
- `batimentos_cardiacos` — leituras de BPM com `pacienteId` + `timestamp`.
- **Relatórios (RF05)** não têm coleção própria: `RelatoriosRepository` só lê as
  coleções acima por período (`[início, fim)` no horário do aparelho) e
  `CalculadoraRelatorios` (`domain/relatorios/`) faz as contas, sem Firebase. As
  consultas têm o mesmo formato das do dia a dia (um tipo de `registros_diarios`
  por vez, mais `alertas` e `batimentos_cardiacos`), então **reaproveitam os índices
  que já existem — nenhum índice novo**. Quem lê é o paciente ou o acompanhante
  vinculado, pelas mesmas security rules (nada a mudar nelas). Regras de negócio:
  - "Dia completo" = meta de água batida + todas as refeições do plano marcadas + todas
    as doses de remédio tomadas (se o paciente tem remédios) + noite de sono registrada
    (basta registrar: quanto dormiu não deixa o dia incompleto) + (diabéticos) todos os
    itens do checklist de glicemia; "parcial" = tem registro mas falta algo; "sem
    registro" = nada da rotina anotado (BPM e alertas vêm do smartwatch, não contam como
    rotina). O exercício não entra na conta (a meta é da semana, e dia de descanso é
    normal), mas um dia só com exercício já conta como "tem registro". O relatório do dia
    mostra o progresso da semana de exercício até aquele dia
    (`RelatoriosRepository.exerciciosDaSemanaAte`); o do mês não.
  - O relatório do mês só conta os dias **já encerrados** (no mês atual, até ontem) e
    abre no mês anterior no dia 1. Ele **não lê as leituras de BPM** (podem ser
    dezenas de milhares por mês): só conta os alertas. O BPM detalhado (menor,
    maior, média, leituras fora da zona) é do relatório do dia, que lê as leituras
    de um dia só. Dessas leituras sai também a **curva do dia** (RF 04.3, Figura 17):
    `SerieDeBatimentos` reduz o dia (até ~2.900 leituras) a um ponto a cada 10 min (média,
    menor e maior) e `GraficoBatimentos` a desenha com a zona de segurança e um marcador
    por alerta; onde o relógio ficou mais de 1 h sem medir a linha para (buraco, não
    reta inventada).
  - As refeições e os nutrientes usam o plano **de hoje** (`Paciente.planoDeRefeicoes`):
    o plano não tem histórico, então mudar o plano muda a leitura dos dias antigos.
    A estimativa de nutrientes só aparece no relatório do dia. A lista de remédios
    (`Paciente.medicamentos`) vale igual: mudar os remédios muda a leitura dos dias
    antigos, e doses marcadas que já não estão na lista aparecem à parte.
- `alertas` — `pacienteId`, `tipo` (`'atencao'` | `'emergencia'` | `'pendencia'` |
  `'sem_dados'`), `mensagem`, `bpm`, `dataHora`, `lido`. `Alerta.ehDeBatimento` =
  atenção ou emergência: é o que o monitor de BPM e os relatórios contam (pendência e
  sem dados ficam de fora deles).
  O aviso de **sem dados do smartwatch** (B10) sai da mesma função agendada
  (`functions/sem_dados.js`): pela última leitura de `batimentos_cardiacos` do paciente
  (mesma consulta de `streamUltimoBatimento`), quando o tempo sem leitura nova, contado
  só das 7h às 22h no horário dele (`ZonaSegurancaCardiaca.prazoAvisoSemDados` = 3 h,
  `inicioDoDiaParaAviso`/`fimDoDiaParaAviso`), vence na última hora. Um aviso por
  período sem dados (id `sem_dados_{paciente}_{ms da última leitura}`), com
  `ultimaLeitura`; quem nunca mandou leitura não recebe aviso (não usa relógio). O card
  já mostra SEM DADOS depois de 1 h (`validadeDaLeitura`) e explica quando o aviso chega.
  A **pendência de atividade** (RF 06.3, B9) é criada pela Cloud Function agendada
  `verificarPendencias` (`functions/pendencias.js`, a cada 10 min, Cloud Scheduler):
  para cada paciente com acompanhante, lê `tarefasDiarias` e `fusoHorarioMinutos` do
  doc dele e, quando o horário-limite de uma tarefa (horário + 1 h,
  `PendenciaAtividade.tolerancia`) passou na última hora sem o registro do dia
  (`medicacao` com `medicamentoId` + `horario`, ou `diabete` do momento), cria o alerta
  com id fixo (`pendencia_{paciente}_{dia}_{hash da chave}`, então nunca repete), o
  horário-limite em `dataHora`, `bpm: null` e a tarefa em `tarefa`. O push sai pelo
  mesmo gatilho dos alertas de BPM (`nivel: 'pendencia'`, título "Pendência: [nome]",
  sem ser urgente). Os alertas de BPM são gerados pelo app do paciente na sincronização de BPM, com o app
  aberto (a cada 30 s) e com ele fechado (a cada 15 min, B7), pelas mesmas regras
  (`MonitorZonaSeguranca`, em `domain/batimentos/`):
  `atencao` quando o painel passa a mostrar "ATENÇÃO" (no máximo 1 a cada 15 min),
  `emergencia` com BPM fora da zona por 5 min. Doc sem `tipo` é tratado como emergência.
  Cada leitura retoma o episódio fora da zona pelas leituras e alertas das últimas 12 h
  (`getAlertasDesde`, mesmo índice de `streamAlertas`), então reabrir o app ou alternar
  entre as duas leituras não repete um alerta já dado.
  O acompanhante escuta em tempo real (`AlertasViewModel`) e mostra notificação local
  (`flutter_local_notifications`) com o app aberto ou em segundo plano. Com o app
  fechado, quem avisa é o **push (B6)**: a Cloud Function `notificarAlertaPaciente`
  (`functions/`, região `southamerica-east1`, a mesma do Firestore) dispara ao criar o
  doc, lê `acompanhantesVinculadosIds` do paciente e manda para os `fcmTokens` de cada
  acompanhante que também tem o paciente em `pacientesVinculadosIds` (o critério das
  rules), com prioridade alta; os tokens que o FCM recusa saem da lista. A mensagem só
  tem dados (`tipo: 'alerta_paciente'`, `alertaId`, `acompanhanteId`, `nivel`, `titulo`,
  `texto`, `dataHora`): quem mostra é o app (`receberPushEmSegundoPlano`, em
  `push_service.dart`), no canal `alertas_pacientes` e com o mesmo id da notificação da
  escuta (`idDaNotificacaoDoAlerta`), então o alerta aparece uma vez só. Só mostra se a
  conta logada no aparelho for a do `acompanhanteId`. Tocar abre `abrirDetalhesDoAlerta`
  (a tela de emergência), também com o app encerrado (`payloadQueAbriuOApp` +
  `AlertasViewModel.aguardarAlerta`). Sem tela cheia por cima do bloqueio: exigiria
  `USE_FULL_SCREEN_INTENT` e `showWhenLocked`, e com isso o app abriria com o celular
  bloqueado; fica a notificação de prioridade máxima. Sem o deploy da função (plano
  Blaze), tudo continua como antes, só sem o aviso com o app fechado.
- `localizacoes/{pacienteId}` — **um doc por paciente** (doc id = UID) com a última
  posição: `pacienteId`, `ativo`, `latitude`, `longitude`, `precisaoMetros`, `dataHora`.
  Cada envio sobrescreve o anterior (sem histórico do trajeto, NF005); desligar grava
  só `ativo: false`. Fora do documento do TCC — pedido da dupla. O paciente liga em
  Menu > Minha localização (`CompartilhamentoLocalizacaoViewModel`, `geolocator`,
  permissão "durante o uso"): envia a cada 1 min só com o app em primeiro plano. O
  acompanhante abre pelo botão "Ver localização" do card ou dos detalhes de um alerta de
  emergência (`ui/localizacao/`): endereço
  via `geocoding` e "Abrir no mapa" via `url_launcher` (link do Google Maps, sem chave).
- **Preferências do aparelho** não vão para o Firestore: `PreferenciasRepository`
  (`shared_preferences`, com `SharedPreferences.setMockInitialValues` nos testes) guarda,
  **por paciente**, se os lembretes estão ligados e os horários que ele escolheu para as
  medições de glicemia e a insulina lenta (a notificação agendada é daquele celular) e,
  **do aparelho todo**, o narrador de voz (ligado e velocidade). Os horários dos remédios,
  esses sim, ficam em `Paciente.medicamentos`.
- **Tarefas do dia para a pendência (RF 06.3, B9)**: o `LembretesViewModel` do
  paciente publica em `usuarios/{uid}` a `tarefasDiarias` (lista de `{chave, tipo,
  descricao, horario}`, os mesmos itens dos lembretes: `Lembrete.toJsonTarefa()`, com o
  horário da glicemia que o paciente escolheu) e o `fusoHorarioMinutos` do aparelho
  (`DadosMedicosRepository.salvarTarefasDiarias`, update só desses campos). Publica ao
  abrir o painel, quando os remédios ou os horários mudam e ao voltar ao app, só se a
  lista mudou; vale com os lembretes desligados. Sem a publicação (conta que ainda não
  abriu esta versão do app) a função não tem o que conferir; sem o fuso, usa o de
  Brasília. No aparelho, o aviso de pendência do paciente é uma notificação a mais do
  `PlanejadorDeLembretes` (`OcorrenciaDeLembrete.pendencia`, payload com
  `#pendencia`), no horário-limite, só para hoje e amanhã e fora do limite de 60 dos
  lembretes; some junto com o lembrete quando a tarefa é registrada. A que passaria da
  meia-noite (tarefa depois das 23h) fica só com o acompanhante.

Padrões dos models: classe abstrata (`Usuario`, `RegistroBase`) + subclasses;
`fromJson(Map, documentId)` factory + `toJson()`; campos com fallback (`?? ''`, `?? 0`).
Padrão dos repositories: construtor com `{FirebaseFirestore? firestore}` para injetar
`FakeFirebaseFirestore` nos testes — manter esse padrão em todo repository novo.

**Privacidade (NF005):** dados do paciente só podem ser lidos pelo acompanhante
vinculado — refletir isso nas security rules do Firestore quando forem escritas.

## Cronograma de desenvolvimento (seção 3.2 do TCC — seguir nesta ordem)

1. **Módulo de Identidade** — cadastro, login, recuperação de senha, seleção de perfil
   (RF001) e triagem de comorbidades (RF002). ← *cadastro (com telefone opcional), login,
   recuperação de senha (`RecuperarSenhaView`: o Firebase manda o link por e-mail; um
   e-mail sem conta recebe a mesma resposta, para não revelar quais contas existem) e
   triagem já feitos (`AuthRepository`, `ui/auth/`, `ui/triagem/`)*
2. **Módulo de Sincronização IoT** — integração com smartwatch via pacote `health`,
   leitura e histórico de BPM (RF004), validação da zona de segurança cardíaca
   ← *leitura a cada 30 s com o app aberto (`SincronizacaoBpmViewModel`). Leitura com o
   app fechado (RF04.2, B7) também feita, pela decisão do B2 (`docs/b2-bpm-app-fechado.md`:
   "viável só em alguns aparelhos"; falta confirmar com o protocolo no aparelho real):
   tarefa periódica do `workmanager` a cada 15 min (`sincronizarComAppFechado`, em
   `leitura_segundo_plano_service.dart`) que grava as leituras novas e gera os alertas. A
   permissão `READ_HEALTH_DATA_IN_BACKGROUND` do Health Connect é o liga/desliga: o cartão
   "COM O APP FECHADO" de "Meu smartwatch" (`CardLeituraAppFechado`) pede a permissão;
   concedida, o ViewModel agenda a tarefa (ao abrir e ao voltar ao app); tirada, ou sem o
   recurso no aparelho, desagenda. Com o app na tela a tarefa pula a vez (o ViewModel se
   anuncia pelo `IsolateNameServer`), para não gravar nem alertar em dobro, e ao voltar
   para o app ele relê a janela do Firestore. Sair da conta desliga a tarefa. O cartão de
   teste do B2 continua só com `fvm flutter run --dart-define=TESTE_B2=true` ("LER UMA VEZ
   EM SEGUNDO PLANO" roda mesmo com o app aberto). Com o Flutter 3.32 o `workmanager`
   precisa da `workmanager_platform_interface` fixa em 0.9.3 (ver `pubspec.yaml`)*
3. **Módulo de Rotina Diária** — checklists de água, sono, exercício, alimentação
   (RF003) e insulina/glicemia habilitado pela triagem (RF008). ← *tela "Minha Rotina"
   (`ui/rotina/`) com hidratação (RF03.1) já feita: meta do paciente em
   `Paciente.metas.hidratacaoMl` (padrão de 8 copos de 250 ml em `MetaHidratacao`
   para quem não tem metas), `+ Copo`/`- Copo` gravam/apagam `RegistroAgua`; o cartão
   "Refeições" (RF03.4) lista as refeições do plano para marcar "feito" e tem o botão
   "Personalizar refeições" (nome e alimentos com quantidade em g, escolhidos por
   busca no catálogo TACO; mostra calorias e macros da refeição e do dia contra as
   metas). Glicemia e
   insulina (RF008) também feitas (`ui/insulina/`): cartão resumido na Rotina só para
   `possuiDiabetes` (medições do dia + última glicemia fora da faixa) que abre a tela
   `GlicemiaInsulinaView` com o checklist dos momentos da E6 (`MomentoGlicemia`), em
   caixa alta para idosos + insulina lenta 22h para quem
   `usaInsulina`, "Outra medição" avulsa, faixas em `FaixasGlicemia` (alvo 70–180) e
   última glicemia/dose no card do acompanhante. `RegistroDiabete` tem `nivelGlicose`
   e `doseInsulina` opcionais (registro só de glicemia ou só de insulina). Padrão da
   Rotina para as próximas atividades: um cartão compacto por atividade; o que é de um
   toque (copo d'água, tomar remédio) resolve no próprio cartão, o que tem várias
   etapas abre tela própria. Sono (RF03.2), exercício (RF03.3) e medicação (RF003, Figura
   14) também feitos, cada um com cartão na Rotina, tela própria e cartão no relatório do
   dia. Sono: `CardSono` + `RegistrarSonoView` (horas de meia em meia hora e nota de 1 a 5;
   meta de `Paciente.metaSonoMinHoras`/`MaxHoras`). Exercício: `CardExercicio` (os de hoje,
   com "Apagar", e o progresso da meta semanal) + `RegistrarExercicioView` (tipo, minutos e
   intensidade em botões, sem digitar). Medicação: `CardMedicacao` (uma linha por dose, com
   caixa de seleção grande) + `MeusRemediosView` (nome, dose e horários, no molde de
   "Minhas refeições"). As telas de registro usam os widgets de `ui/shared/`
   (`PerguntaFormulario`, `ErroFormulario`, `BotaoSalvar`, `ContadorGrande`). Lembretes
   (RF 07.3) também feitos (`domain/lembretes/`, `ui/lembretes/`, menu > Meus lembretes):
   o `LembretesViewModel` (criado em `PacienteView.comProviders`, que o atualiza quando os
   remédios mudam) mantém **agendadas no aparelho** as notificações dos próximos 7 dias (no
   máximo 60, o limite do iOS é 64) de cada dose de remédio e, para diabéticos, das 4
   medições da E6 (07:00, 11:30, 18:00 e 21:30, que o paciente pode mudar) e da insulina
   lenta (22:00). Cada dia é uma notificação própria, e não uma repetição diária, porque o
   plugin no Android **ignora a data** de um agendamento repetido: assim o aviso de hoje
   some quando o paciente registra (do agendamento e da bandeja) sem apagar o de amanhã.
   Os ids vêm de um hash estável (`idDaNotificacao`) e o payload começa com `lembrete:`; os
   dias seguintes entram a cada abertura, registro ou mudança nos remédios e o plugin
   reagenda sozinho ao reiniciar o celular. O horário vira um instante em UTC (`tz.UTC`),
   então não depende do fuso do aparelho. O Android 12+ pede `SCHEDULE_EXACT_ALARM`: sem
   ele o aviso cai no modo aproximado (ainda toca, pode atrasar) e a tela oferece o botão.
   Sair da conta cancela os avisos. Conferido num emulador Android 16: toca com o processo
   morto, não toca o que já foi registrado e some da bandeja ao registrar (lido de
   `adb shell dumpsys alarm` e `dumpsys notification`). Falta sugerir/gerar os alimentos
   das refeições automaticamente a partir das metas. Cada atividade nova também precisa entrar
   nos relatórios: um tipo a mais em `RelatoriosRepository.registrosDoPeriodo`, um campo
   em `ResumoDoDia` (e no cálculo de "dia completo") e um cartão em
   `relatorio_dia_conteudo.dart`.
   A consulta do dia exige o índice composto de `registros_diarios` em
   `firestore.indexes.json` (publicar com `firebase deploy --only firestore:indexes`)*
4. **Módulo de Monitoramento** — painel do acompanhante, vínculo por código, alertas
   push em tempo real via FCM (RF005, RF006). ← *vínculo por código, lista de
   pacientes em cards e central de alertas em tempo real com notificação local
   (`ui/acompanhante/`, `ui/alertas/`) já feitos. Relatórios (`ui/relatorios/`) também
   feitos: "Ontem" (resumo da rotina do dia anterior) e "Mês" (calendário da rotina
   que abre o relatório de cada dia, com gráficos de água e glicemia; o do dia tem o
   gráfico de linha do BPM das 24 h, RF 04.3), a mesma tela
   para os dois perfis — o paciente abre pelo botão "Meus Relatórios" do painel e o
   acompanhante pelo botão "Ver relatórios" do card do paciente (só muda o título).
   BPM e status por card (RF05.1) também feitos: cada card tem o seu
   `StatusPacienteViewModel` (criado num `ChangeNotifierProvider` por card) com o BPM
   mais recente em tempo real, "há X min", o selo ESTÁVEL / ATENÇÃO / SEM DADOS (zona de
   `ZonaSegurancaCardiaca`; leitura com mais de `validadeDaLeitura` = 1 h vira SEM DADOS)
   e a última atividade da rotina (`DadosMedicosRepository.streamUltimaAtividade`, que
   exige o índice `registros_diarios` pacienteId + dataHora; cada tipo novo de registro
   precisa entrar em `_registroDoTipo` e em `descreverAtividade`). Tela de emergência
   (Figura 16) também feita: `abrirDetalhesDoAlerta` manda o alerta de emergência (pela
   notificação ou pela lista) para `EmergenciaView`, tela cheia vermelha com o BPM
   crítico e os botões "LIGAR PARA [NOME]" (só com telefone), "LIGAR PARA O SAMU (192)"
   e "VER LOCALIZAÇÃO"; o de atenção segue na folha de detalhes. Ligar = abrir o
   discador pelo link `tel:` (`TelefoneService`, fake nos testes; `BotaoLigar` em
   `ui/shared/`). O botão "Falar com Acompanhante" do painel do paciente (Figura 13)
   abre `FalarComAcompanhanteView` (`ui/paciente/`): cada acompanhante vinculado com
   "LIGAR PARA [NOME]" (ou "SEM TELEFONE CADASTRADO") e o atalho "LIGAR PARA O SAMU
   (192)" — dois toques do painel até o discador. Push com o app fechado (RF06.2, B6)
   também feito: `PushService` (`firebase_messaging` 16.2.2, a versão da mesma leva do
   `firebase_core` 4.9.0; fake nos testes), token em `usuarios/{uid}.fcmTokens` e a
   Cloud Function em `functions/` (ver `alertas` acima). Publicar com
   `firebase deploy --only functions` (plano Blaze, decisão D2). Limites de alerta pelo
   acompanhante (RF 06.1, B8) também feitos: botão "Limites de alerta" do card →
   `LimitesAlertaView` (ver `limitesAlerta` em `usuarios/{uid}`); exige publicar as rules
   (`firebase deploy --only firestore:rules`), com teste em `firestore_rules_test/`.
   Aviso de pendência de atividade (RF 06.3, B9) também feito: o paciente recebe o
   aviso no aparelho pelos lembretes do A7 e o acompanhante, o push da função agendada
   `verificarPendencias` (ver `alertas` e "Tarefas do dia" acima), que vai junto no
   `firebase deploy --only functions`. A pendência aparece em laranja ("PENDÊNCIA") na
   central de alertas e no card, com a orientação de lembrar o paciente. Aviso de "sem
   dados do smartwatch" (B10) também feito, na mesma função (ver `alertas` acima): é a
   rede de segurança para quando a leitura com o app fechado (B7) não funciona no
   aparelho ou o relógio ficou fora do pulso*
5. **Módulo de Acessibilidade** — narrador de texto com `flutter_tts`: ativar/desativar
   global, narrar conteúdo, ajustar velocidade (RF007) ← *configurações feitas
   (`ui/configuracoes/`, menu > Acessibilidade): liga/desliga o narrador, três velocidades
   em botões (`VelocidadeNarracao`: devagar, normal, rápido) e "Testar voz"; escolher a
   velocidade já fala um exemplo. A escolha vale para o aparelho todo
   (`PreferenciasRepository`) e a voz fica atrás do `TtsService` (`flutter_tts`, `pt-BR`),
   com fake nos testes; o Android 11+ exige `TTS_SERVICE` em `<queries>` no manifesto, e a
   tela avisa quando falta a voz em português. "Ouvir esta tela" (RF 08.2) também feito: o
   `BotaoOuvirTela` (`ui/shared/`) fica logo abaixo do título do painel, da rotina, dos
   relatórios (Ontem, Mês e o relatório de um dia) e da lista de notificações, e **lê um
   resumo curto**, escrito à mão para cada tela (`narracao_do_painel.dart`,
   `narracao_da_rotina.dart`, `narracao_dos_relatorios.dart`, `narracao_dos_alertas.dart`:
   funções puras, com teste que limita o tamanho do texto): o que importa agora e, na
   rotina, o que FALTA, e não a árvore de widgets nem o que já foi feito. Fala sem siglas
   ("batimentos por minuto", "miligramas por decilitro", o 192 como "um, nove, dois"). Na
   lista de notificações cada alerta fala a sua manchete (`mancheteDoAlerta`, a mesma da
   faixa do painel do acompanhante), e os batimentos só entram nos alertas de BPM
   (`Alerta.ehDeBatimento`): pendência de atividade e sem dados do smartwatch não são
   lidos como "atenção". Só
   aparece com o narrador ligado e **sem leitor de tela**: com o TalkBack ligado
   (`MediaQuery.accessibleNavigation`) o botão some e o narrador não fala, para as duas
   vozes não falarem juntas (`SemanticsService.announce` é obsoleto no Android, então
   não serve de alternativa); a tela de Acessibilidade explica isso. Vira "Parar de
   ouvir" enquanto fala (o `TtsService` avisa quando a fala começa e termina,
   `definirOuvinteDaFala`) e a leitura para sozinha quando a tela sai da frente, mas só
   se foi o próprio botão que a começou. Quem lê é o `ConfiguracoesViewModel`
   (`ouvir`/`pararDeOuvir`/`falando`), um só para o app todo; as telas abertas por cima do
   painel não herdam os providers dele, então `rotaComNarrador` (`ui/shared/`) leva o
   narrador junto. A tela de emergência (`EmergenciaView`) fala sozinha ao abrir
   (`falarAoAbrir`), com o narrador ligado. Falta testar a voz e o TalkBack num celular de
   verdade. O acompanhante ainda não tem onde ligar o narrador (o TCC define o narrador
   como recurso do Paciente): `AlertasView.rota(..., narrador:)` e `abrirDetalhesDoAlerta`
   já levam o narrador junto se o painel dele passar a tê-lo*

Nota prática: o módulo IoT depende de hardware físico (smartwatch pareado). Se o
dispositivo não estiver disponível quando chegar a vez dele, é aceitável adiantar o
Módulo de Rotina Diária (que só depende de Firestore) e voltar ao IoT depois — os dois
não dependem um do outro.

Regras de negócio importantes do documento:
- Triagem adapta a interface: módulo de insulina aparece só para diabéticos;
  cardiopatia ativa prioridade nos alertas de BPM (UC02).
- BPM fora da zona de segurança por tempo prolongado → alerta de emergência para
  paciente E acompanhante (UC04.4 → UC06). Tela de emergência oferece ligar para o
  paciente ou para o 192.
- Atividade não confirmada até o horário-limite → notificação de pendência para ambos.
- Horários de glicemia/insulina (entrevista E6): ao acordar, antes do almoço, antes do
  jantar e antes de dormir; insulina lenta tem horário fixo (22h). A entrevista só dá o
  "22h": os lembretes usam 07:00, 11:30, 18:00 e 21:30 para as medições
  (`MomentoGlicemia.horarioPadrao`) e o paciente muda em "Meus lembretes".

## Identidade visual

Paleta, tipografia, tamanhos e padrões de navegação estão em `GUIA_VISUAL.md` (raiz) —
seguir em toda tela nova. Resumo:

- Cores de marca: `Theme.of(context).colorScheme` (semente `AppCores.semente`).
  Estado/aviso: `AppCores.sucesso` / `aviso` / `perigo` (contraste ≥ 4,5:1).
  Nunca `Colors.green/red/orange` direto. Vermelho só para alerta de saúde e erro.
- Navegação do paciente: painel central + menu lateral aberto por botão "Menu"
  rotulado (`BotaoBarraSuperior`); subtelas com "Voltar" rotulado e `TituloTela`.
- Widgets prontos em `ui/shared/` (`BotaoGrande`, `CaixaAlerta`, `CardStatus`,
  `mostrarDialogoConfirmacao`...) antes de criar outro.

## Convenções de código

- **Tudo em português**: nomes de classes, campos, variáveis, testes e mensagens de UI
  seguem a nomenclatura do documento (Paciente, Acompanhante, RegistroAgua...).
- UI acessível para idosos em toda tela nova (NF004): botões grandes, fontes legíveis,
  alto contraste — é requisito do TCC, não estética opcional.
- Testes: `group('X Testes', ...)`, descrições em português ("Deve salvar e buscar...").
  Todo model e repository novo ganha teste correspondente espelhando o caminho em `test/`.
- Security rules: validar localmente antes de publicar com
  `firebase emulators:exec --only firestore --project demo-rules "<script>"` (projeto
  `demo-*` não toca no Firebase real). Publicar com `firebase deploy --only firestore:rules`.
  Regra nova ganha teste em `firestore_rules_test/` (o que deve passar e o que deve ser
  negado), rodado com `npm run test:emulador`.
- Commits em português, minúsculos, prefixo convencional (`feat:`, `chore:`, `fix:`),
  sem acentos — ex.: `feat: implementacao do modulo de identidade`.
