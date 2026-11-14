import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/repositories/paciente_repository.dart';
import '../../domain/alergias/alergias.dart';
import '../../domain/medicacao/remedio.dart';
import '../../domain/metas/calculadora_metas.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/paciente.dart';

// Estado da triagem (RF002). Serve ao assistente de 4 etapas do primeiro
// acesso e a "Meus dados" (menu > perfil), que abre com as respostas que o
// paciente ja deu (`edicao: true`) para ele mudar o que precisar.
class TriagemViewModel extends ChangeNotifier {
  static const double limiteLiquidoMinimoLitros = 0.5;
  static const double limiteLiquidoMaximoLitros = 5;

  // Criado so ao gravar: abrir "Meus dados" nao depende do Firestore.
  PacienteRepository? _pacienteRepositoryInjetado;
  PacienteRepository get _pacienteRepository =>
      _pacienteRepositoryInjetado ??= PacienteRepository();
  final Paciente _pacienteOriginal;

  TriagemViewModel({
    required Paciente paciente,
    PacienteRepository? pacienteRepository,
    bool edicao = false,
  })  : _pacienteOriginal = paciente,
        _pacienteRepositoryInjetado = pacienteRepository {
    if (edicao) _preencherCom(paciente);
  }

  // As respostas que o paciente ja deu, para "Meus dados".
  void _preencherCom(Paciente paciente) {
    possuiDiabetes = paciente.possuiDiabetes;
    tipoDiabetes = paciente.tipoDiabetes;
    usaInsulina = paciente.usaInsulina;
    tipoInsulina = paciente.tipoInsulina ?? '';
    possuiCardiopatia = paciente.possuiCardiopatia;
    tipoCardiopatia = paciente.tipoCardiopatia ?? '';
    usaMarcapasso = paciente.usaMarcapasso;
    final limiteMl = paciente.limiteLiquidoMl;
    possuiRestricaoLiquido =
        paciente.possuiCardiopatia ? limiteMl != null : null;
    limiteLiquidoLitros = limiteMl == null ? null : limiteMl / 1000;
    dataNascimento = paciente.dataNascimento;
    sexoBiologico = paciente.sexoBiologico;
    alturaCm = paciente.alturaCm;
    pesoKg = paciente.pesoKg;
    nivelAtividadeFisica = paciente.nivelAtividadeFisica;
    alergiasAlimentos = [...paciente.alergiasAlimentos];
    alergiasRemedios = [...paciente.alergiasRemedios];
    outrasAlergias = paciente.alergias ?? '';
    medicamentosEmUso = [...paciente.medicamentosEmUso];
  }

  // Diabetes
  bool? possuiDiabetes;
  String? tipoDiabetes;
  bool? usaInsulina;
  String tipoInsulina = '';

  // Cardiopatia
  bool? possuiCardiopatia;
  String tipoCardiopatia = '';
  bool? usaMarcapasso;
  // Restricao de liquido definida pelo medico. Limita a meta de hidratacao,
  // entao so e perguntada a quem tem cardiopatia (ex.: insuficiencia cardiaca).
  bool? possuiRestricaoLiquido;
  double? limiteLiquidoLitros;

  // Dados fisicos/demograficos (obrigatorios)
  DateTime? dataNascimento;
  String? sexoBiologico;
  double? alturaCm;
  double? pesoKg;
  String? nivelAtividadeFisica;

  // Outras informacoes (opcionais). As alergias a alimentos e a remedios e os
  // remedios em uso sao escolhidos nas listas (TACO e Anvisa); as outras
  // alergias, em texto livre.
  List<String> alergiasAlimentos = [];
  List<String> alergiasRemedios = [];
  String outrasAlergias = '';
  List<Remedio> medicamentosEmUso = [];

  bool carregando = false;
  String? mensagemErro;

  // Disponível para a tela apos concluirTriagem() ou salvarAlteracoes() ter
  // sucesso, para seguir ja com os dados atualizados (ex: possuiCardiopatia).
  Paciente? pacienteAtualizado;

  void responderDiabetes(bool valor) {
    possuiDiabetes = valor;
    if (!valor) {
      tipoDiabetes = null;
      usaInsulina = null;
      tipoInsulina = '';
    }
    mensagemErro = null;
    notifyListeners();
  }

  void selecionarTipoDiabetes(String tipo) {
    tipoDiabetes = tipo;
    mensagemErro = null;
    notifyListeners();
  }

  void responderUsaInsulina(bool valor) {
    usaInsulina = valor;
    if (!valor) tipoInsulina = '';
    mensagemErro = null;
    notifyListeners();
  }

  void definirTipoInsulina(String valor) {
    tipoInsulina = valor;
  }

