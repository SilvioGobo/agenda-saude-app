import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/alerta.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/registro_agua.dart';
import '../../domain/models/registro_diabete.dart';
import '../../domain/models/registro_refeicao.dart';

// Tudo o que o paciente registrou num periodo, exceto os batimentos.
class RegistrosDoPeriodo {
  final List<RegistroAgua> agua;
  final List<RegistroRefeicao> refeicoes;
  final List<RegistroDiabete> diabete;
  final List<Alerta> alertas;

  const RegistrosDoPeriodo({
    this.agua = const [],
    this.refeicoes = const [],
    this.diabete = const [],
    this.alertas = const [],
  });
}

// Leituras do Firestore que alimentam os relatorios do dia e do mes (RF05).
// So le: gravar continua com o DadosMedicosRepository. Cada consulta pega o
// intervalo [inicio, fim) no horario do aparelho e usa o mesmo formato das
// consultas ja existentes, entao reaproveita os indices de
// firestore.indexes.json (nenhum indice novo). O acompanhante vinculado le
// os mesmos documentos do paciente, pelas mesmas security rules.
class RelatoriosRepository {
  final FirebaseFirestore _firestore;

  RelatoriosRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Agua, refeicoes, glicemia/insulina e alertas do periodo, em consultas
  // paralelas. A glicemia so e buscada de quem tem diabetes.
  Future<RegistrosDoPeriodo> registrosDoPeriodo(
    String pacienteId,
    DateTime inicio,
    DateTime fim, {
    required bool incluirDiabete,
  }) async {
    final (agua, refeicoes, diabete, alertas) = await (
      _registros(pacienteId, 'agua', inicio, fim, RegistroAgua.fromJson),
      _registros(pacienteId, 'refeicao', inicio, fim, RegistroRefeicao.fromJson),
      incluirDiabete
          ? _registros(pacienteId, 'diabete', inicio, fim, RegistroDiabete.fromJson)
          : Future.value(const <RegistroDiabete>[]),
      _alertas(pacienteId, inicio, fim),
    ).wait;

    return RegistrosDoPeriodo(
      agua: agua,
      refeicoes: refeicoes,
      diabete: diabete,
      alertas: alertas,
    );
  }

  // Leituras de BPM do periodo, da mais recente para a mais antiga. Um dia
  // tem de centenas a poucos milhares de leituras; por isso so o relatorio do
  // dia usa esta consulta - o do mes nao le batimentos, so os alertas.
  Future<List<BatimentoCardiaco>> batimentosDoPeriodo(
    String pacienteId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final snapshot = await _firestore
        .collection('batimentos_cardiacos')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('timestamp', isGreaterThanOrEqualTo: inicio)
        .where('timestamp', isLessThan: fim)
        // mesma ordem das outras consultas: reaproveita o indice existente
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BatimentoCardiaco.fromJson(doc.data(), doc.id))
        .toList();
  }

  // Registros de um [tipo] (o campo `tipo` gravado por cada RegistroBase), do
  // mais recente para o mais antigo. Mesma consulta do dia a dia
  // (pacienteId + tipo + dataHora), agora com um intervalo maior.
  Future<List<T>> _registros<T>(
    String pacienteId,
    String tipo,
    DateTime inicio,
    DateTime fim,
    T Function(Map<String, dynamic> json, String documentId) converter,
  ) async {
    final snapshot = await _firestore
        .collection('registros_diarios')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('tipo', isEqualTo: tipo)
        .where('dataHora', isGreaterThanOrEqualTo: inicio)
        .where('dataHora', isLessThan: fim)
        .orderBy('dataHora', descending: true)
        .get();

    return snapshot.docs.map((doc) => converter(doc.data(), doc.id)).toList();
  }

  Future<List<Alerta>> _alertas(
    String pacienteId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final snapshot = await _firestore
        .collection('alertas')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('dataHora', isGreaterThanOrEqualTo: inicio)
        .where('dataHora', isLessThan: fim)
        .orderBy('dataHora', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Alerta.fromJson(doc.data(), doc.id))
        .toList();
  }
}
