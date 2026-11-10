import 'package:flutter/foundation.dart';

import '../../domain/medicacao/horario_medicacao.dart';
import '../../domain/models/medicamento.dart';
import 'medicacao_viewmodel.dart';

// Remedio enquanto o paciente edita: o nome e a dose mudam a cada letra, e so
// viram Medicamento ao salvar.
class RemedioEmEdicao {
  final String id;
  String nome;
  String dose;
  // Em "HH:MM", do mais cedo para o mais tarde.
  final List<String> horarios;
  // Por que o ultimo horario escolhido nao entrou; null = sem erro.
  String? erroHorario;

  RemedioEmEdicao({
    required this.id,
    this.nome = '',
    this.dose = '',
    List<String>? horarios,
  }) : horarios = horarios ?? [];
}

// Estado da tela "Meus remedios": o paciente cadastra os remedios que toma, com
// a dose e os horarios de cada um (RF003, Figura 14). Na rotina ele so marca
// "tomado". Os horarios vem do seletor de hora, ja em "HH:MM" ("08:00"). Nada
// e gravado ate "Salvar".
class MeusRemediosViewModel extends ChangeNotifier {
  static const int tamanhoMaximoNome = 40;
  static const int tamanhoMaximoDose = 20;

  final Future<bool> Function(List<Medicamento>) _aoSalvar;
  final String Function() _gerarId;

  MeusRemediosViewModel({
    required List<Medicamento> atual,
    required Future<bool> Function(List<Medicamento>) aoSalvar,
    String Function()? gerarId,
  })  : _aoSalvar = aoSalvar,
        _gerarId = gerarId ?? _idPelaHora {
    remedios = [
      for (final medicamento in atual)
        RemedioEmEdicao(
          id: medicamento.id,
          nome: medicamento.nome,
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

  void adicionar() {
    if (!podeAdicionar) return;
    remedios.add(RemedioEmEdicao(id: _gerarId()));
    mensagemErro = null;
    notifyListeners();
  }

  void remover(String id) {
    remedios.removeWhere((remedio) => remedio.id == id);
    mensagemErro = null;
    notifyListeners();
  }

  void definirNome(RemedioEmEdicao remedio, String valor) {
    remedio.nome = valor;
    _limparAviso();
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
      mensagemErro = 'Dê um nome para todos os remédios.';
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
