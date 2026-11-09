'use strict';

// Uma execucao da funcao agendada `verificarPendencias` (index.js): para cada
// paciente com acompanhante, confere as tarefas do dia que passaram do
// horario-limite (B9, RF 06.3, pendencias.js) e se o smartwatch parou de
// mandar BPM (B10, sem_dados.js). As duas verificacoes so criam alertas; o
// push aos acompanhantes sai pelo gatilho `notificarAlertaPaciente`.
//
// Fica separado da funcao, com o Firestore recebido de fora, para os testes
// rodarem sem o Firebase.

const { lista, verificarPendenciasDoPaciente } = require('./pendencias');
const { verificarSemDadosDoPaciente } = require('./sem_dados');

const VERIFICACOES = [
  { total: 'pendencias', verificar: verificarPendenciasDoPaciente },
  { total: 'semDados', verificar: verificarSemDadosDoPaciente },
];

// Um paciente (ou uma verificacao) com problema nao impede os outros.
// Devolve os totais, para o log.
async function verificarPacientes({
  firestore,
  agoraMs = Date.now(),
  logger = console,
}) {
  const totais = { pacientes: 0, pendencias: 0, semDados: 0, falhas: 0 };
  const snapshot = await firestore
    .collection('usuarios')
    .where('perfil', '==', 'Paciente')
    .get();

  for (const doc of snapshot.docs) {
    const paciente = doc.data();
    // Sem acompanhante, nao ha a quem avisar: o paciente ja tem os lembretes
    // no aparelho.
    if (lista(paciente.acompanhantesVinculadosIds).length === 0) continue;
    totais.pacientes += 1;

    for (const { total, verificar } of VERIFICACOES) {
      try {
        totais[total] += await verificar({
          pacienteId: doc.id,
          paciente,
          firestore,
          agoraMs,
        });
      } catch (erro) {
        totais.falhas += 1;
        logger.error('Falha ao verificar um paciente', {
          pacienteId: doc.id,
          verificacao: total,
          erro: String(erro),
        });
      }
    }
  }
  return totais;
}

module.exports = { verificarPacientes };
