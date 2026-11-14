import 'package:flutter/foundation.dart';

import '../../core/constants/meta_hidratacao.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/paciente.dart';

// Estado das telas de metas: ver as metas calculadas e ajustar as da rotina.
// (O peso e o resto da triagem mudam em "Meus dados", que calcula as metas de
// novo.) Todo ajuste e gravado no documento do paciente e repassado em
// [aoAtualizar] para o painel enxergar o paciente novo sem precisar reler o
// Firestore.
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

  // Criado so ao gravar: ver as metas nao depende do Firestore.
  PacienteRepository? _pacienteRepositoryInjetado;
  PacienteRepository get _pacienteRepository =>
      _pacienteRepositoryInjetado ??= PacienteRepository();
  final ValueChanged<Paciente>? _aoAtualizar;

  Paciente _paciente;

  MetasViewModel({
    required Paciente paciente,
    PacienteRepository? pacienteRepository,
    ValueChanged<Paciente>? aoAtualizar,
  }) : _paciente = paciente,
       _pacienteRepositoryInjetado = pacienteRepository,
       _aoAtualizar = aoAtualizar;

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

  Future<bool> _gravar({
    required MetasPersonalizadas metas,
    required String erro,
  }) async {
    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      await _pacienteRepository.atualizarMetas(_paciente.id, metas);
      _paciente = _paciente.copyWith(metas: metas);
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
