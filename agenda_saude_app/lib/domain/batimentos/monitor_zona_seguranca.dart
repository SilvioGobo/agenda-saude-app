import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../models/alerta.dart';
import '../models/batimento_cardiaco.dart';
import '../models/limites_alerta.dart';

// Regras dos alertas de BPM, sem Firebase (UC04.4 -> UC06 e RF06). Usadas
// igual pela leitura de 30 s com o app aberto (SincronizacaoBpmViewModel) e
// pela leitura a cada 15 min com o app fechado (B7, que comeca do zero a cada
// execucao). Por isso o estado pode ser retomado do que ja esta no Firestore:
// as leituras gravadas e os alertas ja gerados.
//
// - Emergencia: BPM fora da zona por `tempoProlongadoParaAlerta` seguidos; um
//   alerta so por episodio, e voltar para a zona encerra o episodio.
// - Atencao: o painel do paciente passa a mostrar "ATENÇÃO" (a leitura mais
//   recente sai da zona). So a passagem avisa, no maximo uma vez a cada
//   `intervaloMinimoEntreAvisos`, e nao junto de uma emergencia do mesmo
//   episodio, que ja avisou o acompanhante.
//
// A zona e a do paciente: os limites que o acompanhante definiu (RF 06.1) ou,
// sem eles, a padrao pela triagem (ZonaSegurancaCardiaca). Retomar com limites
// novos reavalia as leituras gravadas com eles, como a leitura com o app
// fechado faz a cada execucao.
class MonitorZonaSeguranca {
  final String pacienteId;
  final bool possuiCardiopatia;
  final LimitesAlerta? limites;

  // Leitura que o painel do paciente mostra agora (a mais recente gravada).
  BatimentoCardiaco? _leituraExibida;
  DateTime? _inicioForaDaZona;
  bool _emergenciaGeradaNoEpisodio = false;
  // Horario da leitura que gerou o ultimo aviso de "ATENÇÃO".
  DateTime? _ultimoAvisoDeAtencao;

  MonitorZonaSeguranca({
    required this.pacienteId,
    required this.possuiCardiopatia,
    this.limites,
  });

  // Retoma o estado a partir das leituras ja gravadas e dos alertas ja
  // gerados (ex.: das ultimas 12 h). O episodio em andamento sao as leituras
  // fora da zona seguidas no fim da lista; ele ja teve emergencia se ha um
  // alerta de emergencia desde o seu inicio.
  factory MonitorZonaSeguranca.retomar({
    required String pacienteId,
    required bool possuiCardiopatia,
    LimitesAlerta? limites,
    required List<BatimentoCardiaco> gravados,
    required List<Alerta> alertas,
  }) {
    final monitor = MonitorZonaSeguranca(
      pacienteId: pacienteId,
      possuiCardiopatia: possuiCardiopatia,
      limites: limites,
    );
    final ordenados = [...gravados]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (ordenados.isNotEmpty) {
      monitor._leituraExibida = ordenados.last;
      DateTime? inicio;
      for (final leitura in ordenados.reversed) {
        if (monitor._dentroDaZona(leitura.bpm)) break;
        inicio = leitura.timestamp;
      }
      monitor._inicioForaDaZona = inicio;
      monitor._emergenciaGeradaNoEpisodio = inicio != null &&
          alertas.any((alerta) =>
              alerta.ehEmergencia && !alerta.dataHora.isBefore(inicio!));
    }

    for (final alerta in alertas) {
      if (alerta.tipo != Alerta.tipoAtencao) continue;
      final ultimo = monitor._ultimoAvisoDeAtencao;
      if (ultimo == null || alerta.dataHora.isAfter(ultimo)) {
        monitor._ultimoAvisoDeAtencao = alerta.dataHora;
      }
    }
    return monitor;
  }

  // Avalia as leituras novas (ja gravadas) e devolve os alertas a gravar, na
  // ordem: as emergencias leitura a leitura e, por ultimo, o aviso de
  // "ATENÇÃO" pela leitura mais recente.
  List<Alerta> avaliar(List<BatimentoCardiaco> novas) {
    if (novas.isEmpty) return const [];
    final ordenadas = [...novas]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final alertas = <Alerta>[];
    for (final leitura in ordenadas) {
      final emergencia = _avaliarEpisodio(leitura);
      if (emergencia != null) alertas.add(emergencia);
    }
    final atencao = _avaliarAtencao(ordenadas.last);
    if (atencao != null) alertas.add(atencao);
    return alertas;
  }

  Alerta? _avaliarEpisodio(BatimentoCardiaco leitura) {
    if (_dentroDaZona(leitura.bpm)) {
      _inicioForaDaZona = null;
      _emergenciaGeradaNoEpisodio = false;
      return null;
    }

    final inicio = _inicioForaDaZona ??= leitura.timestamp;
    final duracao = leitura.timestamp.difference(inicio);
    if (_emergenciaGeradaNoEpisodio ||
        duracao < ZonaSegurancaCardiaca.tempoProlongadoParaAlerta) {
      return null;
    }

    _emergenciaGeradaNoEpisodio = true;
    return Alerta(
      id: '',
      pacienteId: pacienteId,
      tipo: Alerta.tipoEmergencia,
      mensagem: 'Batimentos fora da zona de segurança há '
          '${duracao.inMinutes} minutos (última leitura: ${leitura.bpm} BPM).',
      bpm: leitura.bpm,
      dataHora: leitura.timestamp,
    );
  }

  Alerta? _avaliarAtencao(BatimentoCardiaco maisRecente) {
    final anterior = _leituraExibida;
    // Leitura antiga que chegou atrasada nao muda o que o painel mostra.
    if (anterior != null &&
        !maisRecente.timestamp.isAfter(anterior.timestamp)) {
      return null;
    }
    _leituraExibida = maisRecente;

    final jaEstavaEmAtencao = anterior != null && !_dentroDaZona(anterior.bpm);
    if (_dentroDaZona(maisRecente.bpm) || jaEstavaEmAtencao) return null;

    // O alerta de emergencia deste mesmo episodio ja avisou o acompanhante.
    if (_emergenciaGeradaNoEpisodio) return null;

    final ultimoAviso = _ultimoAvisoDeAtencao;
    if (ultimoAviso != null &&
        maisRecente.timestamp.difference(ultimoAviso) <
            ZonaSegurancaCardiaca.intervaloMinimoEntreAvisos) {
      return null;
    }

    _ultimoAvisoDeAtencao = maisRecente.timestamp;
    final acima = ZonaSegurancaCardiaca.estaAcimaDaZona(
      maisRecente.bpm,
      possuiCardiopatia: possuiCardiopatia,
      limites: limites,
    );
    return Alerta(
      id: '',
      pacienteId: pacienteId,
      tipo: Alerta.tipoAtencao,
      mensagem: 'Batimentos ${acima ? 'acima' : 'abaixo'} da zona de '
          'segurança (${maisRecente.bpm} BPM).',
      bpm: maisRecente.bpm,
      dataHora: maisRecente.timestamp,
    );
  }

  bool _dentroDaZona(int bpm) => ZonaSegurancaCardiaca.estaDentroDaZona(
        bpm,
        possuiCardiopatia: possuiCardiopatia,
        limites: limites,
      );
}
