# B2 — BPM com o app fechado (RF 04.2)

Teste da Sprint 1 (Pessoa B). Pergunta: o app consegue continuar lendo o BPM do
smartwatch com o app fechado? A resposta define o **B7** (implementar a leitura com o
app fechado) e o **B10** (aviso de "sem dados do smartwatch").

## Como é hoje

`SincronizacaoBpmViewModel` lê o Health Connect a cada 30 s **só com o app em primeiro
plano**: ao sair da tela (`didChangeAppLifecycleState`) o timer para, porque o Health
Connect recusa a leitura de um app em segundo plano sem permissão extra.

## O que a documentação e o código mostram

| Ponto | O que vale |
| --- | --- |
| Restrição padrão | O Health Connect só deixa ler com o app em primeiro plano. |
| Permissão extra | Para ler em segundo plano o app declara `android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND` e o usuário concede à parte, além da de ler o BPM. |
| Depende do aparelho | O recurso depende da versão do Health Connect instalada: é preciso checar `FEATURE_READ_HEALTH_DATA_IN_BACKGROUND` antes. A documentação não fixa versão mínima. |
| Pacote `health` 13.3.1 (o do projeto) | Já tem `isHealthDataInBackgroundAvailable()`, `isHealthDataInBackgroundAuthorized()` e `requestHealthDataInBackgroundAuthorization()`. A leitura usa o contexto da aplicação, então roda no isolate do WorkManager, sem tela. |
| WorkManager | Tarefa periódica a cada **15 min no mínimo** (regra do Android). A economia de bateria pode atrasar ou pular execuções. É o caminho que o exemplo oficial do Health Connect usa para ler em segundo plano. |
| Serviço em primeiro plano | A documentação **não diz** que um serviço em primeiro plano conta como "app em primeiro plano" para o Health Connect; só o recomenda para uma leitura já começada não ser interrompida. No Android 14 o serviço do tipo `health` ainda exige permissões próprias e notificação fixa. Por isso o teste usa WorkManager. |
| Cotas | A leitura em segundo plano tem limite de chamadas mais restrito que em primeiro plano (sem números publicados). Uma leitura a cada 15 min fica longe disso. |
| O relógio | O relógio não fala direto com o app: o app da marca (Samsung Health, Mi Fitness, Zepp...) grava no Health Connect no ritmo dele. Esse atraso soma com os 15 min. |

## O que esta branch traz para o teste

- Permissão `READ_HEALTH_DATA_IN_BACKGROUND` no `AndroidManifest.xml`.
- `HealthService` com três métodos novos (recurso disponível, permissão concedida, pedir
  permissão), com fake nos testes.
- `core/services/leitura_segundo_plano_service.dart`: tarefa periódica do WorkManager
  (`workmanager` 0.9.2, a última que resolve com o Flutter 3.32.8), a cada 15 min e só
  com internet. Ela lê as últimas 12 h do Health Connect e grava em
  `batimentos_cardiacos` só as leituras novas (mesmo critério do app aberto). O
  resultado vai para o log: `BPM em segundo plano: N leituras novas` ou `... falhou`.
  Na Sprint 2 a tarefa passou a gerar os alertas também (B7, seção abaixo).
- Cartão **TESTE B2** na tela "Meu smartwatch", que só aparece rodando com
  `--dart-define=TESTE_B2=true` (o paciente nunca vê): mostra se o recurso existe, se a
  permissão foi dada e se a leitura está ligada, com os botões para cada passo.

## Protocolo no aparelho real

Precisa do celular do paciente com o relógio pareado (o app da marca sincronizando com
o Health Connect) e do celular do acompanhante com o paciente vinculado.

1. Celular do paciente no USB: `fvm flutter run --dart-define=TESTE_B2=true`. Em outro
   terminal, deixe `fvm flutter logs` aberto.
2. Entre como paciente. Menu > Meu smartwatch > cartão **TESTE B2**. Anote "Recurso no
   Health Connect". Se der INDISPONÍVEL, atualize o Health Connect pela Play Store e
   toque em VERIFICAR DE NOVO. Se continuar indisponível, este aparelho não suporta:
   anote e pule para a decisão.
3. PEDIR PERMISSÃO e conceda o acesso em segundo plano na tela do Health Connect.
4. LER UMA VEZ EM SEGUNDO PLANO. No log deve aparecer `BPM em segundo plano: ...`.
   "falhou" com erro de segurança = a permissão não valeu.
5. LIGAR LEITURA A CADA 15 MIN. Feche o app (tire dos recentes) e use o relógio por 45
   a 60 min.
6. No celular do acompanhante, deixe o painel aberto: o card do paciente (B3) mostra o
   BPM e o "há X min". Anote a hora de cada mudança com o app do paciente fechado.
