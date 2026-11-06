import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/telefones_emergencia.dart';
import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../core/services/telefone_service.dart';
import '../../core/theme/app_cores.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_ligar.dart';
import 'card_alerta.dart';

// Tela de emergencia do acompanhante (Figura 16 do TCC, RF06.2 e RF06.4):
// toma a tela inteira em vermelho para interromper o que ele estiver
// fazendo, mostra o BPM critico do alerta e oferece, em botoes grandes,
// ligar para o paciente (so se ele tem telefone cadastrado), ligar para o
// SAMU (192) e ver onde ele esta. Abre pela notificacao de emergencia e pelo
// alerta de emergencia na tela de Notificacoes.
class EmergenciaView extends StatelessWidget {
  final Alerta alerta;
  final String nomePaciente;
  // Null quando o paciente ja foi desvinculado: sem ligar para ele.
  final Paciente? paciente;
  // Tela "Onde está..." do paciente; null esconde o botao.
  final WidgetBuilder? telaDeLocalizacao;
  // Permitem aos testes trocar o discador e o relogio por falsos.
  final TelefoneService? telefoneService;
  final DateTime? agora;

  const EmergenciaView({
    super.key,
    required this.alerta,
    required this.nomePaciente,
    this.paciente,
    this.telaDeLocalizacao,
    this.telefoneService,
    this.agora,
  });

  String get _primeiroNome {
    final nome = nomePaciente.trim();
    return nome.isEmpty ? 'o paciente' : nome.split(RegExp(r'\s+')).first;
  }

  bool get _podeLigarParaPaciente => paciente?.temTelefone ?? false;

  // O que saiu da zona de seguranca do paciente (UC04.4), em caixa alta.
  String get _motivo {
    final bpm = alerta.bpm;
    final cardiopata = paciente?.possuiCardiopatia ?? false;
    if (bpm != null &&
        bpm > ZonaSegurancaCardiaca.bpmMaximo(possuiCardiopatia: cardiopata)) {
      return 'BATIMENTOS CARDÍACOS ELEVADOS';
    }
    if (bpm != null &&
        bpm < ZonaSegurancaCardiaca.bpmMinimo(possuiCardiopatia: cardiopata)) {
      return 'BATIMENTOS CARDÍACOS BAIXOS';
    }
    return 'BATIMENTOS FORA DA ZONA DE SEGURANÇA';
  }

  String get _orientacao {
    final contato = _podeLigarParaPaciente
        ? 'Ligue agora para $_primeiroNome para saber como está.'
        : 'Fale com $_primeiroNome agora para saber como está.';
    final endereco = telaDeLocalizacao != null
        ? ' e informe o endereço que aparece em "Ver localização"'
        : '';
    return '$contato Se não atender ou relatar mal-estar, ligue para o SAMU '
        '(192)$endereco.';
  }

  void _verLocalizacao(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: telaDeLocalizacao!));
  }

  @override
  Widget build(BuildContext context) {
    final paciente = this.paciente;
    // "Voltar" em branco: o verde do tema some no fundo vermelho.
    final temaDaBarra = Theme.of(context).copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      ),
    );

    return Scaffold(
      backgroundColor: AppCores.perigo,
      appBar: AppBar(
        backgroundColor: AppCores.perigo,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: Theme(
          data: temaDaBarra,
          child: BotaoBarraSuperior.voltar(
            aoTocar: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: const Text(
                'ALERTA CRÍTICO',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nomePaciente,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _QuadroDoAlerta(
              alerta: alerta,
              motivo: _motivo,
              orientacao: _orientacao,
              agora: agora,
            ),
            const SizedBox(height: 24),
            if (paciente != null && _podeLigarParaPaciente) ...[
              BotaoLigar(
                rotulo: 'LIGAR PARA ${_primeiroNome.toUpperCase()}',
                numero: paciente.telefone!,
                icone: Icons.call_rounded,
                corFundo: AppCores.sucesso,
                corTexto: Colors.white,
                telefoneService: telefoneService,
              ),
              const SizedBox(height: 16),
            ],
            BotaoLigar(
              rotulo: 'LIGAR PARA O SAMU (192)',
              numero: TelefonesEmergencia.samu,
              icone: Icons.emergency_rounded,
              corFundo: Colors.white,
              corTexto: AppCores.perigo,
              telefoneService: telefoneService,
            ),
            if (telaDeLocalizacao != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _verLocalizacao(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  iconSize: 28,
                ),
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('VER LOCALIZAÇÃO'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Quadro branco com o motivo, o BPM critico em destaque, ha quanto tempo o
// alerta foi gerado e o que fazer.
class _QuadroDoAlerta extends StatelessWidget {
  final Alerta alerta;
  final String motivo;
  final String orientacao;
  final DateTime? agora;

  const _QuadroDoAlerta({
    required this.alerta,
    required this.motivo,
    required this.orientacao,
    this.agora,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bpm = alerta.bpm;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_rounded,
                color: AppCores.perigo,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  motivo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppCores.perigo,
                  ),
                ),
              ),
            ],
          ),
          if (bpm != null) ...[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: '$bpm batimentos por minuto',
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$bpm',
                        style: const TextStyle(
                          fontSize: 76,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          color: AppCores.perigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.favorite_rounded,
                        size: 40,
                        color: AppCores.perigo,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'BPM',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppCores.perigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            descreverHorario(alerta.dataHora, agora: agora).toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            alerta.mensagem,
            style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            'O que fazer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            orientacao,
            style: TextStyle(
              fontSize: 17,
              height: 1.35,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
