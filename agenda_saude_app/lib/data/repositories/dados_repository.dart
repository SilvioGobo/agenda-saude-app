import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/meta_exercicio.dart';
import '../../domain/models/registro_agua.dart';
import '../../domain/models/registro_medicacao.dart';
import '../../domain/models/registro_refeicao.dart';
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

  Future<void> removerRegistro(String registroId) async {
    await _firestore.collection('registros_diarios').doc(registroId).delete();
  }

  // Troca o conteudo de um registro que ja existe (ex.: o paciente corrige as
  // horas de sono de hoje), mantendo o mesmo documento. As security rules so
  // deixam o dono do registro fazer isso.
  Future<void> atualizarRegistro(
    String registroId,
    RegistroBase registro,
  ) async {
    await _firestore
        .collection('registros_diarios')
        .doc(registroId)
        .set(registro.toJson());
  }

  // Registros de agua do paciente no dia de [dia] (do primeiro ao ultimo
  // instante no horario do aparelho), do mais recente para o mais antigo, em
  // tempo real - alimenta a barra de progresso da hidratacao (RF03.1).
  Stream<List<RegistroAgua>> streamAguaDoDia(String pacienteId, DateTime dia) {
    return _registrosDoDia(pacienteId, 'agua', dia)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroAgua.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Noite de sono registrada no dia de [dia], em tempo real - alimenta o
  // cartao "Sono" da rotina (RF03.2). O paciente registra ao acordar, entao a
  // noite cai no dia em que ele acordou (ver RegistroSono). Costuma ser um so
  // registro; vem do mais recente para o mais antigo.
  Stream<List<RegistroSono>> streamSonoDoDia(String pacienteId, DateTime dia) {
    return _registrosDoDia(pacienteId, 'sono', dia)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroSono.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Doses de remedio que o paciente marcou como tomadas no dia de [dia], em
  // tempo real - alimenta o cartao "Medicacoes" da rotina (RF003, Figura 14).
  // Do mais recente para o mais antigo. Usa o mesmo indice das outras
  // consultas de registros do dia.
  Stream<List<RegistroMedicacao>> streamMedicacoesDoDia(
    String pacienteId,
    DateTime dia,
  ) {
    return _registrosDoDia(pacienteId, 'medicacao', dia)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroMedicacao.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Exercicios da semana (de domingo a sabado) que contem [dia], em tempo real
  // - alimenta o cartao "Exercicio" da rotina (RF03.3): os de hoje e o
  // progresso da meta de minutos da semana. Do mais recente para o mais antigo.
  Stream<List<RegistroExercicio>> streamExerciciosDaSemana(
    String pacienteId,
    DateTime dia,
  ) {
    final inicio = MetaExercicio.inicioDaSemana(dia);
    final fim = DateTime(inicio.year, inicio.month, inicio.day + 7);

    return _registrosEntre(pacienteId, 'exercicio', inicio, fim)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroExercicio.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Medicoes de glicemia e aplicacoes de insulina do paciente no dia de
  // [dia], do mais recente para o mais antigo, em tempo real - alimenta o
  // checklist "Glicemia e Insulina" da rotina (RF008).
  Stream<List<RegistroDiabete>> streamDiabeteDoDia(
    String pacienteId,
    DateTime dia,
  ) {
    return _registrosDoDia(pacienteId, 'diabete', dia)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroDiabete.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Ultimos registros de diabetes do paciente, do mais recente para o mais
  // antigo, em tempo real. O card do acompanhante tira deles a ultima
  // glicemia e a ultima dose de insulina (Figura 15); [limite] cobre cerca
  // de dois dias de checklist completo.
  Stream<List<RegistroDiabete>> streamUltimosRegistrosDiabete(
    String pacienteId, {
    int limite = 10,
  }) {
    return _firestore
        .collection('registros_diarios')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('tipo', isEqualTo: 'diabete')
        .orderBy('dataHora', descending: true)
        .limit(limite)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroDiabete.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Registro mais recente da rotina do paciente, de qualquer tipo (agua,
  // refeicao, glicemia/insulina...), em tempo real: a "ultima atividade da
  // rotina" do card do acompanhante (Figura 15). Usa o indice composto de
  // registros_diarios (pacienteId + dataHora) de firestore.indexes.json.
  Stream<RegistroBase?> streamUltimaAtividade(String pacienteId) {
    return _firestore
        .collection('registros_diarios')
        .where('pacienteId', isEqualTo: pacienteId)
        .orderBy('dataHora', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return _registroDoTipo(doc.data(), doc.id);
    });
  }

  // Monta a subclasse de RegistroBase pelo campo `tipo` gravado no toJson()
  // de cada uma. Null para um tipo que esta versao do app nao conhece: cada
  // atividade nova da rotina precisa entrar aqui.
  static RegistroBase? _registroDoTipo(Map<String, dynamic> json, String id) {
    switch (json['tipo']) {
      case 'agua':
        return RegistroAgua.fromJson(json, id);
      case 'refeicao':
        return RegistroRefeicao.fromJson(json, id);
      case 'diabete':
        return RegistroDiabete.fromJson(json, id);
      case 'sono':
        return RegistroSono.fromJson(json, id);
      case 'exercicio':
        return RegistroExercicio.fromJson(json, id);
      case 'medicacao':
        return RegistroMedicacao.fromJson(json, id);
    }
    return null;
  }

  // Registros de um [tipo] no dia de [dia] (do primeiro ao ultimo instante no
  // horario do aparelho). Usa o indice composto de registros_diarios
  // (pacienteId + tipo + dataHora) de firestore.indexes.json.
  Query<Map<String, dynamic>> _registrosDoDia(
    String pacienteId,
    String tipo,
    DateTime dia,
  ) {
    return _registrosEntre(
      pacienteId,
      tipo,
      DateTime(dia.year, dia.month, dia.day),
      DateTime(dia.year, dia.month, dia.day + 1),
    );
  }

  // Registros de um [tipo] no intervalo [inicio, fim), do mais recente para o
  // mais antigo. Mesma consulta e mesmo indice do dia a dia, com um intervalo
  // maior.
  Query<Map<String, dynamic>> _registrosEntre(
    String pacienteId,
    String tipo,
    DateTime inicio,
    DateTime fim,
  ) {
    return _firestore
        .collection('registros_diarios')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('tipo', isEqualTo: tipo)
        .where('dataHora', isGreaterThanOrEqualTo: inicio)
        .where('dataHora', isLessThan: fim)
        .orderBy('dataHora', descending: true);
  }

  // Refeicoes que o paciente marcou como feitas no dia de [dia], em tempo real
  // (RF03.4). Usa o mesmo indice de `registros_diarios` da hidratacao.
  Stream<List<RegistroRefeicao>> streamRefeicoesDoDia(
    String pacienteId,
    DateTime dia,
  ) {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = DateTime(dia.year, dia.month, dia.day + 1);

    return _firestore
        .collection('registros_diarios')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('tipo', isEqualTo: 'refeicao')
        .where('dataHora', isGreaterThanOrEqualTo: inicio)
        .where('dataHora', isLessThan: fim)
        .orderBy('dataHora', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroRefeicao.fromJson(doc.data(), doc.id))
            .toList());
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

  // Alertas do paciente gerados a partir de [desde], do mais novo para o mais
  // antigo. A leitura do BPM (com o app aberto ou fechado) retoma por eles o
  // episodio fora da zona, para nao repetir um alerta ja dado. Mesmo indice
  // de `streamAlertas` (pacienteId + dataHora).
  Future<List<Alerta>> getAlertasDesde(String pacienteId, DateTime desde) async {
    final snapshot = await _firestore
        .collection('alertas')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('dataHora', isGreaterThanOrEqualTo: desde)
        .orderBy('dataHora', descending: true)
        .get();

    return snapshot.docs.map((doc) => Alerta.fromJson(doc.data(), doc.id)).toList();
  }

  // Alertas mais recentes do paciente em tempo real (RF06), do mais novo para
  // o mais antigo - usados pela central de notificacoes do acompanhante.
  // `doServidor` e falso enquanto a lista vem so do cache local do aparelho
  // (ex.: ao abrir o app), antes de o Firestore confirmar o estado atual.
  Stream<({List<Alerta> alertas, bool doServidor})> streamAlertas(
    String pacienteId, {
    int limite = 50,
  }) {
    return _firestore
        .collection('alertas')
        .where('pacienteId', isEqualTo: pacienteId)
        .orderBy('dataHora', descending: true)
        .limit(limite)
        .snapshots()
        .map((snapshot) => (
              alertas: snapshot.docs
                  .map((doc) => Alerta.fromJson(doc.data(), doc.id))
                  .toList(),
              doServidor: !snapshot.metadata.isFromCache,
            ));
  }

  // As security rules so deixam o acompanhante (ou o paciente) mudar o campo
  // `lido` de um alerta. O Firestore limita cada WriteBatch a 500 operacoes.
  Future<void> marcarAlertasComoLidos(List<String> alertaIds) async {
    const tamanhoLote = 500;
    for (var i = 0; i < alertaIds.length; i += tamanhoLote) {
      final lote = _firestore.batch();
      final fim = (i + tamanhoLote < alertaIds.length)
          ? i + tamanhoLote
          : alertaIds.length;
      for (final id in alertaIds.sublist(i, fim)) {
        lote.update(_firestore.collection('alertas').doc(id), {'lido': true});
      }
      await lote.commit();
    }
  }

  // Leituras de BPM gravadas a partir de [desde]. A sincronizacao com o
  // smartwatch usa essa lista para nao regravar o que ja foi importado.
  Future<List<BatimentoCardiaco>> getBatimentosDesde(
    String pacienteId,
    DateTime desde,
  ) async {
    final snapshot = await _firestore
        .collection('batimentos_cardiacos')
        .where('pacienteId', isEqualTo: pacienteId)
        .where('timestamp', isGreaterThanOrEqualTo: desde)
        // mesma ordem das outras consultas: reaproveita o indice existente
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BatimentoCardiaco.fromJson(doc.data(), doc.id))
        .toList();
  }

  // Leitura de BPM mais recente ja gravada (consulta unica).
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