7. Repita o passo 6 com a tela do paciente bloqueada e com a economia de bateria ligada.
8. Preencha a tabela abaixo e toque em DESLIGAR LEITURA no fim.

## Resultado (preencher no teste)

| Aparelho e Android | Health Connect (versão) | Relógio e app da marca | Recurso disponível? | Permissão concedida? | Leitura chegou com o app fechado? | Atraso medição → card | Observações |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |

## Decisão

**Preliminar, pela documentação e pelo código; confirmar com o protocolo acima.**
A leitura do BPM com o app fechado é **viável só em alguns aparelhos**. Ela depende de
quatro coisas fora do controle do app: o recurso de leitura em segundo plano existir na
versão do Health Connect do aparelho, o usuário conceder a permissão extra, o Android
deixar a tarefa rodar (no mínimo a cada 15 min, e mais espaçada com economia de
bateria) e o app da marca do relógio gravar no Health Connect com o celular em repouso.
Por isso o **B7** implementa a leitura periódica de 15 min com os alertas de atenção e
emergência onde o recurso existir, e mantém a leitura de 30 s com o app aberto. O
**B10** passa a ser obrigatório, porque nos aparelhos sem o recurso, ou com a bateria
segurando a tarefa, haverá horas sem dado. O texto do TCC (D5) deve trocar "coleta
contínua" por "a cada 30 s com o app aberto e a cada 15 min com o app fechado, onde o
Health Connect permitir". Se no aparelho do teste nenhuma leitura chegar com o app
fechado mesmo com recurso e permissão, a decisão vira **inviável**: o B7 sai do
roteiro, o B10 continua obrigatório e o texto do TCC passa a dizer só "com o app
aberto".

## B7 — o que entrou (Sprint 2)

Implementado pela decisão preliminar ("viável só em alguns aparelhos"). O protocolo
acima ainda precisa rodar no aparelho real para confirmar.

- **Alertas com o app fechado**: a tarefa de 15 min (`sincronizarComAppFechado`) grava as
  leituras novas e gera os alertas de atenção e emergência com as mesmas regras do app
  aberto, que saíram do `SincronizacaoBpmViewModel` para `MonitorZonaSeguranca`
  (`lib/domain/batimentos/`). Cada execução começa do zero, então o monitor retoma o
  episódio fora da zona pelas leituras e alertas das últimas 12 h: um episódio que
  atravessa duas execuções gera uma emergência só, e a emergência sai no tempo certo
  mesmo se o começo do episódio foi lido na execução anterior. O alerta vira push para o
  acompanhante pelo B6.
- **Liga/desliga pelo paciente**: cartão **COM O APP FECHADO** em Menu > Meu smartwatch.
  Mostra LIGADA, DESLIGADA (com o botão PERMITIR LEITURA COM O APP FECHADO) ou NÃO FUNCIONA
  NESTE CELULAR. A permissão do Health Connect manda: concedida, a tarefa fica agendada;
  tirada nas configurações do Health Connect, ela sai na próxima vez que o app abrir.
  Sair da conta também desliga.
- **Sem dobrar com o app aberto**: enquanto o app está na tela (lendo a cada 30 s), a
  tarefa pula a vez. Ao voltar para o app, ele relê as leituras e os alertas do Firestore,
  para não regravar o que a tarefa gravou.
- O cartão TESTE B2 continua (só com `--dart-define=TESTE_B2=true`). O passo 5 do
  protocolo agora acontece sozinho ao conceder a permissão; "LER UMA VEZ EM SEGUNDO
  PLANO" roda mesmo com o app aberto, e o log mostra `BPM em segundo plano: N leituras
  novas, M alertas`.

Para conferir o alerta no aparelho: conceda a permissão, feche o app do paciente, meça
fora da zona por mais de 5 min (ou aguarde uma leitura fora da zona) e espere a próxima
execução. Com a função do B6 publicada, o celular do acompanhante recebe o push mesmo
com o app dele fechado.

## Fontes

- [Health Connect: Read raw data](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data)
  (permissão e checagem do recurso de leitura em segundo plano, exemplo com WorkManager)
- [Health Connect: Review Health Connect functionality](https://developer.android.com/health-and-fitness/guides/health-connect/plan/developer-functionality)
  (leitura só em primeiro plano, serviço em primeiro plano)
- [Health Connect: Rate limiting](https://developer.android.com/health-and-fitness/guides/health-connect/plan/rate-limiting)
  (cota mais restrita em segundo plano)
- [Health Connect: Sync data](https://developer.android.com/guide/health-and-fitness/health-connect/develop/sync-data)
  (o app não é avisado de dado novo)
- Pacote `health` 13.3.1: README, seção "Android: Reading Health Data in Background", e
  `HealthDataOperations.kt`
- [Pacote `workmanager`](https://pub.dev/packages/workmanager)
