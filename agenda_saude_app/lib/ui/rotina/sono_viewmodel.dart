import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_sono.dart';
import 'registrar_sono_viewmodel.dart';

// Estado do cartao "Sono" da rotina diaria (RF03.2): a noite que o paciente
// registrou hoje, ao acordar, com as horas dormidas e a qualidade de 1 a 5.
// Gravar e corrigir a noite e com o [RegistrarSonoViewModel]; este so acompanha
// o Firestore em tempo real, entao o acompanhante - que le a mesma colecao - ve
// a mesma noite do paciente.
class SonoViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  StreamSubscription<List<RegistroSono>>? _assinatura;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  SonoViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now {
    _observarDia();
  }

  // Do mais recente para o mais antigo. Costuma haver um so por dia.
  List<RegistroSono> _registros = const [];

  // A noite de hoje; se ha mais de uma (dois aparelhos), a mais recente. Null
  // enquanto o paciente nao registrou.
  RegistroSono? get registroDeHoje =>
      _registros.isEmpty ? null : _registros.first;

  bool get registrou => registroDeHoje != null;

  // Verdadeiro ate o Firestore entregar a primeira lista do dia.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura do dia falhou (ex.: sem permissao ou indice faltando): o que
  // esta registrado nao e confiavel, entao a tela esconde o resumo.
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  // Meta do paciente (calculada na triagem); contas sem metas usam 7 a 9 horas.
  int get metaMinHoras => paciente.metaSonoMinHoras;

  int get metaMaxHoras => paciente.metaSonoMaxHoras;

  // Dormiu pelo menos o minimo da meta. Passar do maximo nao tira a meta: o
  // app nao chama de "ruim" quem dormiu mais.
  bool get metaAtingida {
    final registro = registroDeHoje;
    return registro != null && registro.horasTotais >= metaMinHoras;
  }

  // O formulario para registrar a noite de hoje - ou corrigi-la, se ja foi
  // registrada. Usa o mesmo Firestore e o mesmo relogio deste ViewModel.
  RegistrarSonoViewModel novoRegistro() {
    return RegistrarSonoViewModel(
      paciente: paciente,
      registroAtual: registroDeHoje,
      dadosRepository: _dadosRepository,
      agora: _agora,
    );
  }

  // Passa a acompanhar o dia atual e agenda a virada para o proximo, para o
  // cartao voltar a "ainda nao registrado" a meia-noite mesmo com a tela aberta.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinatura?.cancel();
    _assinatura = _dadosRepository.streamSonoDoDia(paciente.id, _dia).listen(
      (registros) {
        _registros = registros;
        _carregando = false;
        _erroDeLeitura = false;
        notifyListeners();
      },
      onError: (Object erro) {
        debugPrint('Stream de sono falhou: $erro');
        _carregando = false;
        _erroDeLeitura = true;
        notifyListeners();
      },
    );

    _timerViradaDoDia?.cancel();
    final meiaNoite = DateTime(_dia.year, _dia.month, _dia.day + 1);
    _timerViradaDoDia = Timer(meiaNoite.difference(agora), _aoVirarODia);
  }

  void _aoVirarODia() {
    _registros = const [];
    _carregando = true;
    _observarDia();
    notifyListeners();
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    _timerViradaDoDia?.cancel();
    super.dispose();
  }
}
