import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/paciente.dart';
import '../insulina/card_glicemia_insulina.dart';
import '../insulina/glicemia_insulina_viewmodel.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_ouvir_tela.dart';
import '../shared/titulo_tela.dart';
import 'card_exercicio.dart';
import 'card_hidratacao.dart';
import 'card_medicacao.dart';
import 'card_refeicoes.dart';
import 'card_sono.dart';
import 'exercicio_viewmodel.dart';
import 'hidratacao_viewmodel.dart';
import 'medicacao_viewmodel.dart';
import 'narracao_da_rotina.dart';
import 'paciente_da_rotina.dart';
import 'refeicoes_viewmodel.dart';
import 'sono_viewmodel.dart';

// "Minha Rotina" (Figura 14 do TCC): checklist do dia do paciente. Tem a
// hidratacao (RF03.1), as medicacoes (RF003), as refeicoes (RF03.4), o sono
// (RF03.2), o exercicio (RF03.3) e, para quem marcou diabetes na triagem,
// glicemia e insulina (RF008). A medicacao vem logo depois da hidratacao, como
// no mockup.
class RotinaView extends StatelessWidget {
  // Mostra o cartao de glicemia e insulina; exige um
  // GlicemiaInsulinaViewModel acima na arvore.
  final bool exibirDiabetes;

  const RotinaView({super.key, this.exibirDiabetes = false});

  // Monta a tela com os ViewModels do paciente. O de glicemia/insulina so e
  // criado para diabeticos - a interface adaptada pela triagem (UC02).
  // `aoAtualizarPaciente` avisa o painel quando o plano de refeicoes ou a lista
  // de remedios muda.
  static Widget comProviders(
    Paciente paciente, {
    ValueChanged<Paciente>? aoAtualizarPaciente,
  }) {
    // As refeicoes e os remedios mudam o paciente cada um por si; o painel
    // recebe sempre o paciente com as duas mudancas (ver PacienteDaRotina).
    final doPainel = PacienteDaRotina(paciente, aoAtualizarPaciente);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HidratacaoViewModel(paciente: paciente),
        ),
        ChangeNotifierProvider(
          create: (_) => MedicacaoViewModel(
            paciente: paciente,
            aoAtualizarPaciente: doPainel.medicamentosMudaram,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RefeicoesViewModel(
            paciente: paciente,
            aoAtualizarPaciente: doPainel.refeicoesMudaram,
          ),
        ),
        if (paciente.possuiDiabetes)
          ChangeNotifierProvider(
            create: (_) => GlicemiaInsulinaViewModel(paciente: paciente),
          ),
        ChangeNotifierProvider(
          create: (_) => SonoViewModel(paciente: paciente),
        ),
        ChangeNotifierProvider(
          create: (_) => ExercicioViewModel(paciente: paciente),
        ),
      ],
      child: RotinaView(exibirDiabetes: paciente.possuiDiabetes),
    );
  }

  // O texto do botao "Ouvir esta tela" (RF 08.2): quantos itens do dia estao
  // feitos e o que falta, lido dos ViewModels no instante do toque. Se algum
  // ainda esta carregando ou nao conseguiu ler, os numeros nao valem e o
  // narrador diz isso - falar "falta tudo" seria enganoso.
  String _textoParaOuvir(BuildContext context) {
    final hidratacao = context.read<HidratacaoViewModel>();
    final medicacao = context.read<MedicacaoViewModel>();
    final refeicoes = context.read<RefeicoesViewModel>();
    final sono = context.read<SonoViewModel>();
    final exercicio = context.read<ExercicioViewModel>();
    final glicemia =
        exibirDiabetes ? context.read<GlicemiaInsulinaViewModel>() : null;

    final carregando = hidratacao.carregando ||
        medicacao.carregando ||
        refeicoes.carregando ||
        sono.carregando ||
        exercicio.carregando ||
        (glicemia?.carregando ?? false);
    if (carregando) return rotinaCarregandoNarrada;

    final comErro = hidratacao.erroDeLeitura ||
        medicacao.erroDeLeitura ||
        refeicoes.erroDeLeitura ||
        sono.erroDeLeitura ||
        exercicio.erroDeLeitura ||
        (glicemia?.erroDeLeitura ?? false);
    if (comErro) return rotinaComErroNarrada;

    return narrarRotina(
      aguaMl: hidratacao.totalMl,
      metaAguaMl: hidratacao.metaMl,
      dosesTotal: medicacao.total,
      dosesPendentes: [
        for (final dose in medicacao.doses)
          if (!medicacao.estaTomada(dose)) dose,
      ],
      refeicoesTotal: refeicoes.total,
      refeicoesFeitas: refeicoes.feitas,
      medicoesPendentes: glicemia == null
          ? null
          : glicemia.totalMedicoes - glicemia.medicoesFeitas,
      // A insulina lenta e o unico item do checklist que nao mede glicemia.
      insulinaPendente: glicemia?.itensDoDia.any(
            (item) => !item.momento.medeGlicemia && !item.feito,
          ) ??
          false,
      sonoRegistrado: sono.registrou,
      exercicioMinutosNaSemana: exercicio.minutosNaSemana,
      exercicioMetaSemanal: exercicio.metaSemanalMinutos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'Minha Rotina',
              subtitulo: 'Registre aqui o que você já fez hoje.',
            ),
            const SizedBox(height: 24),
            BotaoOuvirTela(texto: () => _textoParaOuvir(context)),
            const CardHidratacao(),
            const SizedBox(height: 16),
            const CardMedicacao(),
            const SizedBox(height: 16),
            const CardRefeicoes(),
            if (exibirDiabetes) ...[
              const SizedBox(height: 16),
              const CardGlicemiaInsulina(),
            ],
            const SizedBox(height: 16),
            const CardSono(),
            const SizedBox(height: 16),
            const CardExercicio(),
          ],
        ),
      ),
    );
  }
}
