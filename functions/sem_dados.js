'use strict';

// Aviso de "sem dados do smartwatch" (B10): se o relogio do paciente fica
// algumas horas sem mandar BPM, o acompanhante e avisado. E a rede de seguranca
// para quando a leitura com o app fechado (B7) nao funciona no aparelho, ou o
// relogio ficou fora do pulso: sem medicoes, o app nao consegue avisar que os
// batimentos sairam da zona de seguranca. Roda dentro da funcao agendada
// `verificarPendencias` (index.js, a cada 10 minutos), e o push sai pelo
// gatilho `notificarAlertaPaciente`, como nos outros alertas.

const { Timestamp } = require('firebase-admin/firestore');

const {
  DIA_MS,
  HORA_MS,
  JANELA_MS,
  criarSeNaoExiste,
  diaDoPaciente,
  fusoDoPaciente,
} = require('./pendencias');

// Tempo sem leitura nova que vira aviso, o mesmo do app
// (ZonaSegurancaCardiaca.prazoAvisoSemDados). O card do acompanhante ja mostra
// "SEM DADOS" depois de 1 hora; o push espera mais, para nao avisar a cada
// pausa da sincronizacao do relogio.
const PRAZO_SEM_DADOS_MS = 3 * HORA_MS;

// O tempo so conta das 7h as 22h no horario do paciente
// (ZonaSegurancaCardiaca.inicioDoDiaParaAviso e fimDoDiaParaAviso): tirar o
// relogio para dormir ou carregar a noite nao vira aviso de madrugada, e
// esquecer de por de volta de manha vira aviso no meio da manha.
const INICIO_DO_DIA_HORA = 7;
const FIM_DO_DIA_HORA = 22;

const TIPO_SEM_DADOS = 'sem_dados';

function emMilissegundos(valor) {
  if (valor && typeof valor.toMillis === 'function') return valor.toMillis();
  if (valor instanceof Date) return valor.getTime();
  return null;
}

// O instante em que o tempo sem leitura nova desde [ultimaLeituraMs], contado
// so dentro do horario do dia, chega ao prazo.
function prazoDoAvisoSemDados(ultimaLeituraMs, fusoMinutos) {
  let restante = PRAZO_SEM_DADOS_MS;
  let cursor = ultimaLeituraMs;
  // O prazo cabe num dia (15 h por dia contam); dois dias sobram.
  for (let volta = 0; volta < 3; volta += 1) {
    const dia = diaDoPaciente(cursor, fusoMinutos);
    const abre = dia.inicioMs + INICIO_DO_DIA_HORA * HORA_MS;
    const fecha = dia.inicioMs + FIM_DO_DIA_HORA * HORA_MS;
    const desde = Math.max(cursor, abre);
    if (desde < fecha) {
      if (fecha - desde >= restante) return desde + restante;
      restante -= fecha - desde;
    }
    cursor = dia.inicioMs + DIA_MS;
  }
  return null;
}

function doisDigitos(valor) {
  return String(valor).padStart(2, '0');
}

// "desde as 14:20", "desde ontem às 21:40" ou "desde 06/11 às 21:40", no
// horario do paciente.
function desdeQuando(instanteMs, fusoMinutos, agoraMs) {
  const local = new Date(instanteMs + fusoMinutos * 60 * 1000);
  const hora = `${doisDigitos(local.getUTCHours())}:${doisDigitos(local.getUTCMinutes())}`;
  const diasAtras = Math.round(
    (diaDoPaciente(agoraMs, fusoMinutos).inicioMs -
      diaDoPaciente(instanteMs, fusoMinutos).inicioMs) /
      DIA_MS,
  );
  if (diasAtras === 0) return `desde as ${hora}`;
  if (diasAtras === 1) return `desde ontem às ${hora}`;
  const data = `${doisDigitos(local.getUTCDate())}/${doisDigitos(local.getUTCMonth() + 1)}`;
  return `desde ${data} às ${hora}`;
}

function primeiroNome(paciente) {
  const nome = typeof paciente?.nome === 'string' ? paciente.nome.trim() : '';
  return nome ? nome.split(/\s+/)[0] : 'o paciente';
}

function mensagemSemDados({ ultimaLeituraMs, fusoMinutos, agoraMs, paciente }) {
  return (
    `O smartwatch não envia medições ${desdeQuando(ultimaLeituraMs, fusoMinutos, agoraMs)}. ` +
    `Peça a ${primeiroNome(paciente)} para abrir o Agenda Saúde com o relógio no pulso.`
  );
}

// Um aviso por periodo sem dados: o id leva o horario da ultima leitura, entao
// a execucao seguinte nao repete, e um periodo novo (o relogio voltou e parou
// de novo) tem outro id.
function idDoAlertaSemDados(pacienteId, ultimaLeituraMs) {
  return `${TIPO_SEM_DADOS}_${pacienteId}_${ultimaLeituraMs}`;
}

// Confere a ultima leitura de BPM de um paciente e cria o aviso se o prazo
// acabou de vencer. Quem nunca mandou leitura nao usa smartwatch: sem aviso.
// Devolve quantos avisos criou (0 ou 1).
async function verificarSemDadosDoPaciente({
  pacienteId,
  paciente,
  firestore,
  agoraMs,
}) {
  // Mesma consulta do painel (streamUltimoBatimento): usa o indice que ja existe.
  const snapshot = await firestore
    .collection('batimentos_cardiacos')
    .where('pacienteId', '==', pacienteId)
    .orderBy('timestamp', 'desc')
    .limit(1)
    .get();
  if (snapshot.docs.length === 0) return 0;

  const ultimaLeituraMs = emMilissegundos(snapshot.docs[0].data().timestamp);
  if (ultimaLeituraMs === null) return 0;
  const fusoMinutos = fusoDoPaciente(paciente);
  const prazoMs = prazoDoAvisoSemDados(ultimaLeituraMs, fusoMinutos);
  // So o prazo que venceu na ultima hora: o aviso de um periodo antigo (ex.: ao
  // publicar a funcao) ja nao ajuda.
  if (prazoMs === null || prazoMs > agoraMs || prazoMs <= agoraMs - JANELA_MS) {
    return 0;
  }

  const criou = await criarSeNaoExiste(
    firestore
      .collection('alertas')
      .doc(idDoAlertaSemDados(pacienteId, ultimaLeituraMs)),
    {
      pacienteId,
      tipo: TIPO_SEM_DADOS,
      mensagem: mensagemSemDados({
        ultimaLeituraMs,
        fusoMinutos,
        agoraMs,
        paciente,
      }),
      bpm: null,
      // Quando o prazo venceu: e desde quando o acompanhante deveria saber.
      dataHora: Timestamp.fromMillis(prazoMs),
      lido: false,
      ultimaLeitura: Timestamp.fromMillis(ultimaLeituraMs),
    },
  );
  return criou ? 1 : 0;
}

module.exports = {
  PRAZO_SEM_DADOS_MS,
  INICIO_DO_DIA_HORA,
  FIM_DO_DIA_HORA,
  TIPO_SEM_DADOS,
  prazoDoAvisoSemDados,
  mensagemSemDados,
  idDoAlertaSemDados,
  verificarSemDadosDoPaciente,
};
