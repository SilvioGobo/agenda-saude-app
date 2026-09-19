import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/codigo_vinculo.dart';
import '../../domain/models/paciente.dart';

class PacienteRepository {
  final FirebaseFirestore _firestore;

  // Permite injetar o banco falso nos testes, ou usa o real no app
  PacienteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Grava o paciente e, no mesmo batch, publica o codigo de vinculo dele em
  // `codigos_vinculo/{codigo}` - e por esse doc que o Acompanhante descobre
  // o paciente (RF05.4), ja que as security rules nao deixam ler
  // `usuarios/{uid}` antes do vinculo existir (NF005).
  Future<void> salvarPaciente(Paciente paciente) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('usuarios').doc(paciente.id),
      paciente.toJson(),
    );
    if (paciente.codigoVinculo.isNotEmpty) {
      batch.set(
        _firestore.collection('codigos_vinculo').doc(paciente.codigoVinculo),
        CodigoVinculo(
          codigo: paciente.codigoVinculo,
          pacienteId: paciente.id,
          nomePaciente: paciente.nome,
        ).toJson(),
      );
    }
    await batch.commit();
  }

  Future<Paciente?> getPaciente(String id) async {
    final doc = await _firestore.collection('usuarios').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Paciente.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // Garante que o codigo do paciente esteja publicado em `codigos_vinculo`.
  // Serve para contas criadas antes desse modulo existir, que tem o codigo no
  // proprio doc mas ainda nao tem a entrada de consulta.
  Future<void> publicarCodigoVinculo(Paciente paciente) async {
    if (paciente.codigoVinculo.isEmpty) return;
    await _firestore
        .collection('codigos_vinculo')
        .doc(paciente.codigoVinculo)
        .set(
          CodigoVinculo(
            codigo: paciente.codigoVinculo,
            pacienteId: paciente.id,
            nomePaciente: paciente.nome,
          ).toJson(),
        );
  }

  // Busca quem esta por tras de um codigo de vinculo. O codigo e normalizado
  // (maiusculas, sem espacos) porque sera digitado a mao pelo acompanhante.
  Future<CodigoVinculo?> buscarPorCodigoVinculo(String codigo) async {
    final codigoNormalizado = normalizarCodigoVinculo(codigo);
    if (codigoNormalizado.isEmpty) return null;

    final doc = await _firestore
        .collection('codigos_vinculo')
        .doc(codigoNormalizado)
        .get();
    if (doc.exists && doc.data() != null) {
      return CodigoVinculo.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  static String normalizarCodigoVinculo(String codigo) {
    return codigo.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }
}
