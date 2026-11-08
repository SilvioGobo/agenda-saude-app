'use strict';

// Push dos alertas de um paciente para os acompanhantes (B6, RF06.2). Fica
// separado do gatilho (index.js), com o Firestore e o FCM recebidos de fora,
// para os testes rodarem sem o Firebase (test/notificacao.test.js).

const { FieldValue } = require('firebase-admin/firestore');

// Valor do campo `tipo` dos dados do push. O app ignora outras mensagens
// (`AlertaPush.tipoDaMensagem`, em lib/core/services/push_service.dart).
const TIPO_DA_MENSAGEM = 'alerta_paciente';

// Respostas do FCM que querem dizer "este aparelho nao recebe mais" (app
// desinstalado, dados apagados, saiu da conta): o token sai da lista.
const CODIGOS_DE_TOKEN_INVALIDO = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

// Por quanto tempo o FCM tenta entregar a um celular desligado ou sem
// internet. Depois disso o alerta continua na central de alertas do app.
const VALIDADE_DO_PUSH_MS = 12 * 60 * 60 * 1000;

// O FCM aceita ate 4 KB de dados por mensagem.
const TAMANHO_MAXIMO_DO_TEXTO = 500;

function nomeDoPaciente(paciente) {
  const nome = typeof paciente?.nome === 'string' ? paciente.nome.trim() : '';
  return nome || 'Paciente';
}

// O nivel do alerta para o app: `atencao` e `emergencia` vem do BPM;
// `pendencia` e a tarefa do dia que passou do horario-limite (RF 06.3, ver
// pendencias.js) e `sem_dados`, o smartwatch que parou de mandar BPM (B10, ver
// sem_dados.js). Alerta sem `tipo` conta como emergencia, como no app
// (`Alerta.fromJson`).
function nivelDoAlerta(alerta) {
  if (alerta?.tipo === 'atencao') return 'atencao';
  if (alerta?.tipo === 'pendencia') return 'pendencia';
  if (alerta?.tipo === 'sem_dados') return 'sem_dados';
  return 'emergencia';
}

// Mesmo titulo da notificacao que o app mostra pela escuta em tempo real
// (`tituloDoAlerta`, em lib/ui/alertas/formato_alertas.dart), para nada mudar
// quando uma substitui a outra.
function tituloDoAlerta(alerta, nomePaciente) {
  switch (nivelDoAlerta(alerta)) {
    case 'atencao':
      return `Atenção: ${nomePaciente}`;
    case 'pendencia':
      return `Pendência: ${nomePaciente}`;
    case 'sem_dados':
      return `Sem dados do smartwatch: ${nomePaciente}`;
    default:
      return `Emergência: ${nomePaciente}`;
  }
}

const TEXTO_PADRAO = {
  pendencia: 'Atividade da rotina não registrada.',
  sem_dados: 'O smartwatch não envia medições há algumas horas.',
};

function textoDoAlerta(alerta) {
  const mensagem =
    typeof alerta?.mensagem === 'string' ? alerta.mensagem.trim() : '';
  const padrao =
    TEXTO_PADRAO[nivelDoAlerta(alerta)] ?? 'Batimentos fora da zona de segurança.';
  return (mensagem || padrao).slice(0, TAMANHO_MAXIMO_DO_TEXTO);
}

// `dataHora` chega do Firestore como Timestamp.
function emMilissegundos(dataHora) {
  if (dataHora && typeof dataHora.toMillis === 'function') {
    return dataHora.toMillis();
  }
  if (dataHora instanceof Date) return dataHora.getTime();
  return Date.now();
}

// Mensagem do FCM para os aparelhos de um acompanhante. No Android vai so com
// dados: quem mostra a notificacao e o app, no canal `alertas_pacientes`, com
// o mesmo id da notificacao da escuta (o alerta nao aparece duas vezes) e o
// toque abrindo a tela de emergencia. Prioridade alta para chegar na hora,
// mesmo com o celular em repouso. No iOS quem mostra e o sistema (`apns`).
function montarMensagem({
  alertaId,
  alerta,
  nomePaciente,
  acompanhanteId,
  tokens,
}) {
  const titulo = tituloDoAlerta(alerta, nomePaciente);
  const texto = textoDoAlerta(alerta);
  return {
    tokens,
    // O FCM so aceita texto nos dados.
    data: {
      tipo: TIPO_DA_MENSAGEM,
      alertaId,
      pacienteId: String(alerta?.pacienteId ?? ''),
      acompanhanteId,
      nivel: nivelDoAlerta(alerta),
      titulo,
      texto,
      dataHora: String(emMilissegundos(alerta?.dataHora)),
    },
    android: {
      priority: 'high',
      ttl: VALIDADE_DO_PUSH_MS,
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: { alert: { title: titulo, body: texto }, sound: 'default' },
      },
    },
  };
}

