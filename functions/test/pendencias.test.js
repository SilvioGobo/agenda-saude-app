'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');

const {
  FUSO_PADRAO_MINUTOS,
  chavesCumpridas,
  diaDoPaciente,
  fusoDoPaciente,
  idDoAlertaDePendencia,
  mensagemDaPendencia,
  pendenciasVencidas,
  tarefasDoPaciente,
  verificarPacientes,
} = require('../pendencias');
const { criarFirestoreFalso } = require('./firestore_falso');

// O paciente mora em Campo Grande (UTC-4), como o app publica.
const FUSO_CAMPO_GRANDE = -240;

// Instante de um horario de Campo Grande ("2026-11-08T09:05").
function emCampoGrande(dataHora) {
  return Date.parse(`${dataHora}:00-04:00`);
}

const losartana = {
  chave: 'remedio|m1|08:00',
  tipo: 'remedio',
  descricao: 'Losartana 50 mg',
  horario: '08:00',
};
const glicemiaAoAcordar = {
  chave: 'glicemia|Ao acordar',
  tipo: 'glicemia',
  descricao: 'Ao acordar',
  horario: '07:00',
};
const insulinaLenta = {
  chave: 'insulina|Insulina lenta (22h)',
  tipo: 'insulina',
  descricao: 'Insulina lenta',
  horario: '22:00',
};

function pacienteJose(campos = {}) {
  return {
    nome: 'José Silva',
    perfil: 'Paciente',
    acompanhantesVinculadosIds: ['cuidador_01'],
    fusoHorarioMinutos: FUSO_CAMPO_GRANDE,
    tarefasDiarias: [losartana, glicemiaAoAcordar, insulinaLenta],
    ...campos,
  };
}

function doseTomada(dataHora, campos = {}) {
  return {
    tipo: 'medicacao',
    pacienteId: 'paciente_01',
    medicamentoId: 'm1',
    horario: '08:00',
    nome: 'Losartana',
    dose: '50 mg',
    dataHora: Timestamp.fromMillis(emCampoGrande(dataHora)),
    ...campos,
  };
}

const loggerMudo = { info() {}, warn() {}, error() {} };