  void responderCardiopatia(bool valor) {
    possuiCardiopatia = valor;
    if (!valor) {
      tipoCardiopatia = '';
      usaMarcapasso = null;
      possuiRestricaoLiquido = null;
      limiteLiquidoLitros = null;
    }
    mensagemErro = null;
    notifyListeners();
  }

  void definirTipoCardiopatia(String valor) {
    tipoCardiopatia = valor;
  }

  void responderUsaMarcapasso(bool valor) {
    usaMarcapasso = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void responderRestricaoLiquido(bool valor) {
    possuiRestricaoLiquido = valor;
    if (!valor) limiteLiquidoLitros = null;
    mensagemErro = null;
    notifyListeners();
  }

  void definirLimiteLiquido(String litros) {
    limiteLiquidoLitros = double.tryParse(litros.replaceAll(',', '.'));
  }

  void definirDataNascimento(DateTime valor) {
    dataNascimento = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void selecionarSexoBiologico(String valor) {
    sexoBiologico = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void definirAltura(String valor) {
    alturaCm = double.tryParse(valor.replaceAll(',', '.'));
  }

  void definirPeso(String valor) {
    pesoKg = double.tryParse(valor.replaceAll(',', '.'));
  }

  void selecionarNivelAtividadeFisica(String valor) {
    nivelAtividadeFisica = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void adicionarAlergiaAlimento(String nome) {
    alergiasAlimentos = comAlergia(alergiasAlimentos, nome);
    notifyListeners();
  }

  void tirarAlergiaAlimento(String nome) {
    alergiasAlimentos = [...alergiasAlimentos]..remove(nome);
    notifyListeners();
  }

  void adicionarAlergiaRemedio(String nome) {
    alergiasRemedios = comAlergia(alergiasRemedios, nome);
    notifyListeners();
  }

  void tirarAlergiaRemedio(String nome) {
    alergiasRemedios = [...alergiasRemedios]..remove(nome);
    notifyListeners();
  }

  void definirOutrasAlergias(String valor) {
    outrasAlergias = valor;
  }

  // O mesmo remedio (pelo nome) nao entra duas vezes.
  void adicionarMedicamentoEmUso(Remedio remedio) {
    if (medicamentosEmUso.any((emUso) => emUso.nome == remedio.nome)) return;
    medicamentosEmUso = [...medicamentosEmUso, remedio];
    notifyListeners();
  }

  void tirarMedicamentoEmUso(Remedio remedio) {
    medicamentosEmUso = [...medicamentosEmUso]..remove(remedio);
    notifyListeners();
  }

  // A alergia (das escolhidas acima) que o remedio em uso tem, ou null.
  String? alergiaDoMedicamentoEmUso(Remedio remedio) => alergiaNoRemedio(
        nome: remedio.nome,
        substancias: remedio.substancias,
        alergias: alergiasRemedios,
      );

  // Cada etapa do assistente valida só os campos que ela mesma mostra, e
  // guarda o erro em mensagemErro para a tela exibir. Retorna true quando
  // pode avançar para a próxima etapa.
  bool validarEAvancarSobreVoce() {
    if (dataNascimento == null ||
        sexoBiologico == null ||
        alturaCm == null ||
        pesoKg == null ||
        nivelAtividadeFisica == null) {
      mensagemErro =
          'Preencha data de nascimento, sexo, altura, peso e nível de atividade física.';
      notifyListeners();
      return false;
    }
    if (alturaCm! <= 0 || alturaCm! > 250 || pesoKg! <= 0 || pesoKg! > 400) {
      mensagemErro = 'Confira os valores de altura e peso.';
      notifyListeners();
      return false;
    }
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  bool validarEAvancarDiabetes() {
    if (possuiDiabetes == null) {
      mensagemErro = 'Responda se você possui diabetes.';
      notifyListeners();
      return false;
    }
    if (possuiDiabetes == true &&
        (tipoDiabetes == null || usaInsulina == null)) {
      mensagemErro = 'Complete as perguntas sobre diabetes.';
      notifyListeners();
      return false;
    }
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  bool validarEAvancarCardiopatia() {
    if (possuiCardiopatia == null) {
      mensagemErro = 'Responda se você possui alguma cardiopatia.';
      notifyListeners();
      return false;
    }
    if (possuiCardiopatia == true &&
        (usaMarcapasso == null || possuiRestricaoLiquido == null)) {
      mensagemErro = 'Complete as perguntas sobre cardiopatia.';
      notifyListeners();
      return false;
    }
    if (possuiRestricaoLiquido == true &&
        (limiteLiquidoLitros == null ||
            limiteLiquidoLitros! < limiteLiquidoMinimoLitros ||
            limiteLiquidoLitros! > limiteLiquidoMaximoLitros)) {
      mensagemErro = 'Informe quantos litros por dia seu médico permitiu '
          '(entre 0,5 e 5).';
      notifyListeners();
      return false;
    }
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  // Primeiro acesso: grava o paciente inteiro (o documento vem do cadastro).
  Future<bool> concluirTriagem() => _salvar(
        _pacienteRepository.salvarPaciente,
        erro: 'Não foi possível salvar a triagem. Tente novamente.',
      );

  // "Meus dados": grava so os campos da triagem e as metas, sem mexer no resto
  // do documento (refeicoes, remedios, limites de alerta, tarefas do dia).
  Future<bool> salvarAlteracoes() => _salvar(
        _pacienteRepository.atualizarTriagem,
        erro: 'Não foi possível salvar seus dados. Tente de novo.',
      );

  Future<bool> _salvar(
    Future<void> Function(Paciente) gravar, {
    required String erro,
  }) async {
    if (!validarEAvancarSobreVoce()) return false;
    if (!validarEAvancarDiabetes()) return false;
    if (!validarEAvancarCardiopatia()) return false;

    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      final comRespostas = _pacienteComRespostas();
      final metas = _metasPara(comRespostas);
      final pacienteAtualizado =
          metas == null ? comRespostas : comRespostas.copyWith(metas: metas);

      await gravar(pacienteAtualizado);

      this.pacienteAtualizado = pacienteAtualizado;
      carregando = false;
      notifyListeners();
      return true;
    } catch (_) {
      mensagemErro = erro;
      carregando = false;
      notifyListeners();
      return false;
    }
  }

  // O paciente com as respostas por cima. O que nao e da triagem (telefone,
  // remedios, refeicoes, metas, limites de alerta, vinculos) vem como estava:
  // no primeiro acesso o paciente inteiro e gravado por cima do documento,
  // entao nada disso pode se perder aqui.
  Paciente _pacienteComRespostas() {
    final original = _pacienteOriginal;
    return Paciente(
      id: original.id,
      nome: original.nome,
      email: original.email,
      perfil: original.perfil,
      telefone: original.telefone,
      medicamentos: original.medicamentos,
      refeicoes: original.refeicoes,
      metas: original.metas,
      limitesAlerta: original.limitesAlerta,
      codigoVinculo: original.codigoVinculo,
      acompanhantesVinculadosIds: original.acompanhantesVinculadosIds,
      possuiDiabetes: possuiDiabetes!,
      tipoDiabetes: possuiDiabetes! ? tipoDiabetes : null,
      usaInsulina: possuiDiabetes! ? usaInsulina : null,
      tipoInsulina:
          (possuiDiabetes! && usaInsulina == true && tipoInsulina.trim().isNotEmpty)
              ? tipoInsulina.trim()
              : null,
      possuiCardiopatia: possuiCardiopatia!,
      tipoCardiopatia:
          (possuiCardiopatia! && tipoCardiopatia.trim().isNotEmpty)
              ? tipoCardiopatia.trim()
              : null,
      usaMarcapasso: possuiCardiopatia! ? usaMarcapasso : null,
      triagemConcluida: true,
      dataNascimento: dataNascimento,
      sexoBiologico: sexoBiologico,
      alturaCm: alturaCm,
      pesoKg: pesoKg,
      nivelAtividadeFisica: nivelAtividadeFisica,
      alergias:
          outrasAlergias.trim().isNotEmpty ? outrasAlergias.trim() : null,
      alergiasAlimentos: alergiasAlimentos,
      alergiasRemedios: alergiasRemedios,
      medicamentosEmUso: medicamentosEmUso,
      limiteLiquidoMl: possuiRestricaoLiquido == true
          ? (limiteLiquidoLitros! * 1000).round()
          : null,
    );
  }

  // As metas saem das respostas (CalculadoraMetas). Sem como calcular (ex.:
  // data de nascimento de menor de idade), ficam as que o paciente ja tinha
  // (nenhuma, no primeiro acesso: valem os padroes). O que ele ajustou a mao
  // em "Minhas metas" (agua, passos, exercicio) continua valendo, so a agua
  // nunca passa da restricao do medico.
  MetasPersonalizadas? _metasPara(Paciente paciente) {
    final calculadas = CalculadoraMetas.calcular(paciente);
    final anteriores = _pacienteOriginal.metas;
    if (calculadas == null) return anteriores;
    if (anteriores == null || !anteriores.ajustadaManualmente) {
      return calculadas;
    }
    final limite = paciente.limiteLiquidoMl;
    return calculadas.comAjustes(
      hidratacaoMl: limite == null
          ? anteriores.hidratacaoMl
          : math.min(anteriores.hidratacaoMl, limite),
      passos: anteriores.passos,
      exercicioMinutosSemana: anteriores.exercicioMinutosSemana,
    );
  }
}
