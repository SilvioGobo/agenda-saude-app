'use strict';

// Cloud Functions do Agenda Saude. Publicar com
// `firebase deploy --only functions` (exige o plano Blaze, decisao D2 do
// roteiro). Os testes rodam com `npm test`, sem o Firebase.

const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const { notificarAcompanhantes } = require('./notificacao');
const { verificarPacientes } = require('./verificacoes');

initializeApp();

// O Firestore do projeto fica em southamerica-east1 (Sao Paulo), e o gatilho
// do Firestore precisa rodar na mesma regiao do banco.
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 10 });

// B6 (RF006, RF06.2): o app do paciente grava um alerta (atencao ou
// emergencia) e os acompanhantes vinculados recebem o push em segundos, mesmo
// com o app fechado. Sem novas tentativas em caso de erro, para nao repetir
// a notificacao.
exports.notificarAlertaPaciente = onDocumentCreated(
  'alertas/{alertaId}',
  async (evento) => {
    const documento = evento.data;
    if (!documento) return;
    const alertaId = evento.params.alertaId;
    const totais = await notificarAcompanhantes({
      alertaId,
      alerta: documento.data(),
      firestore: getFirestore(),
      messaging: getMessaging(),
      logger,
    });
    logger.info('Push do alerta', { alertaId, ...totais });
  },
);

// B9 (RF 06.3) e B10: a cada 10 minutos, para cada paciente com acompanhante,
// cria o alerta de pendencia das tarefas do dia que passaram do horario-limite
// sem registro e o aviso de "sem dados" quando o smartwatch para de mandar BPM
// por 3 horas (contadas das 7h as 22h); o push sai pelo gatilho acima. Usa o
// Cloud Scheduler (plano Blaze). Sem novas tentativas: a proxima execucao
// confere de novo, e o id fixo de cada alerta impede aviso repetido.
exports.verificarPendencias = onSchedule(
  {
    schedule: 'every 10 minutes',
    timeZone: 'America/Sao_Paulo',
    retryCount: 0,
  },
  async () => {
    const totais = await verificarPacientes({
      firestore: getFirestore(),
      agoraMs: Date.now(),
      logger,
    });
    logger.info('Verificação das pendências', totais);
  },
);