describe('Pendências: regras sem Firebase Testes', () => {
  it('Deve usar o fuso publicado pelo app e, sem ele, o horário de Brasília', () => {
    assert.equal(fusoDoPaciente({ fusoHorarioMinutos: -240 }), -240);
    assert.equal(fusoDoPaciente({}), FUSO_PADRAO_MINUTOS);
    assert.equal(fusoDoPaciente({ fusoHorarioMinutos: 'x' }), FUSO_PADRAO_MINUTOS);
    assert.equal(fusoDoPaciente({ fusoHorarioMinutos: 5000 }), FUSO_PADRAO_MINUTOS);
  });

  it('Deve achar o dia e a meia-noite no horário do paciente', () => {
    // 02:30 de 9/11 em UTC ainda e 22:30 de 8/11 em Campo Grande.
    const dia = diaDoPaciente(Date.parse('2026-11-09T02:30:00Z'), FUSO_CAMPO_GRANDE);
    assert.equal(dia.texto, '2026-11-08');
    assert.equal(dia.inicioMs, Date.parse('2026-11-08T04:00:00Z'));
  });

  it('Deve ignorar as tarefas da lista que não dá para conferir', () => {
    const tarefas = tarefasDoPaciente({
      tarefasDiarias: [
        losartana,
        { ...losartana, chave: '' },
        { ...losartana, tipo: 'agua' },
        { ...losartana, horario: '8h' },
        { ...losartana, horario: '25:00' },
        null,
        'texto',
      ],
    });
    assert.deepEqual(tarefas, [losartana]);
    assert.deepEqual(tarefasDoPaciente({}), []);
  });

  it('Deve vencer a tarefa uma hora depois do horário, só dentro da janela de uma hora', () => {
    const vencidasAs = (dataHora) =>
      pendenciasVencidas({
        tarefas: [losartana],
        fusoMinutos: FUSO_CAMPO_GRANDE,
        agoraMs: emCampoGrande(dataHora),
      });

    assert.equal(vencidasAs('2026-11-08T08:59').length, 0);
    const vencida = vencidasAs('2026-11-08T09:00');
    assert.equal(vencida.length, 1);
    assert.equal(vencida[0].dia.texto, '2026-11-08');
    assert.equal(vencida[0].prazoMs, emCampoGrande('2026-11-08T09:00'));
    assert.equal(vencidasAs('2026-11-08T09:55').length, 1);
    // Passada a janela, a execucao seguinte nao manda mais.
    assert.equal(vencidasAs('2026-11-08T10:00').length, 0);
  });

  it('Deve conferir no dia de ontem a tarefa da noite que vence depois da meia-noite', () => {
    const tarde = { ...losartana, chave: 'remedio|m2|23:30', horario: '23:30' };
    const vencidas = pendenciasVencidas({
      tarefas: [tarde],
      fusoMinutos: FUSO_CAMPO_GRANDE,
      agoraMs: emCampoGrande('2026-11-09T00:40'),
    });

    assert.equal(vencidas.length, 1);
    assert.equal(vencidas[0].dia.texto, '2026-11-08');
  });

  it('Deve dar as chaves cumpridas como o app: dose marcada e momento da glicemia', () => {
    const chaves = chavesCumpridas([
      doseTomada('2026-11-08T08:10'),
      { tipo: 'diabete', momento: 'Ao acordar' },
      { tipo: 'agua', quantidadeML: 250 },
    ]);

    assert.deepEqual(
      [...chaves].sort(),
      ['glicemia|Ao acordar', 'insulina|Ao acordar', 'remedio|m1|08:00'],
    );
  });

  it('Deve escrever o que ficou pendente para cada tipo de tarefa', () => {
    assert.equal(
      mensagemDaPendencia(losartana),
      'Não marcou como tomado o remédio das 08:00 (Losartana 50 mg).',
    );
    assert.equal(
      mensagemDaPendencia(glicemiaAoAcordar),
      'Não anotou a glicemia das 07:00 (Ao acordar).',
    );
    assert.equal(
      mensagemDaPendencia(insulinaLenta),
      'Não anotou a insulina das 22:00 (Insulina lenta).',
    );
    assert.equal(
      mensagemDaPendencia({ ...losartana, descricao: '' }),
      'Não marcou como tomado o remédio das 08:00.',
    );
  });

  it('Deve dar o mesmo id para a mesma tarefa no mesmo dia, sem "/" nem "|"', () => {
    const id = idDoAlertaDePendencia('paciente_01', '2026-11-08', losartana.chave);
    assert.equal(id, idDoAlertaDePendencia('paciente_01', '2026-11-08', losartana.chave));
    assert.notEqual(id, idDoAlertaDePendencia('paciente_01', '2026-11-09', losartana.chave));
    assert.notEqual(id, idDoAlertaDePendencia('paciente_01', '2026-11-08', 'remedio|m1|20:00'));
    assert.match(id, /^pendencia_paciente_01_2026-11-08_[0-9a-f]{8}$/);
  });
});

