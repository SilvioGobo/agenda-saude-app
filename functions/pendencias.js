'use strict';

// Aviso de pendencia de atividade (RF 06.3, B9). A funcao agendada
// `verificarPendencias` (index.js) roda a cada 10 minutos: para cada paciente
// com acompanhante, olha a lista de tarefas do dia que o app do paciente
// publica em `usuarios/{uid}.tarefasDiarias` (remedios, glicemia e insulina,
// as mesmas dos lembretes do A7) e, quando o horario-limite de uma tarefa
// acaba de passar sem o registro do dia, cria um alerta do tipo `pendencia`.
// Quem manda o push aos acompanhantes e o gatilho `notificarAlertaPaciente`,
// como nos alertas de BPM. O paciente recebe o aviso no proprio aparelho, pelo
// lembrete agendado (PlanejadorDeLembretes, no app).
//
// Fica separado da funcao, com o Firestore recebido de fora, para os testes
// rodarem sem o Firebase (test/pendencias.test.js).

const { Timestamp } = require('firebase-admin/firestore');

const MINUTO_MS = 60 * 1000;
const HORA_MS = 60 * MINUTO_MS;
const DIA_MS = 24 * HORA_MS;

// O horario-limite e o horario da tarefa mais esta tolerancia, a mesma do app
// (PendenciaAtividade.tolerancia, em lib/core/constants/pendencia_atividade.dart).
const TOLERANCIA_MS = HORA_MS;

// So vira alerta a pendencia cujo horario-limite passou na ultima hora: cobre
// uma execucao que falhar sem mandar de uma vez as de horas atras (ao publicar
// a funcao, ou quando o paciente cadastra um remedio no meio do dia).
const JANELA_MS = HORA_MS;

// Fuso de quem ainda nao abriu a versao do app que o publica: o horario de
// Brasilia (UTC-3).
const FUSO_PADRAO_MINUTOS = -180;

const TIPO_PENDENCIA = 'pendencia';

// Tipo de `registros_diarios` que cumpre cada tipo de tarefa.
const REGISTRO_DE_CADA_TAREFA = {
  remedio: 'medicacao',
  glicemia: 'diabete',
  insulina: 'diabete',
};

function lista(valor) {
  return Array.isArray(valor) ? valor : [];
}

// Deslocamento do horario do aparelho do paciente em relacao ao UTC, em
// minutos (ex.: -240 em Campo Grande), como o app publica.
function fusoDoPaciente(paciente) {
  const fuso = paciente?.fusoHorarioMinutos;
  return Number.isInteger(fuso) && Math.abs(fuso) <= 14 * 60
    ? fuso
    : FUSO_PADRAO_MINUTOS;
}

// "HH:MM" em minutos desde a meia-noite; null se nao for um horario.
function minutosDoHorario(horario) {
  const partes = /^(\d{2}):(\d{2})$/.exec(
    typeof horario === 'string' ? horario : '',
  );
  if (!partes) return null;
  const hora = Number(partes[1]);
  const minuto = Number(partes[2]);
  if (hora > 23 || minuto > 59) return null;
  return hora * 60 + minuto;
}

// As tarefas da lista publicada que da para conferir.
function tarefasDoPaciente(paciente) {
  return lista(paciente?.tarefasDiarias).filter(
    (tarefa) =>
      tarefa !== null &&
      typeof tarefa === 'object' &&
      typeof tarefa.chave === 'string' &&
      tarefa.chave !== '' &&
      Object.hasOwn(REGISTRO_DE_CADA_TAREFA, tarefa.tipo) &&
      minutosDoHorario(tarefa.horario) !== null,
  );
}

// O dia de um instante no horario do paciente: "AAAA-MM-DD" e o instante (UTC)
// da meia-noite desse dia.
function diaDoPaciente(instanteMs, fusoMinutos) {
  const deslocamento = fusoMinutos * MINUTO_MS;
  const meiaNoiteLocal =
    Math.floor((instanteMs + deslocamento) / DIA_MS) * DIA_MS;
  return {
    texto: new Date(meiaNoiteLocal).toISOString().slice(0, 10),
    inicioMs: meiaNoiteLocal - deslocamento,
  };
}

