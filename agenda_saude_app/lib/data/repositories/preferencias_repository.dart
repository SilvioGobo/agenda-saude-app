import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/momentos_glicemia.dart';
import '../../domain/acessibilidade/configuracao_narrador.dart';
import '../../domain/medicacao/horario_medicacao.dart';

// Preferencias que ficam so no aparelho, no `shared_preferences`: nada daqui vai
// para o Firestore. Servem ao que e do celular e nao da conta, como os
// lembretes (a notificacao agendada e daquele aparelho) e o narrador de voz.
class PreferenciasRepository {
  final Future<SharedPreferences> Function() _abrir;

  // [abrir] permite aos testes trocar o armazenamento por um em memoria.
  PreferenciasRepository({Future<SharedPreferences> Function()? abrir})
      : _abrir = abrir ?? SharedPreferences.getInstance;

  // --- Lembretes (RF 07.3) ---
  // Valem por paciente: quem entra depois no mesmo celular nao herda os
  // horarios de outro.

  static String _chaveLembretesLigados(String pacienteId) =>
      'lembretes.ligados.$pacienteId';

  static String _chaveHorario(String pacienteId, String nomeDoMomento) =>
      'lembretes.horario.$pacienteId.$nomeDoMomento';

  // Os lembretes vem ligados: quem nao mexeu na configuracao quer ser avisado.
  Future<bool> lembretesLigados(String pacienteId) async {
    final preferencias = await _abrir();
    return preferencias.getBool(_chaveLembretesLigados(pacienteId)) ?? true;
  }

  Future<void> salvarLembretesLigados(String pacienteId, bool ligados) async {
    final preferencias = await _abrir();
    await preferencias.setBool(_chaveLembretesLigados(pacienteId), ligados);
  }

  // Os horarios que o paciente escolheu para os momentos da glicemia (nome do
  // momento -> "HH:MM"). Momento sem horario escolhido fica de fora e usa o
  // padrao; um valor salvo que nao e uma hora valida tambem e ignorado.
  Future<Map<String, String>> horariosDosMomentos(String pacienteId) async {
    final preferencias = await _abrir();
    final horarios = <String, String>{};
    for (final momento in MomentoGlicemia.todos) {
      final salvo = preferencias.getString(_chaveHorario(pacienteId, momento.nome));
      final horario = salvo == null ? null : normalizarHorario(salvo);
      if (horario != null) horarios[momento.nome] = horario;
    }
    return horarios;
  }

  // Guarda o horario escolhido para um momento; null volta ao padrao.
  Future<void> salvarHorarioDoMomento(
    String pacienteId,
    String nomeDoMomento,
    String? horario,
  ) async {
    final preferencias = await _abrir();
    final chave = _chaveHorario(pacienteId, nomeDoMomento);
    if (horario == null) {
      await preferencias.remove(chave);
    } else {
      await preferencias.setString(chave, horario);
    }
  }

  // --- Narrador de voz (RF 07 e RF 08) ---
  // Valem para o aparelho todo, e nao por paciente: a configuracao de
  // acessibilidade "permanece ativa globalmente ate que o usuario a desative".

  static const _chaveNarradorLigado = 'narrador.ligado';
  static const _chaveNarradorVelocidade = 'narrador.velocidade';

  // O narrador vem desligado, na velocidade normal.
  Future<ConfiguracaoNarrador> narrador() async {
    final preferencias = await _abrir();
    return ConfiguracaoNarrador(
      ligado: preferencias.getBool(_chaveNarradorLigado) ?? false,
      velocidade: VelocidadeNarracao.porNome(
        preferencias.getString(_chaveNarradorVelocidade),
      ),
    );
  }

  Future<void> salvarNarradorLigado(bool ligado) async {
    final preferencias = await _abrir();
    await preferencias.setBool(_chaveNarradorLigado, ligado);
  }

  Future<void> salvarVelocidadeDoNarrador(VelocidadeNarracao velocidade) async {
    final preferencias = await _abrir();
    await preferencias.setString(_chaveNarradorVelocidade, velocidade.name);
  }
}
