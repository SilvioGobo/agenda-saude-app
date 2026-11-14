import 'package:flutter/foundation.dart';

import '../../domain/models/paciente.dart';

// O paciente que a "Minha Rotina" repassa ao painel. Varias telas mudam o
// paciente - o plano de refeicoes, os remedios, as metas e as alergias - e cada
// ViewModel guarda a sua copia dele. Sem esta classe, salvar as refeicoes depois dos remedios (ou o
// contrario) devolveria ao painel a lista antiga do outro cartao, e a proxima
// abertura da Rotina mostraria como pendente algo que ja foi mudado. Cada
// aviso entra por cima do paciente mais recente que o painel recebeu.
class PacienteDaRotina {
  Paciente _atual;
  final ValueChanged<Paciente>? _aoAtualizar;

  PacienteDaRotina(Paciente inicial, ValueChanged<Paciente>? aoAtualizar)
      : _atual = inicial,
        _aoAtualizar = aoAtualizar;

  Paciente get atual => _atual;

  // O cartao de refeicoes salvou o plano novo.
  void refeicoesMudaram(Paciente novo) {
    _atual = _atual.copyWith(refeicoes: novo.refeicoes);
    _aoAtualizar?.call(_atual);
  }

  // O cartao de medicacoes salvou a lista de remedios nova.
  void medicamentosMudaram(Paciente novo) {
    _atual = _atual.copyWith(medicamentos: novo.medicamentos);
    _aoAtualizar?.call(_atual);
  }

  // O paciente ajustou as metas de agua, passos ou exercicio.
  void metasMudaram(Paciente novo) {
    _atual = _atual.copyWith(metas: novo.metas);
    _aoAtualizar?.call(_atual);
  }

  // O paciente mudou as alergias ("Minhas alergias").
  void alergiasMudaram(Paciente novo) {
    _atual = _atual.copyWith(
      alergiasAlimentos: novo.alergiasAlimentos,
      alergiasRemedios: novo.alergiasRemedios,
      alergias: novo.alergias ?? '',
    );
    _aoAtualizar?.call(_atual);
  }
}
