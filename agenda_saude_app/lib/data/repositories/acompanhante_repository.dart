import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  // Aparelhos do acompanhante que recebem o push dos alertas (B6): a Cloud
  // Function le `usuarios/{uid}.fcmTokens` e manda para cada um. Uma lista,
  // porque a mesma conta pode estar em mais de um celular. As security rules
  // ja deixam o dono mexer no proprio documento.
  Future<void> adicionarTokenPush(String acompanhanteId, String token) async {
    await _firestore.collection('usuarios').doc(acompanhanteId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  // Ao sair da conta, este aparelho deixa de receber os alertas.
  Future<void> removerTokenPush(String acompanhanteId, String token) async {
    await _firestore.collection('usuarios').doc(acompanhanteId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
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

  // Acompanhantes de um paciente, para ele ligar (Figura 13: "Falar com
  // Acompanhante"). Rele o doc do paciente, porque um vinculo novo pode ter
  // chegado depois do login, e carrega cada acompanhante um doc por vez: as
  // security rules deixam o paciente ler so o doc de quem tem o UID dele em
  // `pacientesVinculadosIds`. Um acompanhante que nao da para ler (doc
  // apagado ou vinculo desfeito no meio do caminho) fica de fora; se nenhum
  // der para ler, e erro (ex.: rules sem essa regra publicadas), e nao
  // "paciente sem acompanhante".
  Future<List<Acompanhante>> listarAcompanhantesDoPaciente(
    String pacienteId,
  ) async {
    final docPaciente =
        await _firestore.collection('usuarios').doc(pacienteId).get();
    final ids = List<String>.from(
      docPaciente.data()?['acompanhantesVinculadosIds'] ?? [],
    );

    Object? ultimoErro;
    final acompanhantes = await Future.wait(ids.map((id) async {
      try {
        final doc = await _firestore.collection('usuarios').doc(id).get();
        if (!doc.exists || doc.data() == null) return null;
        return Acompanhante.fromJson(doc.data()!, doc.id);
      } catch (erro) {
        debugPrint('Nao foi possivel ler o acompanhante $id: $erro');
        ultimoErro = erro;
        return null;
      }
    }));

    final lidos = acompanhantes.whereType<Acompanhante>().toList();
    if (lidos.isEmpty && ultimoErro != null) throw ultimoErro!;
    return lidos;
  }
}
