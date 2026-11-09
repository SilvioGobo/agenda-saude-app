// Aviso de pendencia de atividade (RF 06.3, B9): quando o horario-limite de uma
// tarefa do dia passa sem o registro (tomar um remedio, medir a glicemia,
// aplicar a insulina), o paciente recebe um lembrete no aparelho e o
// acompanhante recebe um push.
class PendenciaAtividade {
  PendenciaAtividade._();

  // O horario-limite e o horario da tarefa mais esta tolerancia: tomar o
  // remedio ou medir a glicemia um pouco depois do lembrete e normal. A Cloud
  // Function `verificarPendencias` (functions/pendencias.js) usa o mesmo valor
  // para avisar o acompanhante.
  static const Duration tolerancia = Duration(hours: 1);
}
