import 'package:flutter/foundation.dart';

import '../../core/constants/meta_hidratacao.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/metas/calculadora_metas.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/paciente.dart';

// Estado das telas de metas: ver as metas calculadas, ajustar as da rotina e
// recalcular depois de uma mudanca de peso ou de atividade fisica. Toda
// alteracao e gravada no documento do paciente e repassada em [aoAtualizar]
// para o painel enxergar o paciente novo sem precisar reler o Firestore.
class MetasViewModel extends ChangeNotifier {
  // Limites dos ajustes manuais. O paciente pode mudar a meta, mas nao para
  // um valor absurdo.
  static const int hidratacaoMinimaMl = 4 * MetaHidratacao.mlPorCopo;
  static const int hidratacaoMaximaPadraoMl = 16 * MetaHidratacao.mlPorCopo;
  static const int passosMinimo = 1000;
  static const int passosMaximo = 20000;
  static const int passosPasso = 500;
  static const int exercicioMinimoMinutos = 30;
  static const int exercicioMaximoMinutos = 420;
  static const int exercicioPassoMinutos = 15;

  static const double pesoMinimoKg = 30;
  static const double pesoMaximoKg = 400;

  // Criado so ao gravar: ver as metas nao depende do Firestore.
  PacienteRepository? _pacienteRepositoryInjetado;
  PacienteRepository get _pacienteRepository =>
      _pacienteRepositoryInjetado ??= PacienteRepository();
  final ValueChanged<Paciente>? _aoAtualizar;
  final DateTime Function() _agora;

  Paciente _paciente;

  MetasViewModel({
    required Paciente paciente,
    PacienteRepository? pacienteRepository,
    ValueChanged<Paciente>? aoAtualizar,
    DateTime Function()? agora,
  }) : _paciente = paciente,
       _pacienteRepositoryInjetado = pacienteRepository,
       _aoAtualizar = aoAtualizar,
       _agora = agora ?? DateTime.now;

  Paciente get paciente => _paciente;

  MetasPersonalizadas? get metas => _paciente.metas;

  bool carregando = false;
  String? mensagemErro;

  // A meta de agua nunca passa da restricao de liquido do medico.
  int get hidratacaoMaximaMl {
    final limite = _paciente.limiteLiquidoMl;
    if (limite == null) return hidratacaoMaximaPadraoMl;
    final limiteEmCopos =
        (limite ~/ MetaHidratacao.mlPorCopo) * MetaHidratacao.mlPorCopo;
    return limiteEmCopos < MetaHidratacao.mlPorCopo
        ? MetaHidratacao.mlPorCopo
        : limiteEmCopos;
  }

  // Menor que o minimo padrao quando o medico limitou o liquido a pouco.
  int get hidratacaoMinimaAjusteMl => hidratacaoMaximaMl < hidratacaoMinimaMl
      ? hidratacaoMaximaMl
      : hidratacaoMinimaMl;

  // Recalcular substitui o que o paciente mudou a mao: a tela pergunta antes.
  bool get precisaConfirmarRecalculo => metas?.ajustadaManualmente ?? false;

  Future<bool> salvarAjustes({
    required int hidratacaoMl,
    required int passos,
    required int exercicioMinutosSemana,
  }) async {
    final atuais = metas;
    if (atuais == null) return false;

    final ajustadas = atuais.comAjustes(
      hidratacaoMl: hidratacaoMl.clamp(
        hidratacaoMinimaAjusteMl,
        hidratacaoMaximaMl,
      ),
      passos: passos.clamp(passosMinimo, passosMaximo),
      exercicioMinutosSemana: exercicioMinutosSemana.clamp(
        exercicioMinimoMinutos,
        exercicioMaximoMinutos,
      ),
    );

    final mudou =
        ajustadas.hidratacaoMl != atuais.hidratacaoMl ||
        ajustadas.passos != atuais.passos ||
        ajustadas.exercicioMinutosSemana != atuais.exercicioMinutosSemana;
    if (!mudou) return true;

    return _gravar(
      metas: ajustadas,
      erro: 'Não foi possível salvar seus ajustes. Tente novamente.',
    );
  }

  // Atualiza o peso e o nivel de atividade e calcula as metas de novo.
  Future<bool> recalcular({
    required String pesoTexto,
    required String nivelAtividade,
  }) async {
    final peso = double.tryParse(pesoTexto.trim().replaceAll(',', '.'));
    if (peso == null || peso < pesoMinimoKg || peso > pesoMaximoKg) {
      mensagemErro = 'Confira o valor do peso.';
      notifyListeners();
      return false;
    }

    final atualizado = _paciente.copyWith(
      pesoKg: peso,
      nivelAtividadeFisica: nivelAtividade,
    );
    final novasMetas = CalculadoraMetas.calcular(atualizado, hoje: _agora());
    if (novasMetas == null) {
      mensagemErro =
          'Faltam dados do seu cadastro (data de nascimento, sexo '
          'ou altura) para calcular as metas.';
      notifyListeners();
      return false;
    }

    return _gravar(
      metas: novasMetas,
      pesoKg: peso,
      nivelAtividadeFisica: nivelAtividade,
      erro: 'Não foi possível recalcular as metas. Tente novamente.',
    );
  }

  Future<bool> _gravar({
    required MetasPersonalizadas metas,
    required String erro,
    double? pesoKg,
    String? nivelAtividadeFisica,
  }) async {
    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      await _pacienteRepository.atualizarMetas(
        _paciente.id,
        metas,
        pesoKg: pesoKg,
        nivelAtividadeFisica: nivelAtividadeFisica,
      );
      _paciente = _paciente.copyWith(
        pesoKg: pesoKg,
        nivelAtividadeFisica: nivelAtividadeFisica,
        metas: metas,
      );
      _aoAtualizar?.call(_paciente);
      carregando = false;
      notifyListeners();
      return true;
    } catch (erroAoGravar) {
      debugPrint('Falha ao gravar as metas: $erroAoGravar');
      mensagemErro = erro;
      carregando = false;
      notifyListeners();
      return false;
    }
  }
}
