import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/registro_agua.dart';
import '../../domain/models/registro_sono.dart';
import '../../domain/models/registro_exercicio.dart';
import '../../domain/models/registro_diabete.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/registro_base.dart';

class DadosMedicosRepository {
  final FirebaseFirestore _firestore;

  DadosMedicosRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> salvarRegistro(RegistroBase registro) async {
    await _firestore.collection('registros_diarios').add(registro.toJson());
  }

  Future<void> salvarBatimento(BatimentoCardiaco batimento) async {
    await _firestore.collection('batimentos_cardiacos').add(batimento.toJson());
  }

  Future<void> gerarAlerta(Alerta alerta) async {
    await _firestore.collection('alertas').add(alerta.toJson());
  }

  Future<List<Alerta>> getAlertas(String pacienteId) async {
    final snapshot = await _firestore
        .collection('alertas')
        .where('pacienteId', isEqualTo: pacienteId)
        .orderBy('dataHora', descending: true)
        .get();

    return snapshot.docs.map((doc) => Alerta.fromJson(doc.data(), doc.id)).toList();
  }
}