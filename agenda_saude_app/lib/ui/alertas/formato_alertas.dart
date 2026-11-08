import '../../domain/models/alerta.dart';

// Titulo da notificacao de um alerta. E o mesmo do push
// (`tituloDoAlerta`, em functions/notificacao.js): a escuta do app e o push
// mostram o mesmo alerta com o mesmo id, e um so substitui o outro sem mudar
// nada na tela.
String tituloDoAlerta(Alerta alerta, String nomePaciente) {
  if (alerta.ehEmergencia) return 'Emergência: $nomePaciente';
  if (alerta.ehPendencia) return 'Pendência: $nomePaciente';
  return 'Atenção: $nomePaciente';
}

// A frase do topo do painel do acompanhante para o alerta nao lido mais novo.
String mancheteDoAlerta(Alerta alerta, String nomePaciente) {
  if (alerta.ehEmergencia) return 'Emergência com $nomePaciente';
  if (alerta.ehPendencia) return '$nomePaciente tem uma atividade pendente';
  return '$nomePaciente precisa de atenção';
}
