'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');

const {
  idDoAlertaSemDados,
  mensagemSemDados,
  prazoDoAvisoSemDados,
} = require('../sem_dados');
const { verificarPacientes } = require('../verificacoes');
const { criarFirestoreFalso } = require('./firestore_falso');

// O paciente mora em Campo Grande (UTC-4), como o app publica.
const FUSO_CAMPO_GRANDE = -240;

// Instante de um horario de Campo Grande ("2026-11-08T09:05").
function emCampoGrande(dataHora) {
  return Date.parse(`${dataHora}:00-04:00`);
}

function pacienteJose(campos = {}) {
  return {
    nome: 'José Silva',
    perfil: 'Paciente',
    acompanhantesVinculadosIds: ['cuidador_01'],
    fusoHorarioMinutos: FUSO_CAMPO_GRANDE,
    ...campos,
  };
}

function leitura(dataHora, bpm = 72) {
  return {
    pacienteId: 'paciente_01',
    bpm,
    timestamp: Timestamp.fromMillis(emCampoGrande(dataHora)),
  };
}

const loggerMudo = { info() {}, warn() {}, error() {} };

function verificarAs(firestore, dataHora) {
  return verificarPacientes({
    firestore,
    agoraMs: emCampoGrande(dataHora),
    logger: loggerMudo,
  });
}

describe('Sem dados do smartwatch: regras Testes', () => {
  const prazoDepoisDe = (dataHora) =>
    prazoDoAvisoSemDados(emCampoGrande(dataHora), FUSO_CAMPO_GRANDE);

  it('Deve vencer 3 horas depois da última leitura durante o dia', () => {
    assert.equal(prazoDepoisDe('2026-11-08T10:00'), emCampoGrande('2026-11-08T13:00'));
    assert.equal(prazoDepoisDe('2026-11-08T19:00'), emCampoGrande('2026-11-08T22:00'));
  });

  it('Não deve contar a noite: o relógio tirado às 21h vence às 9h do dia seguinte', () => {
    // 21h as 22h conta 1 hora; as outras 2 horas, das 7h as 9h.
    assert.equal(prazoDepoisDe('2026-11-08T21:00'), emCampoGrande('2026-11-09T09:00'));
    assert.equal(prazoDepoisDe('2026-11-08T23:30'), emCampoGrande('2026-11-09T10:00'));
  });

  it('A leitura de madrugada só começa a contar às 7h', () => {
    assert.equal(prazoDepoisDe('2026-11-08T02:00'), emCampoGrande('2026-11-08T10:00'));
  });

  it('Deve escrever desde quando, no horário do paciente', () => {
    const mensagem = (ultima, agora) =>
      mensagemSemDados({
        ultimaLeituraMs: emCampoGrande(ultima),
        fusoMinutos: FUSO_CAMPO_GRANDE,
        agoraMs: emCampoGrande(agora),
        paciente: pacienteJose(),
      });

    assert.equal(
      mensagem('2026-11-08T10:15', '2026-11-08T13:20'),
      'O smartwatch não envia medições desde as 10:15. Peça a José para abrir o '
        + 'Agenda Saúde com o relógio no pulso.',
    );
    assert.match(mensagem('2026-11-07T21:40', '2026-11-08T09:00'), /desde ontem às 21:40/);
    assert.match(mensagem('2026-11-05T21:40', '2026-11-08T09:00'), /desde 05\/11 às 21:40/);
  });
});