// As tarefas cujo horario-limite caiu em (agora - JANELA, agora], cada uma com
// o dia dela: o de hoje ou o de ontem (a tarefa das 23h30 vence a 00h30).
function pendenciasVencidas({ tarefas, fusoMinutos, agoraMs }) {
  const hoje = diaDoPaciente(agoraMs, fusoMinutos);
  const ontem = diaDoPaciente(hoje.inicioMs - 1, fusoMinutos);
  const vencidas = [];
  for (const dia of [ontem, hoje]) {
    for (const tarefa of tarefas) {
      const horarioMs =
        dia.inicioMs + minutosDoHorario(tarefa.horario) * MINUTO_MS;
      const prazoMs = horarioMs + TOLERANCIA_MS;
      if (prazoMs <= agoraMs && prazoMs > agoraMs - JANELA_MS) {
        vencidas.push({ tarefa, dia, prazoMs });
      }
    }
  }
  return vencidas;
}

// As chaves de tarefa que os registros de um dia cumprem, como
// `PlanejadorDeLembretes.chavesCumpridas` no app: a dose marcada (remedio +
// horario) e o momento da glicemia registrado (medicao, insulina ou as duas).
function chavesCumpridas(registros) {
  const chaves = new Set();
  for (const registro of registros) {
    if (registro?.tipo === 'medicacao') {
      chaves.add(`remedio|${registro.medicamentoId}|${registro.horario}`);
    } else if (registro?.tipo === 'diabete') {
      chaves.add(`glicemia|${registro.momento}`);
      chaves.add(`insulina|${registro.momento}`);
    }
  }
  return chaves;
}

// Registros de um tipo no dia que comeca em [inicioMs], na mesma consulta das
// telas do app (pacienteId + tipo + dataHora): usa o indice que ja existe.
async function registrosDoDia(firestore, pacienteId, tipo, inicioMs) {
  const snapshot = await firestore
    .collection('registros_diarios')
    .where('pacienteId', '==', pacienteId)
    .where('tipo', '==', tipo)
    .where('dataHora', '>=', Timestamp.fromMillis(inicioMs))
    .where('dataHora', '<', Timestamp.fromMillis(inicioMs + DIA_MS))
    .orderBy('dataHora', 'desc')
    .get();
  return snapshot.docs.map((doc) => doc.data());
}

function mensagemDaPendencia(tarefa) {
  const descricao =
    typeof tarefa.descricao === 'string' ? tarefa.descricao.trim() : '';
  const qual = descricao ? ` (${descricao})` : '';
  switch (tarefa.tipo) {
    case 'remedio':
      return `Não marcou como tomado o remédio das ${tarefa.horario}${qual}.`;
    case 'glicemia':
      return `Não anotou a glicemia das ${tarefa.horario}${qual}.`;
    default:
      return `Não anotou a insulina das ${tarefa.horario}${qual}.`;
  }
}

