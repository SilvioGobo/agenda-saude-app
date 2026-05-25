import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/paciente.dart';

class PacienteRepository {
  final FirebaseFirestore _firestore;

  // Permite injetar o banco falso nos testes, ou usa o real no app
  PacienteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> salvarPaciente(Paciente paciente) async {
    await _firestore.collection('usuarios').doc(paciente.id).set(paciente.toJson());
  }

  Future<Paciente?> getPaciente(String id) async {
    final doc = await _firestore.collection('usuarios').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Paciente.fromJson(doc.data()!, doc.id);
    }
    return null;
  }
}