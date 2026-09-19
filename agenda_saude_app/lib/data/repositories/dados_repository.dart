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

  // Grava varias leituras de uma vez (sincronizacao com o smartwatch traz
  // lotes). O Firestore limita cada WriteBatch a 500 operacoes.
  Future<void> salvarBatimentos(List<BatimentoCardiaco> batimentos) async {
    const tamanhoLote = 500;
    for (var i = 0; i < batimentos.length; i += tamanhoLote) {
      final lote = _firestore.batch();
      final fim = (i + tamanhoLote < batimentos.length)
          ? i + tamanhoLote
          : batimentos.length;
      for (final batimento in batimentos.sublist(i, fim)) {
        lote.set(
          _firestore.collection('batimentos_cardiacos').doc(),
          batimento.toJson(),
        );
      }
      await lote.commit();
    }
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

  // Leitura de BPM mais recente ja gravada (consulta unica). A sincronizacao
  // com o smartwatch usa o timestamp dela para importar so o que e novo.
  Future<BatimentoCardiaco?> getUltimoBatimento(String pacienteId) async {
    final snapshot = await _firestore
        .collection('batimentos_cardiacos')
        .where('pacienteId', isEqualTo: pacienteId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return BatimentoCardiaco.fromJson(doc.data(), doc.id);
  }

  // Leitura de BPM mais recente do paciente, em tempo real (RF04.3, NF003) -
  // usada no destaque de batimentos do painel principal (Figura 13).
  Stream<BatimentoCardiaco?> streamUltimoBatimento(String pacienteId) {
    return _firestore
        .collection('batimentos_cardiacos')
        .where('pacienteId', isEqualTo: pacienteId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return BatimentoCardiaco.fromJson(doc.data(), doc.id);
    });
  }
}