describe('verificarPacientes (B10) Testes', () => {
  it('Deve avisar quando o smartwatch passa 3 horas do dia sem mandar medições', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'batimentos_cardiacos/b1': leitura('2026-11-08T09:00', 70),
      'batimentos_cardiacos/b2': leitura('2026-11-08T10:15', 74),
    });

    const totais = await verificarAs(firestore, '2026-11-08T13:20');

    assert.deepEqual(totais, { pacientes: 1, pendencias: 0, semDados: 1, falhas: 0 });
    const alertas = Object.entries(firestore.daColecao('alertas'));
    assert.equal(alertas.length, 1);
    const [id, alerta] = alertas[0];
    assert.equal(id, idDoAlertaSemDados('paciente_01', emCampoGrande('2026-11-08T10:15')));
    assert.equal(alerta.tipo, 'sem_dados');
    assert.equal(alerta.pacienteId, 'paciente_01');
    assert.equal(alerta.lido, false);
    assert.equal(alerta.bpm, null);
    assert.match(alerta.mensagem, /^O smartwatch não envia medições desde as 10:15\./);
    assert.equal(alerta.dataHora.toMillis(), emCampoGrande('2026-11-08T13:15'));
    assert.equal(alerta.ultimaLeitura.toMillis(), emCampoGrande('2026-11-08T10:15'));
  });

  it('Não deve avisar antes do prazo nem repetir o aviso do mesmo período', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'batimentos_cardiacos/b1': leitura('2026-11-08T10:15'),
    });

    assert.equal((await verificarAs(firestore, '2026-11-08T13:10')).semDados, 0);
    assert.equal((await verificarAs(firestore, '2026-11-08T13:20')).semDados, 1);
    assert.equal((await verificarAs(firestore, '2026-11-08T13:30')).semDados, 0);
    assert.equal(Object.keys(firestore.daColecao('alertas')).length, 1);
  });

  it('Deve avisar de novo num período novo sem dados (o relógio voltou e parou outra vez)', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'batimentos_cardiacos/b1': leitura('2026-11-08T08:00'),
    });
    await verificarAs(firestore, '2026-11-08T11:05');

    firestore.documentos.set('batimentos_cardiacos/b2', leitura('2026-11-08T12:00'));
    await verificarAs(firestore, '2026-11-08T13:00');
    await verificarAs(firestore, '2026-11-08T15:05');

    assert.equal(Object.keys(firestore.daColecao('alertas')).length, 2);
  });

  it('Não deve avisar à noite quem tirou o relógio para dormir', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'batimentos_cardiacos/b1': leitura('2026-11-08T21:30'),
    });

    for (const hora of ['2026-11-09T00:35', '2026-11-09T03:00', '2026-11-09T07:30']) {
      assert.equal((await verificarAs(firestore, hora)).semDados, 0);
    }
    // Esqueceu de por o relogio de manha: o aviso sai as 9h30.
    assert.equal((await verificarAs(firestore, '2026-11-09T09:35')).semDados, 1);
  });

  it('Não deve avisar quem nunca mandou medição nem quem não tem acompanhante', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'usuarios/paciente_02': pacienteJose({ acompanhantesVinculadosIds: [] }),
      'batimentos_cardiacos/b1': {
        ...leitura('2026-11-08T08:00'),
        pacienteId: 'paciente_02',
      },
    });

    const totais = await verificarAs(firestore, '2026-11-08T11:05');

    assert.deepEqual(totais, { pacientes: 1, pendencias: 0, semDados: 0, falhas: 0 });
    assert.deepEqual(firestore.daColecao('alertas'), {});
  });

  it('Não deve avisar um período antigo, que venceu há mais de uma hora', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'batimentos_cardiacos/b1': leitura('2026-11-01T08:00'),
    });

    const totais = await verificarAs(firestore, '2026-11-08T11:05');

    assert.equal(totais.semDados, 0);
  });

  it('A falha numa verificação não deve impedir a outra', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose({
        tarefasDiarias: [
          {
            chave: 'remedio|m1|08:00',
            tipo: 'remedio',
            descricao: 'Losartana 50 mg',
            horario: '08:00',
          },
        ],
      }),
    });
    const original = firestore.collection.bind(firestore);
    firestore.collection = (colecao) => {
      if (colecao === 'batimentos_cardiacos') throw new Error('indice faltando');
      return original(colecao);
    };

    const totais = await verificarAs(firestore, '2026-11-08T09:05');

    assert.deepEqual(totais, { pacientes: 1, pendencias: 1, semDados: 0, falhas: 1 });
  });
});
