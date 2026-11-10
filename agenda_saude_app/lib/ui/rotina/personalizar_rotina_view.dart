import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/paciente.dart';
import '../metas/ajustar_metas_view.dart';
import '../metas/metas_viewmodel.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'medicacao_viewmodel.dart';
import 'meus_remedios_view.dart';
import 'paciente_da_rotina.dart';
import 'personalizar_refeicoes_view.dart';
import 'refeicoes_viewmodel.dart';

// "Personalizar rotina", aberta pelo menu lateral: junta num lugar so o que o
// paciente configura de vez em quando - os remedios, o plano de refeicoes e as
// metas de agua, passos e exercicio. A "Minha Rotina" fica so com o checklist
// do dia.
class PersonalizarRotinaView extends StatelessWidget {
  const PersonalizarRotinaView({super.key});

  // `aoAtualizarPaciente` avisa o painel quando os remedios, as refeicoes ou as
  // metas mudam. Cada ViewModel guarda a sua copia do paciente; o painel recebe
  // sempre o paciente com todas as mudancas (ver PacienteDaRotina).
  static Widget comProviders(
    Paciente paciente, {
    ValueChanged<Paciente>? aoAtualizarPaciente,
  }) {
    final doPainel = PacienteDaRotina(paciente, aoAtualizarPaciente);

    return MultiProvider(
      providers: [
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
        ChangeNotifierProvider(
          create: (_) => MetasViewModel(
            paciente: paciente,
            aoAtualizar: doPainel.metasMudaram,
          ),
        ),
      ],
      child: const PersonalizarRotinaView(),
    );
  }

  void _abrir(BuildContext context, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    final medicacao = context.read<MedicacaoViewModel>();
    final refeicoes = context.read<RefeicoesViewModel>();
    final metas = context.watch<MetasViewModel>();

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
            const TituloTela('Personalizar rotina'),
            const SizedBox(height: 24),
            _Opcao(
              icone: Icons.medication_rounded,
              rotulo: 'Meus remédios',
              descricao: 'Nome, dose e horários',
              aoTocar: () =>
                  _abrir(context, MeusRemediosView.comProviders(medicacao)),
            ),
            const SizedBox(height: 12),
            _Opcao(
              icone: Icons.restaurant_rounded,
              rotulo: 'Minhas refeições',
              descricao: 'Refeições do dia e alimentos',
              aoTocar: () => _abrir(
                context,
                PersonalizarRefeicoesView.comProviders(refeicoes),
              ),
            ),
            // Sem metas calculadas (triagem incompleta) nao ha o que ajustar.
            if (metas.metas != null) ...[
              const SizedBox(height: 12),
              _Opcao(
                icone: Icons.tune_rounded,
                rotulo: 'Ajustar metas',
                descricao: 'Água, passos e exercício',
                aoTocar: () => _abrir(
                  context,
                  ChangeNotifierProvider.value(
                    value: metas,
                    child: const AjustarMetasView(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Cartao grande e tocavel: icone, nome e uma linha do que tem dentro. Mesmo
// tamanho dos itens do menu lateral (72dp, icone 32, texto 20 - NF004).
class _Opcao extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String descricao;
  final VoidCallback aoTocar;

  const _Opcao({
    required this.icone,
    required this.rotulo,
    required this.descricao,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: aoTocar,
        minTileHeight: 80,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icone, size: 32, color: colorScheme.primary),
        title: Text(
          rotulo,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          descricao,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 32,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