// FNV-1a de 32 bits em hexadecimal: um pedaco curto e fixo da chave da tarefa
// para o id do alerta (a chave tem o id do remedio, "|" e o horario).
function resumoDaChave(texto) {
  let hash = 0x811c9dc5;
  for (const unidade of Buffer.from(texto, 'utf8')) {
    hash ^= unidade;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

// Uma pendencia por tarefa por dia: o id fixo faz a execucao seguinte (ou uma
// repetida) nao criar o mesmo alerta de novo.
function idDoAlertaDePendencia(pacienteId, dia, chave) {
  return `${TIPO_PENDENCIA}_${pacienteId}_${dia}_${resumoDaChave(chave)}`;
}

// Cria o documento so se ele ainda nao existe. Devolve se criou.
async function criarSeNaoExiste(referencia, dados) {
  try {
    await referencia.create(dados);
    return true;
  } catch (erro) {
    // ALREADY_EXISTS (codigo 6 do gRPC): o alerta ja foi criado antes.
    if (erro?.code === 6 || erro?.code === 'already-exists') return false;
    throw erro;
  }
}

// Confere as tarefas de um paciente e cria os alertas de pendencia que faltam.
// Devolve quantos criou.
async function verificarPendenciasDoPaciente({
  pacienteId,
  paciente,
  firestore,
  agoraMs,
}) {
  const tarefas = tarefasDoPaciente(paciente);
  if (tarefas.length === 0) return 0;
  const vencidas = pendenciasVencidas({
    tarefas,
    fusoMinutos: fusoDoPaciente(paciente),
    agoraMs,
  });
  if (vencidas.length === 0) return 0;

  // Os registros de cada tipo em cada dia sao lidos uma vez so.
  const cumpridasPorDia = new Map();
  const cumpridasNoDia = (tipo, inicioMs) => {
    const chave = `${tipo}@${inicioMs}`;
    if (!cumpridasPorDia.has(chave)) {
      cumpridasPorDia.set(
        chave,
        registrosDoDia(firestore, pacienteId, tipo, inicioMs).then(
          chavesCumpridas,
        ),
      );
    }
    return cumpridasPorDia.get(chave);
  };

  let criados = 0;
  for (const { tarefa, dia, prazoMs } of vencidas) {
    const cumpridas = await cumpridasNoDia(
      REGISTRO_DE_CADA_TAREFA[tarefa.tipo],
      dia.inicioMs,
    );
    if (cumpridas.has(tarefa.chave)) continue;

    const criou = await criarSeNaoExiste(
      firestore
        .collection('alertas')
        .doc(idDoAlertaDePendencia(pacienteId, dia.texto, tarefa.chave)),
      {
        pacienteId,
        tipo: TIPO_PENDENCIA,
        mensagem: mensagemDaPendencia(tarefa),
        bpm: null,
        // O horario-limite: e quando a tarefa passou a estar pendente.
        dataHora: Timestamp.fromMillis(prazoMs),
        lido: false,
        tarefa: {
          chave: tarefa.chave,
          tipo: tarefa.tipo,
          descricao: typeof tarefa.descricao === 'string' ? tarefa.descricao : '',
          horario: tarefa.horario,
          dia: dia.texto,
        },
      },
    );
    if (criou) criados += 1;
  }
  return criados;
}

// Uma execucao da funcao agendada: confere todos os pacientes que tem
// acompanhante. Um paciente com problema (ex.: dado estranho) nao impede os
// outros. Devolve os totais, para o log.
async function verificarPacientes({
  firestore,
  agoraMs = Date.now(),
  logger = console,
}) {
  const totais = { pacientes: 0, pendencias: 0, falhas: 0 };
  const snapshot = await firestore
    .collection('usuarios')
    .where('perfil', '==', 'Paciente')
    .get();

  for (const doc of snapshot.docs) {
    const paciente = doc.data();
    // Sem acompanhante, nao ha a quem avisar: o paciente ja tem o lembrete no
    // aparelho.
    if (lista(paciente.acompanhantesVinculadosIds).length === 0) continue;
    totais.pacientes += 1;
    try {
      totais.pendencias += await verificarPendenciasDoPaciente({
        pacienteId: doc.id,
        paciente,
        firestore,
        agoraMs,
      });
    } catch (erro) {
      totais.falhas += 1;
      logger.error('Falha ao verificar as pendências de um paciente', {
        pacienteId: doc.id,
        erro: String(erro),
      });
    }
  }
  return totais;
}

module.exports = {
  TOLERANCIA_MS,
  JANELA_MS,
  FUSO_PADRAO_MINUTOS,
  TIPO_PENDENCIA,
  fusoDoPaciente,
  tarefasDoPaciente,
  diaDoPaciente,
  pendenciasVencidas,
  chavesCumpridas,
  mensagemDaPendencia,
  idDoAlertaDePendencia,
  verificarPendenciasDoPaciente,
  verificarPacientes,
};
