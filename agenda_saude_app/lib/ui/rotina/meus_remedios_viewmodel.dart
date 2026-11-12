import 'package:flutter/foundation.dart';

import '../../domain/alergias/alergias.dart';
import '../../domain/medicacao/horario_medicacao.dart';
import '../../domain/medicacao/remedio.dart';
import '../../domain/models/medicamento.dart';
import 'medicacao_viewmodel.dart';

// Remedio enquanto o paciente edita: o nome e os principios ativos vem do
// catalogo (ou do nome digitado na busca), a dose muda a cada letra, e so
// viram Medicamento ao salvar.
class RemedioEmEdicao {
  final String id;
  String nome;
  List<String> substancias;
  String dose;
  // Em "HH:MM", do mais cedo para o mais tarde.
  final List<String> horarios;
  // Por que o ultimo horario escolhido nao entrou; null = sem erro.
  String? erroHorario;

  RemedioEmEdicao({
    required this.id,
    this.nome = '',
    this.substancias = const [],
    this.dose = '',
    List<String>? horarios,
  }) : horarios = horarios ?? [];
}

// Estado da tela "Meus remedios": o paciente escolhe na lista da Anvisa os
// remedios que toma (`BuscarRemedioView`), com a dose e os horarios de cada um
// (RF003, Figura 14). Na rotina ele so marca "tomado". Os horarios vem do
// seletor de hora, ja em "HH:MM" ("08:00"). Os remedios com algo das
// [alergias] do paciente saem marcados. Nada e gravado ate "Salvar".
class MeusRemediosViewModel extends ChangeNotifier {
  static const int tamanhoMaximoDose = 20;

  final Future<bool> Function(List<Medicamento>) _aoSalvar;
  final String Function() _gerarId;
  // Alergias a remedios do paciente (Paciente.alergiasRemedios).
  final List<String> alergias;

  MeusRemediosViewModel({
    required List<Medicamento> atual,
    required Future<bool> Function(List<Medicamento>) aoSalvar,
    this.alergias = const [],
    String Function()? gerarId,
  })  : _aoSalvar = aoSalvar,
        _gerarId = gerarId ?? _idPelaHora {
    remedios = [
      for (final medicamento in atual)
        RemedioEmEdicao(
          id: medicamento.id,
          nome: medicamento.nome,
          substancias: medicamento.substancias,
          dose: medicamento.dose,
          horarios: [...medicamento.horarios],
        ),
    ];
  }

  static String _idPelaHora() => 'm${DateTime.now().microsecondsSinceEpoch}';

  late List<RemedioEmEdicao> remedios;

  bool salvando = false;
  String? mensagemErro;

  bool get podeAdicionar => remedios.length < MedicacaoViewModel.maximoRemedios;

  bool podeAdicionarHorario(RemedioEmEdicao remedio) =>
      remedio.horarios.length < MedicacaoViewModel.maximoHorariosPorRemedio;

  // Poe na lista o remedio escolhido na busca.
  void adicionar(Remedio escolhido) {
    if (!podeAdicionar) return;
    remedios.add(
      RemedioEmEdicao(
        id: _gerarId(),
        nome: escolhido.nome,
        substancias: escolhido.substancias,
      ),
    );
    mensagemErro = null;
    notifyListeners();
  }

  // Troca o remedio por outro da busca. O id fica: as doses ja marcadas hoje
  // continuam ligadas a ele.
  void trocarRemedio(RemedioEmEdicao remedio, Remedio escolhido) {
    remedio
      ..nome = escolhido.nome
      ..substancias = escolhido.substancias;
    mensagemErro = null;
    notifyListeners();
  }

  // A alergia do paciente que o remedio tem, ou null.
  String? alergiaDe(RemedioEmEdicao remedio) => alergiaNoRemedio(
        nome: remedio.nome,
        substancias: remedio.substancias,
        alergias: alergias,
      );

  void remover(String id) {
    remedios.removeWhere((remedio) => remedio.id == id);
    mensagemErro = null;
    notifyListeners();
  }

  void definirDose(RemedioEmEdicao remedio, String valor) {
    remedio.dose = valor;
    _limparAviso();
  }

  // Adiciona o horario escolhido no seletor ("HH:MM"). Devolve true se entrou;
  // senao deixa o motivo em `erroHorario` do remedio.
  bool adicionarHorario(RemedioEmEdicao remedio, String escolhido) {
    final horario = normalizarHorario(escolhido);
    if (horario == null) {
      return _recusarHorario(remedio, 'Esse horário não existe.');
    }
    if (remedio.horarios.contains(horario)) {
      return _recusarHorario(remedio, 'Esse horário já está na lista.');
    }
    if (!podeAdicionarHorario(remedio)) {
      return _recusarHorario(
        remedio,
        'Cada remédio pode ter até '
        '${MedicacaoViewModel.maximoHorariosPorRemedio} horários.',
      );
    }

    remedio.horarios
      ..add(horario)
      ..sort();
    remedio.erroHorario = null;
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  void removerHorario(RemedioEmEdicao remedio, String horario) {
    remedio.horarios.remove(horario);
    remedio.erroHorario = null;
    mensagemErro = null;
    notifyListeners();
  }

  Future<bool> salvar() async {
    if (remedios.any((remedio) => remedio.nome.trim().isEmpty)) {
      mensagemErro = 'Escolha o nome de todos os remédios.';
      notifyListeners();
      return false;
    }
    if (remedios.any((remedio) => remedio.horarios.isEmpty)) {
      mensagemErro = 'Escolha pelo menos um horário para cada remédio.';
      notifyListeners();
      return false;
    }

    salvando = true;
    mensagemErro = null;
    notifyListeners();

    final salvou = await _aoSalvar([
      for (final remedio in remedios)
        Medicamento(
          id: remedio.id,
          nome: remedio.nome.trim(),
          dose: remedio.dose.trim(),
          horarios: [...remedio.horarios],
          substancias: [...remedio.substancias],
        ),
    ]);

    salvando = false;
    if (!salvou) {
      mensagemErro = 'Não foi possível salvar. Tente de novo.';
    }
    notifyListeners();
    return salvou;
  }

  bool _recusarHorario(RemedioEmEdicao remedio, String motivo) {
    remedio.erroHorario = motivo;
    notifyListeners();
    return false;
  }

  // Qualquer edicao limpa o aviso do ultimo "Salvar".
  void _limparAviso() {
    if (mensagemErro != null) {
      mensagemErro = null;
      notifyListeners();
    }
  }
}