describe('verificarPacientes (B9) Testes', () => {
  it('Deve criar o alerta de pendência do remédio não marcado até o horário-limite', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
    });

    const totais = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T09:03'),
      logger: loggerMudo,
    });

    assert.deepEqual(totais, { pacientes: 1, pendencias: 1, falhas: 0 });
    const alertas = Object.entries(firestore.daColecao('alertas'));
    assert.equal(alertas.length, 1);
    const [id, alerta] = alertas[0];
    assert.equal(id, idDoAlertaDePendencia('paciente_01', '2026-11-08', losartana.chave));
    assert.equal(alerta.pacienteId, 'paciente_01');
    assert.equal(alerta.tipo, 'pendencia');
    assert.equal(alerta.lido, false);
    assert.equal(alerta.bpm, null);
    assert.equal(
      alerta.mensagem,
      'Não marcou como tomado o remédio das 08:00 (Losartana 50 mg).',
    );
    assert.equal(alerta.dataHora.toMillis(), emCampoGrande('2026-11-08T09:00'));
    assert.deepEqual(alerta.tarefa, { ...losartana, dia: '2026-11-08' });
  });

  it('Não deve avisar quando a dose foi marcada no dia, mesmo antes do horário', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'registros_diarios/r1': doseTomada('2026-11-08T07:40'),
    });

    const totais = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T09:03'),
      logger: loggerMudo,
    });

    assert.equal(totais.pendencias, 0);
    assert.deepEqual(firestore.daColecao('alertas'), {});
  });

  it('Deve avisar quando a dose marcada é a de outro dia ou de outro horário', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'registros_diarios/r1': doseTomada('2026-11-07T08:05'),
      'registros_diarios/r2': doseTomada('2026-11-08T08:05', { horario: '20:00' }),
      'registros_diarios/r3': doseTomada('2026-11-08T08:05', { pacienteId: 'outro' }),
    });

    const totais = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T09:03'),
      logger: loggerMudo,
    });

    assert.equal(totais.pendencias, 1);
  });

  it('Não deve repetir o alerta na execução seguinte', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
    });
    const verificarAs = (dataHora) =>
      verificarPacientes({
        firestore,
        agoraMs: emCampoGrande(dataHora),
        logger: loggerMudo,
      });

    assert.equal((await verificarAs('2026-11-08T09:03')).pendencias, 1);
    assert.equal((await verificarAs('2026-11-08T09:13')).pendencias, 0);
    assert.equal(Object.keys(firestore.daColecao('alertas')).length, 1);
  });

  it('Deve conferir a glicemia e a insulina pelos registros de diabetes do momento', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'registros_diarios/g1': {
        tipo: 'diabete',
        pacienteId: 'paciente_01',
        momento: 'Insulina lenta (22h)',
        doseInsulina: 14,
        dataHora: Timestamp.fromMillis(emCampoGrande('2026-11-08T22:10')),
      },
    });

    // As 08:05 vence a glicemia de ao acordar (07:00); as 23:05, a insulina.
    const manha = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T08:05'),
      logger: loggerMudo,
    });
    const noite = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T23:05'),
      logger: loggerMudo,
    });

    assert.equal(manha.pendencias, 1);
    assert.equal(noite.pendencias, 0);
    const [alerta] = Object.values(firestore.daColecao('alertas'));
    assert.equal(alerta.tarefa.tipo, 'glicemia');
  });

  it('Deve usar o horário de Brasília para quem ainda não publicou o fuso', async () => {
    const semFuso = pacienteJose();
    delete semFuso.fusoHorarioMinutos;
    const firestore = criarFirestoreFalso({ 'usuarios/paciente_01': semFuso });

    // Sem o fuso, vale o horario de Brasilia: 09:03 de la vence a dose das
    // 08:00 (em Campo Grande ainda seriam 08:03).
    const totais = await verificarPacientes({
      firestore,
      agoraMs: Date.parse('2026-11-08T09:03:00-03:00'),
      logger: loggerMudo,
    });

    assert.equal(totais.pendencias, 1);
  });

  it('Deve pular quem não tem acompanhante, quem não é paciente e quem não publicou tarefas', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose({ acompanhantesVinculadosIds: [] }),
      'usuarios/paciente_02': pacienteJose({ tarefasDiarias: undefined }),
      'usuarios/cuidador_01': {
        nome: 'Carlos',
        perfil: 'Acompanhante',
        tarefasDiarias: [losartana],
        acompanhantesVinculadosIds: ['x'],
      },
    });

    const totais = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T09:03'),
      logger: loggerMudo,
    });

    assert.deepEqual(totais, { pacientes: 1, pendencias: 0, falhas: 0 });
    assert.deepEqual(firestore.daColecao('alertas'), {});
  });

  it('Deve ler os registros só quando há tarefa vencida, uma vez por tipo', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose({
        tarefasDiarias: [
          losartana,
          { ...losartana, chave: 'remedio|m2|08:00', descricao: 'Metformina' },
        ],
      }),
    });

    await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T15:00'),
      logger: loggerMudo,
    });
    assert.equal(
      firestore.consultas.filter((c) => c.colecao === 'registros_diarios').length,
      0,
    );

    await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T09:03'),
      logger: loggerMudo,
    });
    const consultas = firestore.consultas.filter(
      (c) => c.colecao === 'registros_diarios',
    );
    assert.equal(consultas.length, 1);
    // A mesma consulta das telas do app: paciente, tipo e o dia.
    assert.deepEqual(
      consultas[0].filtros.map(([campo, operador]) => `${campo} ${operador}`),
      ['pacienteId ==', 'tipo ==', 'dataHora >=', 'dataHora <'],
    );
    assert.equal(Object.keys(firestore.daColecao('alertas')).length, 2);
  });

  it('Um paciente com problema não deve impedir os outros', async () => {
    const firestore = criarFirestoreFalso({
      'usuarios/paciente_01': pacienteJose(),
      'usuarios/paciente_02': pacienteJose(),
    });
    const original = firestore.collection.bind(firestore);
    firestore.collection = (colecao) => {
      const consulta = original(colecao);
      if (colecao !== 'registros_diarios') return consulta;
      const where = consulta.where.bind(consulta);
      return {
        ...consulta,
        where(campo, operador, valor) {
          if (valor === 'paciente_01') throw new Error('indice faltando');
          return where(campo, operador, valor);
        },
      };
    };

    const totais = await verificarPacientes({
      firestore,
      agoraMs: emCampoGrande('2026-11-08T09:03'),
      logger: loggerMudo,
    });

    assert.deepEqual(totais, { pacientes: 2, pendencias: 1, falhas: 1 });
  });
});
