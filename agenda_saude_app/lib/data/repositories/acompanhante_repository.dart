import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';

class AcompanhanteRepository {

  final FirebaseFirestore _firestore;

  AcompanhanteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> salvarAcompanhante(Acompanhante acompanhante) async {
    await _firestore
        .collection('usuarios')
        .doc(acompanhante.id)
        .set(acompanhante.toJson());
  }

  Future<Acompanhante?> getAcompanhante(String id) async {
    final doc = await _firestore.collection('usuarios').doc(id).get();

    if (doc.exists && doc.data() != null) {
      return Acompanhante.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // Vinculo bidirecional (RF05.4): grava o paciente na lista do acompanhante
  // e o acompanhante na lista do paciente, no mesmo batch, para os dois lados
  // nunca ficarem inconsistentes. As security rules so aceitam a escrita no
  // doc do paciente se ela mexer apenas em `acompanhantesVinculadosIds`.
  Future<void> vincularPaciente(String acompanhanteId, String pacienteId) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('usuarios').doc(acompanhanteId), {
      'pacientesVinculadosIds': FieldValue.arrayUnion([pacienteId]),
    });
    batch.update(_firestore.collection('usuarios').doc(pacienteId), {
      'acompanhantesVinculadosIds': FieldValue.arrayUnion([acompanhanteId]),
    });
    await batch.commit();
  }

  Future<void> desvincularPaciente(String acompanhanteId, String pacienteId) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('usuarios').doc(acompanhanteId), {
      'pacientesVinculadosIds': FieldValue.arrayRemove([pacienteId]),
    });
    batch.update(_firestore.collection('usuarios').doc(pacienteId), {
      'acompanhantesVinculadosIds': FieldValue.arrayRemove([acompanhanteId]),
    });
    await batch.commit();
  }

  // Carrega os pacientes da lista de vinculados, um doc por vez: as security
  // rules autorizam a leitura individual de cada paciente vinculado, mas nao
  // conseguem provar isso para uma consulta em lote (`whereIn`).
  // Ids cujo doc nao existe mais sao ignorados.
  Future<List<Paciente>> listarPacientesVinculados(
    Acompanhante acompanhante,
  ) async {
    final docs = await Future.wait(
      acompanhante.pacientesVinculadosIds
          .map((id) => _firestore.collection('usuarios').doc(id).get()),
    );
    return docs
        .where((doc) => doc.exists && doc.data() != null)
        .map((doc) => Paciente.fromJson(doc.data()!, doc.id))
        .toList();
  }
}