// Tokens que o FCM recusou como inexistentes. As respostas vem na mesma ordem
// dos tokens enviados.
function tokensInvalidos(tokens, resposta) {
  return resposta.responses.flatMap((envio, indice) =>
    !envio.success && CODIGOS_DE_TOKEN_INVALIDO.has(envio.error?.code)
      ? [tokens[indice]]
      : [],
  );
}

function lista(valor) {
  return Array.isArray(valor) ? valor : [];
}

// Manda o push de um alerta recem-criado para cada acompanhante vinculado ao
// paciente e tira da lista os tokens que nao valem mais. Retorna os totais,
// para o log da funcao.
async function notificarAcompanhantes({
  alertaId,
  alerta,
  firestore,
  messaging,
  logger = console,
}) {
  const totais = { acompanhantes: 0, enviados: 0, falhas: 0, tokensRemovidos: 0 };
  const pacienteId = alerta?.pacienteId;
  if (typeof pacienteId !== 'string' || pacienteId === '') {
    logger.warn('Alerta sem pacienteId: push não enviado', { alertaId });
    return totais;
  }

  const usuarios = firestore.collection('usuarios');
  const docPaciente = await usuarios.doc(pacienteId).get();
  if (!docPaciente.exists) {
    logger.warn('Paciente do alerta não existe: push não enviado', {
      alertaId,
      pacienteId,
    });
    return totais;
  }
  const paciente = docPaciente.data();
  const nomePaciente = nomeDoPaciente(paciente);
  const acompanhantesIds = [
    ...new Set(lista(paciente.acompanhantesVinculadosIds)),
  ];

  // Um acompanhante com problema (ex.: FCM fora do ar) nao impede os outros.
  const resultados = await Promise.allSettled(
    acompanhantesIds.map(async (acompanhanteId) => {
      const referencia = usuarios.doc(acompanhanteId);
      const doc = await referencia.get();
      if (!doc.exists) return null;
      const acompanhante = doc.data();

      // NF005: so recebe quem tambem tem o paciente na propria lista, o mesmo
      // criterio das security rules para ler os dados dele.
      if (!lista(acompanhante.pacientesVinculadosIds).includes(pacienteId)) {
        return null;
      }
      const tokens = [
        ...new Set(
          lista(acompanhante.fcmTokens).filter(
            (token) => typeof token === 'string' && token !== '',
          ),
        ),
      ];
      if (tokens.length === 0) {
        return { enviados: 0, falhas: 0, tokensRemovidos: 0 };
      }

      const resposta = await messaging.sendEachForMulticast(
        montarMensagem({
          alertaId,
          alerta,
          nomePaciente,
          acompanhanteId,
          tokens,
        }),
      );
      const invalidos = tokensInvalidos(tokens, resposta);
      if (invalidos.length > 0) {
        await referencia.update({
          fcmTokens: FieldValue.arrayRemove(...invalidos),
        });
      }
      return {
        enviados: resposta.successCount,
        falhas: resposta.failureCount,
        tokensRemovidos: invalidos.length,
      };
    }),
  );

  resultados.forEach((resultado, indice) => {
    if (resultado.status === 'rejected') {
      logger.error('Falha ao mandar o push para um acompanhante', {
        alertaId,
        acompanhanteId: acompanhantesIds[indice],
        erro: String(resultado.reason),
      });
      return;
    }
    const valor = resultado.value;
    if (valor === null) return;
    totais.acompanhantes += 1;
    totais.enviados += valor.enviados;
    totais.falhas += valor.falhas;
    totais.tokensRemovidos += valor.tokensRemovidos;
  });
  return totais;
}

module.exports = {
  TIPO_DA_MENSAGEM,
  VALIDADE_DO_PUSH_MS,
  montarMensagem,
  tokensInvalidos,
  notificarAcompanhantes,
};
