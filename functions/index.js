'use strict';

// Cloud Functions do Agenda Saude. Publicar com
// `firebase deploy --only functions` (exige o plano Blaze, decisao D2 do
// roteiro). Os testes rodam com `npm test`, sem o Firebase.

const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const { notificarAcompanhantes } = require('./notificacao');

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
