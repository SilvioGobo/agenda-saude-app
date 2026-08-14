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
- **Firebase (BaaS)**: Auth (login/cadastro), Cloud Firestore (dados + sync em tempo
  real), Cloud Messaging (notificações push). Projeto: `tcc-agenda-saude`
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
    services/       # tts_service, health_service, notification_service (wrappers de plugin)
  domain/models/    # já completo (ver abaixo)
  data/repositories/
    auth_repository.dart          # a criar: wrapper do FirebaseAuth (RF001)
    paciente_repository.dart      # existente
    acompanhante_repository.dart  # existente (vincular/desvincular paciente)
    dados_repository.dart         # existente: DadosMedicosRepository (registros, BPM, alertas)
  ui/
    auth/           # login, cadastro, seleção de perfil (arquivos criados, vazios)
    triagem/        # questionário adaptativo de comorbidades (RF002)
    paciente/       # painel principal: BPM em destaque, status, atalhos
    rotina/         # checklist diário: água, sono, exercício, alimentação (RF003)
    insulina/       # glicemia + insulina — só visível se possuiDiabetes (RF008)
    acompanhante/   # painel com cards dos pacientes vinculados (RF005)
    historico/      # gráficos e relatórios consolidados (RF005)
    alertas/        # tela de emergência (overlay vermelho) + lista de notificações (RF006)
    configuracoes/  # acessibilidade: ativar narrador, velocidade da fala (RF007)
    shared/         # widgets reutilizáveis acessíveis (BotaoGrande, CardStatus, etc.)
test/               # espelha lib/ (test/domain/models, test/data/repositories, test/ui)
integration_test/   # fluxos completos no emulador
```

## Modelo de dados (Firestore)

Convenções já estabelecidas nos repositories — manter:

- `usuarios/{uid}` — doc id = UID do Firebase Auth. Paciente e Acompanhante na mesma
  coleção, discriminados pelo campo `perfil` (`'Paciente'` | `'Acompanhante'`).
  Paciente tem `possuiDiabetes`, `possuiCardiopatia`, `codigoVinculo`;
  Acompanhante tem `pacientesVinculadosIds: List<String>`.
- `registros_diarios` — todas as subclasses de `RegistroBase` (água, sono, exercício,
  diabete), discriminadas pelo campo `tipo` gravado no `toJson()` de cada uma.
- `batimentos_cardiacos` — leituras de BPM com `pacienteId` + `timestamp`.
- `alertas` — `pacienteId`, `mensagem`, `dataHora`, `lido`.

Padrões dos models: classe abstrata (`Usuario`, `RegistroBase`) + subclasses;
`fromJson(Map, documentId)` factory + `toJson()`; campos com fallback (`?? ''`, `?? 0`).
Padrão dos repositories: construtor com `{FirebaseFirestore? firestore}` para injetar
`FakeFirebaseFirestore` nos testes — manter esse padrão em todo repository novo.

**Privacidade (NF005):** dados do paciente só podem ser lidos pelo acompanhante
vinculado — refletir isso nas security rules do Firestore quando forem escritas.

## Cronograma de desenvolvimento (seção 3.2 do TCC — seguir nesta ordem)

1. **Módulo de Identidade** — cadastro, login, recuperação de senha, seleção de perfil
   (RF001) e triagem de comorbidades (RF002). ← *próximo passo: AuthRepository,
   AuthViewModel e telas de auth/triagem*
2. **Módulo de Sincronização IoT** — integração com smartwatch via pacote `health`,
   leitura e histórico de BPM (RF004), validação da zona de segurança cardíaca
3. **Módulo de Rotina Diária** — checklists de água, sono, exercício, alimentação
   (RF003) e insulina/glicemia habilitado pela triagem (RF008)
4. **Módulo de Monitoramento** — painel do acompanhante, vínculo por código, alertas
   push em tempo real via FCM (RF005, RF006)
5. **Módulo de Acessibilidade** — narrador de texto com `flutter_tts`: ativar/desativar
   global, narrar conteúdo, ajustar velocidade (RF007)

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
  jantar e antes de dormir; insulina lenta tem horário fixo (22h).

## Convenções de código

- **Tudo em português**: nomes de classes, campos, variáveis, testes e mensagens de UI
  seguem a nomenclatura do documento (Paciente, Acompanhante, RegistroAgua...).
- UI acessível para idosos em toda tela nova (NF004): botões grandes, fontes legíveis,
  alto contraste — é requisito do TCC, não estética opcional.
- Testes: `group('X Testes', ...)`, descrições em português ("Deve salvar e buscar...").
  Todo model e repository novo ganha teste correspondente espelhando o caminho em `test/`.
- Commits em português, minúsculos, prefixo convencional (`feat:`, `chore:`, `fix:`),
  sem acentos — ex.: `feat: implementacao do modulo de identidade`.
