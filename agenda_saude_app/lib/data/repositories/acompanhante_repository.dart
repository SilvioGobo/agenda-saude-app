import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/acompanhante.dart';

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

  Future<void> vincularPaciente(String acompanhanteId, String pacienteId) async {
    await _firestore.collection('usuarios').doc(acompanhanteId).update({
      'pacientesVinculadosIds': FieldValue.arrayUnion([pacienteId]),
    });
  }

  Future<void> desvincularPaciente(String acompanhanteId, String pacienteId) async {
    await _firestore.collection('usuarios').doc(acompanhanteId).update({
      'pacientesVinculadosIds': FieldValue.arrayRemove([pacienteId]),
    });
  }
}