import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/localizacao.dart';

// Localizacao do paciente compartilhada com os acompanhantes vinculados.
// Doc `localizacoes/{pacienteId}`: o paciente grava (so o proprio doc) e os
// acompanhantes vinculados leem, como nas outras colecoes do paciente (NF005).
class LocalizacaoRepository {
  final FirebaseFirestore _firestore;

  LocalizacaoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String pacienteId) =>
      _firestore.collection('localizacoes').doc(pacienteId);

  Future<Localizacao?> getLocalizacao(String pacienteId) async {
    final doc = await _doc(pacienteId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Localizacao.fromJson(doc.data()!, doc.id);
  }

  // Localizacao do paciente em tempo real - usada pela tela do acompanhante.
  // Emite null enquanto o paciente nunca ligou o compartilhamento.
  Stream<Localizacao?> streamLocalizacao(String pacienteId) {
    return _doc(pacienteId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Localizacao.fromJson(doc.data()!, doc.id);
    });
  }

  // Sobrescreve o doc inteiro: a posicao anterior nao fica guardada.
  Future<void> salvarLocalizacao(Localizacao localizacao) async {
    await _doc(localizacao.pacienteId).set(localizacao.toJson());
  }

  // Liga o compartilhamento antes da primeira posicao chegar, para o app
  // retomar sozinho na proxima vez que for aberto.
  Future<void> ativarCompartilhamento(String pacienteId) {
    return salvarLocalizacao(Localizacao(pacienteId: pacienteId, ativo: true));
  }

  // Desliga e apaga a ultima posicao, para o acompanhante nao continuar
  // vendo onde o paciente estava.
  Future<void> desativarCompartilhamento(String pacienteId) {
    return salvarLocalizacao(Localizacao(pacienteId: pacienteId, ativo: false));
  }
}
