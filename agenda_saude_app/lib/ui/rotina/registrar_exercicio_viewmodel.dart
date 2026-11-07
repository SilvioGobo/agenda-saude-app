import 'package:flutter/foundation.dart';

import '../../core/constants/meta_exercicio.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_exercicio.dart';

// Formulario de um exercicio (RF 03.3 "Registrar atividades fisicas"): o
// paciente escolhe qual exercicio fez, por quantos minutos (de 5 em 5, sem
// teclado) e como foi a intensidade. Cada vez que salva cria um registro novo:
// ele pode se exercitar mais de uma vez por dia.
class RegistrarExercicioViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  RegistrarExercicioViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now;

  String? _tipo;
  String? get tipo => _tipo;

  int _minutos = MetaExercicio.minutosIniciais;
  int get minutos => _minutos;

  String? _intensidade;
  String? get intensidade => _intensidade;

  bool get podeDiminuir =>
      _minutos - MetaExercicio.passoMinutos >= MetaExercicio.minutosMinimos;

  bool get podeAumentar =>
      _minutos + MetaExercicio.passoMinutos <= MetaExercicio.minutosMaximos;

  // Falta escolher o exercicio ou a intensidade; somem quando escolhidos.
  String? _erroTipo;
  String? get erroTipo => _erroTipo;

  String? _erroIntensidade;
  String? get erroIntensidade => _erroIntensidade;

  // Falha ao gravar no Firestore.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  bool _salvando = false;
  bool get salvando => _salvando;

  void escolherTipo(String tipo) {
    _tipo = tipo;
    _erroTipo = null;
    notifyListeners();
  }

  void escolherIntensidade(String intensidade) {
    _intensidade = intensidade;
    _erroIntensidade = null;
    notifyListeners();
  }

  void diminuirMinutos() {
    if (!podeDiminuir) return;
    _minutos -= MetaExercicio.passoMinutos;
    notifyListeners();
  }

  void aumentarMinutos() {
    if (!podeAumentar) return;
    _minutos += MetaExercicio.passoMinutos;
    notifyListeners();
  }

  // Grava o exercicio. Retorna true se salvou.
  Future<bool> salvar() async {
    if (_salvando) return false;
    _mensagemErro = null;

    final tipo = _tipo;
    final intensidade = _intensidade;
    _erroTipo = tipo == null ? 'Escolha qual exercício você fez.' : null;
    _erroIntensidade =
        intensidade == null ? 'Escolha como foi a intensidade.' : null;
    if (tipo == null || intensidade == null) {
      notifyListeners();
      return false;
    }

    _salvando = true;
    notifyListeners();
    try {
      await _dadosRepository.salvarRegistro(RegistroExercicio(
        id: '',
        pacienteId: paciente.id,
        dataHora: _agora(),
        tipoExercicio: tipo,
        duracaoMinutos: _minutos,
        intensidade: intensidade,
      ));
      _salvando = false;
      notifyListeners();
      return true;
    } catch (erro) {
      debugPrint('Falha ao registrar o exercicio: $erro');
      _mensagemErro = 'Não foi possível salvar. Tente de novo.';
      _salvando = false;
      notifyListeners();
      return false;
    }
  }
}
