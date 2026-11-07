'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

const {
  TIPO_DA_MENSAGEM,
  VALIDADE_DO_PUSH_MS,
  montarMensagem,
  tokensInvalidos,
  notificarAcompanhantes,
} = require('../notificacao');

const medidoEm = new Date('2026-11-07T13:30:00Z');

function alertaDeEmergencia(campos = {}) {
  return {
    pacienteId: 'paciente_01',
    tipo: 'emergencia',
    mensagem:
      'Batimentos fora da zona de segurança há 6 minutos (última leitura: 128 BPM).',
    bpm: 128,
    dataHora: Timestamp.fromDate(medidoEm),
    lido: false,
    ...campos,
  };
}

// Firestore falso: so o que a funcao usa (`collection().doc().get/update`).
function criarFirestoreFalso(documentos) {
  const atualizacoes = [];
  return {
    atualizacoes,
    collection(colecao) {
      return {
        doc(id) {
          const caminho = `${colecao}/${id}`;
          return {
            async get() {
              const dados = documentos[caminho];
              return { exists: dados !== undefined, data: () => dados };
            },
            async update(campos) {
              atualizacoes.push({ caminho, campos });
            },
          };
        },
      };
    },
  };
}

// FCM falso: guarda as mensagens e responde com erro para os tokens listados.
function criarMessagingFalso(errosPorToken = {}, { falharPara = [] } = {}) {
  const mensagens = [];
  return {
    mensagens,
    async sendEachForMulticast(mensagem) {
      mensagens.push(mensagem);
      if (mensagem.tokens.some((token) => falharPara.includes(token))) {
        throw new Error('FCM fora do ar');
      }
      const responses = mensagem.tokens.map((token) =>
        errosPorToken[token]
          ? { success: false, error: { code: errosPorToken[token] } }
          : { success: true, messageId: `msg_${token}` },
      );
      const successCount = responses.filter((r) => r.success).length;
      return {
        responses,
        successCount,
        failureCount: responses.length - successCount,
      };
    },
  };
}

const loggerMudo = { info() {}, warn() {}, error() {} };

function pacienteJose(campos = {}) {
  return {
    nome: '  José Silva ',
    perfil: 'Paciente',
    acompanhantesVinculadosIds: ['cuidador_01'],
    ...campos,
  };
}

function acompanhante(campos = {}) {
  return {
    nome: 'Carlos Souza',
    perfil: 'Acompanhante',
    pacientesVinculadosIds: ['paciente_01'],
    fcmTokens: ['token_celular'],
    ...campos,
  };
}

describe('montarMensagem Testes', () => {
  it('Deve montar o push de emergência só com dados, prioridade alta e validade', () => {
    const mensagem = montarMensagem({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      nomePaciente: 'José Silva',
      acompanhanteId: 'cuidador_01',
      tokens: ['token_celular'],
    });

    assert.deepEqual(mensagem.tokens, ['token_celular']);
    assert.deepEqual(mensagem.data, {
      tipo: TIPO_DA_MENSAGEM,
      alertaId: 'alerta_01',
      pacienteId: 'paciente_01',
      acompanhanteId: 'cuidador_01',
      nivel: 'emergencia',
      titulo: 'Emergência: José Silva',
      texto:
        'Batimentos fora da zona de segurança há 6 minutos (última leitura: 128 BPM).',
      dataHora: String(medidoEm.getTime()),
    });
    // Sem o bloco `notification`: no Android quem mostra e o app.
    assert.equal(mensagem.notification, undefined);
    assert.equal(mensagem.android.priority, 'high');
    assert.equal(mensagem.android.ttl, VALIDADE_DO_PUSH_MS);
    assert.equal(mensagem.apns.payload.aps.alert.title, 'Emergência: José Silva');
  });

  it('Deve montar o push de "Atenção" com o título do app', () => {
    const mensagem = montarMensagem({
      alertaId: 'alerta_02',
      alerta: alertaDeEmergencia({
        tipo: 'atencao',
        mensagem: 'Batimentos acima da zona de segurança (118 BPM).',
      }),
      nomePaciente: 'José Silva',
      acompanhanteId: 'cuidador_01',
      tokens: ['token_celular'],
    });

    assert.equal(mensagem.data.nivel, 'atencao');
    assert.equal(mensagem.data.titulo, 'Atenção: José Silva');
  });

  it('Deve tratar o alerta sem tipo como emergência e encurtar texto longo', () => {
    const alerta = alertaDeEmergencia({ mensagem: 'x'.repeat(5000) });
    delete alerta.tipo;

    const mensagem = montarMensagem({
      alertaId: 'alerta_03',
      alerta,
      nomePaciente: 'José Silva',
      acompanhanteId: 'cuidador_01',
      tokens: ['token_celular'],
    });

    assert.equal(mensagem.data.nivel, 'emergencia');
    assert.equal(mensagem.data.texto.length, 500);
    // Todos os valores dos dados sao texto, como o FCM exige.
    for (const valor of Object.values(mensagem.data)) {
      assert.equal(typeof valor, 'string');
    }
  });
});

describe('tokensInvalidos Testes', () => {
  it('Deve apontar só os tokens que o FCM diz não existirem mais', () => {
    const tokens = ['ok', 'desinstalado', 'malformado', 'instavel'];
    const resposta = {
      responses: [
        { success: true },
        { success: false, error: { code: 'messaging/registration-token-not-registered' } },
        { success: false, error: { code: 'messaging/invalid-registration-token' } },
        { success: false, error: { code: 'messaging/internal-error' } },
      ],
    };

    assert.deepEqual(tokensInvalidos(tokens, resposta), ['desinstalado', 'malformado']);
  });
});

