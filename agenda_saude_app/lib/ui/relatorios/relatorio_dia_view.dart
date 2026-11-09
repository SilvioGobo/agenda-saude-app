import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/alimentos_repository.dart';
import '../../data/repositories/relatorios_repository.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_ouvir_tela.dart';
import '../shared/titulo_tela.dart';
import 'estado_relatorio.dart';
import 'formato_relatorios.dart';
import 'narracao_dos_relatorios.dart';
import 'relatorio_dia_conteudo.dart';
import 'relatorio_dia_viewmodel.dart';

// Relatorio de um dia qualquer, aberto ao tocar nele no calendario do mes: a
// mesma leitura do "Ontem", com a data no titulo.
class RelatorioDiaView extends StatelessWidget {
  final bool paraAcompanhante;

  const RelatorioDiaView({super.key, this.paraAcompanhante = false});

  // Os parametros opcionais permitem aos testes montar a tela com
  // repositories falsos.
  static Widget comProviders(
    Paciente paciente,
    DateTime dia, {
    bool paraAcompanhante = false,
    RelatoriosRepository? relatoriosRepository,
    AlimentosRepository? alimentosRepository,
  }) {
    return ChangeNotifierProvider(
      create: (_) => RelatorioDiaViewModel(
        paciente: paciente,
        dia: dia,
        relatoriosRepository: relatoriosRepository,
        alimentosRepository: alimentosRepository,
      )..carregar(),
      child: RelatorioDiaView(paraAcompanhante: paraAcompanhante),
    );
  }

  // O texto do botao "Ouvir esta tela" (RF 08.2), lido no instante do toque.
  String _textoParaOuvir(BuildContext context) {
    final viewModel = context.read<RelatorioDiaViewModel>();
    return switch (viewModel.estado) {
      EstadoRelatorio.carregando => relatorioCarregandoNarrado,
      EstadoRelatorio.erro => relatorioComErroNarrado,
      EstadoRelatorio.pronto => narrarRelatorioDoDia(viewModel.resumo!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<RelatorioDiaViewModel>();
    final nome = primeiroNomeDe(viewModel.paciente.nome);

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
            TituloTela(
              capitalizar(descreverDia(viewModel.dia)),
              subtitulo: paraAcompanhante
                  ? 'Como foi a rotina de $nome neste dia.'
                  : 'Como foi a sua rotina neste dia.',
            ),
            const SizedBox(height: 24),
            BotaoOuvirTela(texto: () => _textoParaOuvir(context)),
            const RelatorioDiaConteudo(),
          ],
        ),
      ),
    );
  }
}
