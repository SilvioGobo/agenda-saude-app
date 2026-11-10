import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/alimentos_repository.dart';
import '../../data/repositories/relatorios_repository.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_ouvir_tela.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/rota_com_narrador.dart';
import '../shared/titulo_tela.dart';
import 'estado_relatorio.dart';
import 'formato_relatorios.dart';
import 'narracao_dos_relatorios.dart';
import 'relatorio_dia_conteudo.dart';
import 'relatorio_dia_view.dart';
import 'relatorio_dia_viewmodel.dart';
import 'relatorio_mes_conteudo.dart';
import 'relatorio_mes_viewmodel.dart';

// Relatorios (RF05): "Ontem", o resumo da rotina do dia anterior, e "Mês", o
// relatorio mensal com calendario. E a mesma tela para o paciente - aberta
// pelo botao "Meus Relatórios" do painel dele - e para o acompanhante - aberta
// pelo card do paciente. Os dois leem os mesmos registros e veem os mesmos
// numeros; so o titulo muda ("Meus relatórios" / "Relatórios de José"). Os
// textos dos relatorios nao dizem "voce" nem citam o nome, para servirem aos
// dois.
class RelatoriosView extends StatefulWidget {
  final bool paraAcompanhante;
  // Abre o relatorio de um dia tocado no calendario do mes.
  final void Function(BuildContext context, DateTime dia) aoAbrirDia;

  const RelatoriosView({
    super.key,
    required this.aoAbrirDia,
    this.paraAcompanhante = false,
  });

  // Monta a tela com os ViewModels do dia anterior e do mes. O do mes so e
  // criado - e so le o Firestore - quando a aba "Mês" e aberta pela primeira
  // vez. Os parametros opcionais permitem aos testes montar a tela com
  // repositories e relogio falsos.
  static Widget comProviders(
    Paciente paciente, {
    bool paraAcompanhante = false,
    RelatoriosRepository? relatoriosRepository,
    AlimentosRepository? alimentosRepository,
    DateTime Function()? agora,
  }) {
    final relogio = agora ?? DateTime.now;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final hoje = relogio();
            return RelatorioDiaViewModel(
              paciente: paciente,
              dia: DateTime(hoje.year, hoje.month, hoje.day - 1),
              relatoriosRepository: relatoriosRepository,
              alimentosRepository: alimentosRepository,
            )..carregar();
          },
        ),
        ChangeNotifierProvider(
          create: (_) => RelatorioMesViewModel(
            paciente: paciente,
            relatoriosRepository: relatoriosRepository,
            agora: relogio,
          )..carregar(),
        ),
      ],
      child: RelatoriosView(
        paraAcompanhante: paraAcompanhante,
        aoAbrirDia: (context, dia) {
          // O relatorio do dia abre por cima e leva junto o narrador (botao
          // "Ouvir esta tela"), que ele nao herdaria.
          Navigator.of(context).push(
            rotaComNarrador(
              context,
              RelatorioDiaView.comProviders(
                paciente,
                dia,
                paraAcompanhante: paraAcompanhante,
                relatoriosRepository: relatoriosRepository,
                alimentosRepository: alimentosRepository,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  State<RelatoriosView> createState() => _RelatoriosViewState();
}

class _RelatoriosViewState extends State<RelatoriosView> {
  // 0 = Ontem, 1 = Mês.
  int _aba = 0;

  // O texto do botao "Ouvir esta tela" (RF 08.2): o da aba aberta, lido no
  // instante do toque. Relatorio ainda carregando ou que nao carregou diz isso,
  // em vez de falar numeros que nao existem.
  String _textoParaOuvir() {
    if (_aba == 0) {
      final viewModel = context.read<RelatorioDiaViewModel>();
      return switch (viewModel.estado) {
        EstadoRelatorio.carregando => relatorioCarregandoNarrado,
        EstadoRelatorio.erro => relatorioComErroNarrado,
        EstadoRelatorio.pronto => narrarRelatorioDoDia(viewModel.resumo!),
      };
    }

    final viewModel = context.read<RelatorioMesViewModel>();
    return switch (viewModel.estado) {
      EstadoRelatorio.carregando => relatorioCarregandoNarrado,
      EstadoRelatorio.erro => relatorioComErroNarrado,
      EstadoRelatorio.pronto => narrarRelatorioDoMes(viewModel.resumo!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final paciente = context.read<RelatorioDiaViewModel>().paciente;
    final nome = primeiroNomeDe(paciente.nome);
    final colorScheme = Theme.of(context).colorScheme;

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
              widget.paraAcompanhante ? 'Relatórios de $nome' : 'Meus relatórios',
              subtitulo: widget.paraAcompanhante
                  ? 'Veja como foram o dia anterior e o mês de $nome.'
                  : 'Veja como foram o seu dia anterior e o seu mês.',
            ),
            const SizedBox(height: 24),
            // Uma chave por aba: ao trocar de aba o botao e recriado e a
            // leitura da aba anterior para.
            BotaoOuvirTela(key: ValueKey(_aba), texto: _textoParaOuvir),
            Row(
              children: [
                Expanded(
                  child: BotaoSelecionavel(
                    rotulo: 'Ontem',
                    icone: Icons.history_rounded,
                    selecionado: _aba == 0,
                    aoTocar: () => setState(() => _aba = 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotaoSelecionavel(
                    rotulo: 'Mês',
                    icone: Icons.calendar_month_rounded,
                    selecionado: _aba == 1,
                    aoTocar: () => setState(() => _aba = 1),
                  ),
                ),
              ],
            ),
            // Espaco maior que o normal: o dia (titulo grande, que quebra em
            // duas linhas) nao pode parecer grudado nos botoes das abas.
            const SizedBox(height: 32),
            if (_aba == 0) ...[
              Text(
                capitalizar(
                  descreverDia(context.read<RelatorioDiaViewModel>().dia),
                ),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const RelatorioDiaConteudo(),
            ] else
              RelatorioMesConteudo(
                aoAbrirDia: (dia) => widget.aoAbrirDia(context, dia),
              ),
          ],
        ),
      ),
    );
  }
}