describe('notificarAcompanhantes Testes', () => {
  it('Deve mandar o push para cada aparelho do acompanhante vinculado', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'usuarios/cuidador_01': acompanhante({
        fcmTokens: ['token_celular', 'token_tablet', 'token_celular'],
      }),
    });
    const messaging = criarMessagingFalso();

    const totais = await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      firestore,
      messaging,
      logger: loggerMudo,
    });

    assert.deepEqual(totais, {
      acompanhantes: 1,
      enviados: 2,
      falhas: 0,
      tokensRemovidos: 0,
    });
    const mensagem = messaging.mensagens[0];
    assert.deepEqual(mensagem.tokens, ['token_celular', 'token_tablet']);
    assert.equal(mensagem.data.titulo, 'Emergência: José Silva');
    assert.equal(mensagem.data.acompanhanteId, 'cuidador_01');
    assert.deepEqual(firestore.atualizacoes, []);
  });

  it('Deve mandar uma mensagem por acompanhante, com o id de quem recebe', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose({
        acompanhantesVinculadosIds: ['cuidador_01', 'cuidador_02'],
      }),
      'usuarios/cuidador_01': acompanhante(),
      'usuarios/cuidador_02': acompanhante({ fcmTokens: ['token_filha'] }),
    });
    const messaging = criarMessagingFalso();

    const totais = await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      firestore,
      messaging,
      logger: loggerMudo,
    });

    assert.equal(totais.acompanhantes, 2);
    assert.deepEqual(
      messaging.mensagens.map((m) => [m.data.acompanhanteId, m.tokens]).sort(),
      [
        ['cuidador_01', ['token_celular']],
        ['cuidador_02', ['token_filha']],
      ],
    );
  });

  it('Deve tirar da lista os tokens de aparelhos que não recebem mais', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'usuarios/cuidador_01': acompanhante({
        fcmTokens: ['token_celular', 'token_desinstalado'],
      }),
    });
    const messaging = criarMessagingFalso({
      token_desinstalado: 'messaging/registration-token-not-registered',
    });

    const totais = await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      firestore,
      messaging,
      logger: loggerMudo,
    });

    assert.equal(totais.enviados, 1);
    assert.equal(totais.tokensRemovidos, 1);
    assert.equal(firestore.atualizacoes.length, 1);
    const { caminho, campos } = firestore.atualizacoes[0];
    assert.equal(caminho, 'usuarios/cuidador_01');
    assert.ok(campos.fcmTokens.isEqual(FieldValue.arrayRemove('token_desinstalado')));
  });

  it('Não deve mandar para quem não tem mais o paciente na própria lista (NF005)', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'usuarios/cuidador_01': acompanhante({ pacientesVinculadosIds: [] }),
    });
    const messaging = criarMessagingFalso();

    const totais = await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      firestore,
      messaging,
      logger: loggerMudo,
    });

    assert.equal(totais.acompanhantes, 0);
    assert.deepEqual(messaging.mensagens, []);
  });

  it('Não deve mandar nada para acompanhante sem aparelho registrado ou apagado', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose({
        acompanhantesVinculadosIds: ['cuidador_01', 'cuidador_apagado'],
      }),
      'usuarios/cuidador_01': acompanhante({ fcmTokens: [] }),
    });
    const messaging = criarMessagingFalso();

    const totais = await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      firestore,
      messaging,
      logger: loggerMudo,
    });

    assert.deepEqual(totais, {
      acompanhantes: 1,
      enviados: 0,
      falhas: 0,
      tokensRemovidos: 0,
    });
    assert.deepEqual(messaging.mensagens, []);
  });

  it('Não deve mandar nada para alerta sem paciente ou de paciente que não existe', async () => {
    const firestore = criarFirestoreFalso({});
    const messaging = criarMessagingFalso();

    await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia({ pacienteId: undefined }),
      firestore,
      messaging,
      logger: loggerMudo,
    });
    await notificarAcompanhantes({
      alertaId: 'alerta_02',
      alerta: alertaDeEmergencia({ pacienteId: 'nao_existe' }),
      firestore,
      messaging,
      logger: loggerMudo,
    });

    assert.deepEqual(messaging.mensagens, []);
  });

  it('Deve continuar mandando para os outros quando o envio de um falha', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose({
        acompanhantesVinculadosIds: ['cuidador_01', 'cuidador_02'],
      }),
      'usuarios/cuidador_01': acompanhante({ fcmTokens: ['token_com_falha'] }),
      'usuarios/cuidador_02': acompanhante({ fcmTokens: ['token_filha'] }),
    });
    const messaging = criarMessagingFalso({}, { falharPara: ['token_com_falha'] });
    const erros = [];

    const totais = await notificarAcompanhantes({
      alertaId: 'alerta_01',
      alerta: alertaDeEmergencia(),
      firestore,
      messaging,
      logger: { ...loggerMudo, error: (texto, dados) => erros.push(dados) },
    });

    assert.equal(totais.acompanhantes, 1);
    assert.equal(totais.enviados, 1);
    assert.equal(erros.length, 1);
    assert.equal(erros[0].acompanhanteId, 'cuidador_01');
  });
});
