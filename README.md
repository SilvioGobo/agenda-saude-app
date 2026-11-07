# Agenda Saúde

[![CI](https://github.com/SilvioGobo/agenda-saude-app/actions/workflows/ci.yml/badge.svg)](https://github.com/SilvioGobo/agenda-saude-app/actions/workflows/ci.yml)

Aplicativo móvel em Flutter para o monitoramento preventivo de idosos e pessoas com
doenças crônicas (diabéticos e cardiopatas). Trabalho de Conclusão de Curso de
Engenharia de Software da UNIGRAN, de Gabriel Menegati e Silvio Daniel.

O app conecta dois perfis:

- **Paciente**: registra a rotina do dia (água, refeições, glicemia e insulina), vê as
  metas calculadas para ele e sincroniza os batimentos do smartwatch.
- **Acompanhante**: vincula os pacientes por um código de 6 caracteres, vê o estado de cada
  um em cards, recebe alertas em tempo real e consulta os relatórios.

A especificação completa (requisitos RF001–RF008, casos de uso, diagrama de classes e
mockups) está em [`TCC_1_FINAL - Gabriel Menegati_Silvio Daniel.pdf`](<TCC_1_FINAL - Gabriel Menegati_Silvio Daniel.pdf>).
Em caso de dúvida sobre comportamento ou escopo, o documento é a fonte da verdade.

## O que já funciona

| Módulo                | O que tem                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------ |
| Identidade            | Cadastro, login e escolha de perfil; triagem de comorbidades que adapta a interface (RF001, RF002) |
| Rotina diária         | Hidratação, plano de refeições com catálogo TACO, glicemia e insulina para diabéticos (RF003, RF008) |
| Metas                 | Metas de água, passos, exercício e alimentação calculadas por fórmulas consagradas, sem IA |
| Sincronização         | BPM do smartwatch pelo Health Connect e zona de segurança cardíaca (RF004)                 |
| Monitoramento         | Painel do acompanhante, vínculo por código, central de alertas, localização do paciente (RF005, RF006) |
| Relatórios            | Relatório do dia anterior e relatório mensal, para os dois perfis                          |

Ainda faltam recuperação de senha, sono, exercício, medicação, lembretes e o narrador de
texto (RF007).

## Como rodar

### O que instalar

- [Git](https://git-scm.com/)
- [FVM](https://fvm.app/documentation/getting-started/installation), que fixa o Flutter
  na versão do projeto (**3.32.8**, em `agenda_saude_app/.fvmrc`). A dupla usa a mesma
  versão, então **nunca use o `flutter` direto**: use sempre `fvm flutter`.
- Android Studio (ou só o Android SDK) e um celular Android ou um emulador. O app exige
  Android 8 ou mais novo (`minSdk 26`).
- Para publicar as rules e os índices do Firestore: [Node.js](https://nodejs.org/) e o
  Firebase CLI (`npm i -g firebase-tools`, depois `firebase login`).

### Passo a passo

```bash
git clone https://github.com/SilvioGobo/agenda-saude-app.git
cd agenda-saude-app/agenda_saude_app

fvm install            # baixa o Flutter da versão do .fvmrc
fvm flutter pub get    # baixa as dependências
fvm flutter run        # roda no aparelho ou emulador conectado
```

Se a IDE não achar o SDK, aponte para `agenda_saude_app/.fvm/flutter_sdk`, o atalho que o
`fvm install` cria na sua máquina. O `.vscode/settings.json` do repositório já faz isso
para o VS Code.

### Firebase

O projeto no Firebase se chama `tcc-agenda-saude`. A configuração do app já está no
repositório (`lib/firebase_options.dart` e `android/app/google-services.json`), então
não é preciso rodar o `flutterfire configure`: o app conecta ao projeto assim que abre. O
Firestore é o do projeto real, então use contas de teste.

Serviços usados: **Authentication** (e-mail e senha), **Cloud Firestore** (dados e
sincronização em tempo real), **Cloud Messaging** (push dos alertas para o acompanhante) e
**Cloud Functions** (a pasta `functions/`, que manda o push quando um alerta é criado).

Para publicar as rules e os índices (precisa de acesso ao projeto):

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

Para publicar as Cloud Functions (precisa do plano Blaze no projeto; o deploy roda os
testes antes):

```bash
cd functions
npm ci
cd ..
firebase deploy --only functions
```

Para testar as rules sem tocar no Firebase real, use o emulador com um projeto `demo-*`:

```bash
firebase emulators:exec --only firestore --project demo-rules "<seu script>"
```

### Smartwatch e Health Connect

O relógio não fala direto com o app. O aplicativo da marca (Samsung Health, Mi Fitness,
Zepp...) sincroniza os batimentos com o **Health Connect** do Android, e o Agenda Saúde lê
de lá. Sem relógio pareado, o painel do paciente mostra "Desconectado" e o resto do app
funciona normalmente.

### Testes

```bash
cd agenda_saude_app
fvm flutter analyze
fvm flutter test                                  # testes de unidade e de widget
fvm flutter test integration_test -d <aparelho>   # fluxo no aparelho ou emulador
```

## Arquitetura

**MVVM + Clean Architecture**. Cada tela tem uma `View` (só desenha) e um `ViewModel`
(`ChangeNotifier` entregue pelo `provider`). A lógica de negócio não depende de UI nem de
Firebase, e o Firebase só aparece nos repositories.

```
View  →  ViewModel  →  Repository  →  Firestore / Auth
              ↓
        domain (models e regras puras)
```

```
agenda_saude_app/
  lib/
    main.dart               # inicia o Firebase e abre o app
    firebase_options.dart   # gerado pelo flutterfire (não editar à mão)
    core/
      theme/                # tema Material 3 e cores do app (AppCores)
      constants/            # zona de segurança de BPM, meta de água, faixas de glicemia
      services/             # wrappers de plugin: Health Connect, GPS, mapa, notificações
    domain/
      models/               # entidades do diagrama de classes
      metas/ refeicoes/ alimentos/ relatorios/   # regras de negócio, sem Firebase
    data/repositories/      # acesso ao Firestore e ao Auth
    ui/<feature>/           # <feature>_view.dart + <feature>_viewmodel.dart
  test/                     # espelha o lib/
  integration_test/         # fluxos completos no aparelho
```

Os repositories recebem o `FirebaseFirestore` no construtor, então os testes usam o
`FakeFirebaseFirestore` no lugar do Firestore real.

### Dados no Firestore

| Coleção                  | Conteúdo                                                                     |
| ------------------------ | ---------------------------------------------------------------------------- |
| `usuarios/{uid}`         | Paciente e Acompanhante, separados pelo campo `perfil`                       |
| `codigos_vinculo/{cod}`  | Índice para o acompanhante achar o paciente pelo código de 6 caracteres      |
| `registros_diarios`      | Água, sono, exercício, glicemia/insulina e refeições, separados pelo campo `tipo` |
| `batimentos_cardiacos`   | Leituras de BPM                                                              |
| `alertas`                | Alertas de atenção e de emergência                                           |
| `localizacoes/{uid}`     | Última posição do paciente, um documento por paciente                        |

O paciente só é lido pelo acompanhante vinculado (NF005); isso está em `firestore.rules`.
O detalhe de cada campo e as regras de negócio estão no [`CLAUDE.md`](CLAUDE.md).

## Telas

Os prints ficam em [`docs/prints/`](docs/prints/).

## Padrões do projeto

- Visual: [`GUIA_VISUAL.md`](GUIA_VISUAL.md) (cores, tamanhos e padrões de tela). O público
  é idoso, então fonte grande, botão grande e contraste alto são requisito (NF004). Use
  `AppCores.sucesso`, `aviso` e `perigo`, nunca `Colors.green`, `red` ou `orange`.
- Código, testes e mensagens de UI em português.
- Commits em português, minúsculos e com prefixo convencional, sem acento:
  `feat: implementacao do modulo de identidade`, `fix: ...`, `chore: ...`.
- Todo model e repository novo ganha teste espelhando o caminho em `test/`.

## Licença

Veja o arquivo [`LICENSE`](LICENSE).
