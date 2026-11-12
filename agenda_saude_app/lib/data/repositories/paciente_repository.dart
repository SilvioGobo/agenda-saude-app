import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/codigo_vinculo.dart';
import '../../domain/models/medicamento.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/refeicao_planejada.dart';

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

  // Grava so as metas do paciente (e, ao recalcular, o peso e o nivel de
  // atividade que as originaram), sem reescrever o resto do documento.
  Future<void> atualizarMetas(
    String pacienteId,
    MetasPersonalizadas metas, {
    double? pesoKg,
    String? nivelAtividadeFisica,
  }) async {
    await _firestore.collection('usuarios').doc(pacienteId).update({
      'metas': metas.toJson(),
      if (pesoKg != null) 'pesoKg': pesoKg,
      if (nivelAtividadeFisica != null)
        'nivelAtividadeFisica': nivelAtividadeFisica,
    });
  }

  // Grava o plano de refeicoes personalizado (RF03.4) sem reescrever o resto
  // do documento do paciente.
  Future<void> salvarRefeicoes(
    String pacienteId,
    List<RefeicaoPlanejada> refeicoes,
  ) async {
    await _firestore.collection('usuarios').doc(pacienteId).update({
      'refeicoes': refeicoes.map((refeicao) => refeicao.toJson()).toList(),
    });
  }

  // Grava a lista de remedios do paciente (RF003) sem reescrever o resto do
  // documento dele. A lista inteira substitui a antiga; vazia = sem remedios.
  Future<void> salvarMedicamentos(
    String pacienteId,
    List<Medicamento> medicamentos,
  ) async {
    await _firestore.collection('usuarios').doc(pacienteId).update({
      'medicamentos':
          medicamentos.map((medicamento) => medicamento.toJson()).toList(),
    });
  }

  // Grava as alergias do paciente ("Minhas alergias") sem reescrever o resto
  // do documento: as dos dois catalogos e o texto das outras (vazio apaga).
  Future<void> salvarAlergias(
    String pacienteId, {
    required List<String> alimentos,
    required List<String> remedios,
    String outras = '',
  }) async {
    await _firestore.collection('usuarios').doc(pacienteId).update({
      'alergiasAlimentos': alimentos,
      'alergiasRemedios': remedios,
      'alergias': outras.trim().isEmpty ? null : outras.trim(),
    });
  }

  // Os campos que a triagem preenche. "Meus dados" grava so eles (e as metas,
  // recalculadas com eles): o plano de refeicoes, os remedios, os limites de
  // alerta e as tarefas do dia ficam como estao.
  static const camposDaTriagem = [
    'possuiDiabetes',
    'tipoDiabetes',
    'usaInsulina',
    'tipoInsulina',
    'possuiCardiopatia',
    'tipoCardiopatia',
    'usaMarcapasso',
    'limiteLiquidoMl',
    'dataNascimento',
    'sexoBiologico',
    'alturaCm',
    'pesoKg',
    'nivelAtividadeFisica',
    'alergias',
    'alergiasAlimentos',
    'alergiasRemedios',
    'medicamentosEmUso',
    'triagemConcluida',
    'metas',
  ];

  Future<void> atualizarTriagem(Paciente paciente) async {
    final json = paciente.toJson();
    await _firestore.collection('usuarios').doc(paciente.id).update({
      for (final campo in camposDaTriagem) campo: json[campo],
    });
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
