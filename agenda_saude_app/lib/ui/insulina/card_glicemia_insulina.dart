import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../../core/theme/app_cores.dart';
import '../../domain/models/registro_diabete.dart';
import '../shared/caixa_alerta.dart';
import '../shared/dialogo_confirmacao.dart';
import 'formatacao_diabete.dart';
import 'glicemia_insulina_viewmodel.dart';
import 'registrar_glicemia_view.dart';

// Cartao "Glicemia e Insulina" do checklist de rotina (RF008, Figura 14 do
// TCC), exibido so para quem marcou diabetes na triagem. Cada momento do dia
// e uma linha grande: pendente ("Toque para registrar") abre a tela de
// registro; feito mostra o valor com a classificacao em texto e cor, e o
// toque oferece apagar o registro para corrigir um valor digitado errado.
class CardGlicemiaInsulina extends StatelessWidget {
  const CardGlicemiaInsulina({super.key});

  Future<void> _registrar(BuildContext context, MomentoGlicemia momento) async {
    final viewModel = context.read<GlicemiaInsulinaViewModel>();
    final salvou = await Navigator.of(context).push(
      RegistrarGlicemiaView.rota(
        paciente: viewModel.paciente,
        momento: momento,
        dadosRepository: viewModel.dadosRepository,
        agora: viewModel.agora,
      ),
    );
    if (salvou != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${momento.nome}: registro salvo.')),
    );
  }

  Future<void> _confirmarApagar(
    BuildContext context,
    RegistroDiabete registro,
  ) async {
    final viewModel = context.read<GlicemiaInsulinaViewModel>();
    final confirmou = await mostrarDialogoConfirmacao(
      context,
      titulo: 'Apagar este registro?',
      mensagem: '${registro.momento}: ${_resumoEmTexto(registro)} '
          '${descreverHora(registro.dataHora)}.\n\nApague só se anotou '
          'errado. Depois você pode registrar de novo.',
      rotuloConfirmar: 'Apagar registro',
      iconeConfirmar: Icons.delete_rounded,
    );
    if (!confirmou) return;
    final apagou = await viewModel.apagarRegistro(registro);
    if (!apagou || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro apagado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GlicemiaInsulinaViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final ultima = viewModel.ultimaGlicemia;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecalho(viewModel: viewModel),
            const SizedBox(height: 20),
            if (viewModel.erroDeLeitura)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Não foi possível carregar sua glicemia de hoje. Volte e '
                  'abra esta tela de novo.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppCores.perigo,
                  ),
                ),
              )
            else if (viewModel.carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (viewModel.hipoglicemiaNaUltimaMedicao && ultima != null) ...[
                CaixaAlerta(
                  titulo: 'GLICEMIA BAIXA',
                  mensagem: 'Sua última medição deu '
                      '${formatarGlicemia(ultima.nivelGlicose!)}. Siga a '
                      'orientação do seu médico para hipoglicemia e meça de '
                      'novo em 15 minutos.',
                  icone: Icons.arrow_downward_rounded,
                ),
                const SizedBox(height: 16),
              ],
              for (final item in viewModel.itensDoDia) ...[
                _LinhaMomento(
                  nome: item.momento.nome,
                  registro: item.registro,
                  aoTocar: item.registro == null
                      ? () => _registrar(context, item.momento)
                      : () => _confirmarApagar(context, item.registro!),
                ),
                const SizedBox(height: 12),
              ],
              for (final registro in viewModel.outrasMedicoes) ...[
                _LinhaMomento(
                  nome: registro.momento,
                  registro: registro,
                  aoTocar: () => _confirmarApagar(context, registro),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () =>
                    _registrar(context, MomentoGlicemia.outraMedicao),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  iconSize: 28,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Outra medição'),
              ),
            ],
            if (viewModel.mensagemErro != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  viewModel.mensagemErro!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
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

// "112 mg/dL e insulina rápida: 6 unidades" - usado no dialogo de apagar.
String _resumoEmTexto(RegistroDiabete registro) {
  final partes = [
    if (registro.temGlicemia) formatarGlicemia(registro.nivelGlicose!),
    if (registro.temInsulina)
      descreverInsulina(registro.tipoInsulina, registro.doseInsulina!)
          .replaceFirst('Insulina', 'insulina'),
  ];
  return partes.join(' e ');
}

// Icone, titulo e quantas das quatro medicoes do dia ja foram feitas. O
// leitor de tela le numa frase so ("Glicemia e Insulina: 2 de 4 medições
// feitas hoje.").
class _Cabecalho extends StatelessWidget {
  final GlicemiaInsulinaViewModel viewModel;

  const _Cabecalho({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;
    final progresso =
        '${viewModel.medicoesFeitas} de ${viewModel.totalMedicoes} medições';

    return Semantics(
      container: true,
      label: pronto
          ? 'Glicemia e Insulina: $progresso feitas hoje.'
          : 'Glicemia e Insulina',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bloodtype_rounded,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Glicemia e Insulina',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (pronto)
                    Text(
                      progresso,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Uma linha do checklist (minimo de 72dp de altura). Pendente: circulo vazio
// e "Toque para registrar". Feito: check verde, glicemia com a classificacao
// ("Na faixa", "Baixa"...), dose de insulina e horario.
class _LinhaMomento extends StatelessWidget {
  final String nome;
  final RegistroDiabete? registro;
  final VoidCallback aoTocar;

  const _LinhaMomento({
    required this.nome,
    required this.registro,
    required this.aoTocar,
  });

  String get _rotuloParaLeitor {
    final r = registro;
    if (r == null) return '$nome: pendente. Toque para registrar.';
    final partes = <String>['$nome: feito'];
    if (r.temGlicemia) {
      final classificacao = FaixasGlicemia.classificar(r.nivelGlicose!);
      partes.add('Glicemia ${falarGlicemia(r.nivelGlicose!)}, '
          '${descreverClassificacao(classificacao).toLowerCase()}');
    }
    if (r.temInsulina) {
      partes.add(descreverInsulina(r.tipoInsulina, r.doseInsulina!)
          .replaceFirst(':', ','));
    }
    partes.add('Registrado ${descreverHora(r.dataHora)}');
    return '${partes.join('. ')}. Toque para apagar este registro.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final r = registro;
    final feito = r != null;
    final textoSecundario = TextStyle(
      fontSize: 18,
      color: colorScheme.onSurfaceVariant,
    );

    return Semantics(
      button: true,
      label: _rotuloParaLeitor,
      onTap: aoTocar,
      excludeSemantics: true,
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: feito ? AppCores.sucesso : colorScheme.outlineVariant,
            width: feito ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    feito
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 32,
                    color: feito ? AppCores.sucesso : colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (r == null)
                          Text('Toque para registrar', style: textoSecundario)
                        else ...[
                          if (r.temGlicemia)
                            _GlicemiaClassificada(mgDl: r.nivelGlicose!),
                          if (r.temInsulina)
                            Text(
                              descreverInsulina(
                                r.tipoInsulina,
                                r.doseInsulina!,
                              ),
                              style: textoSecundario,
                            ),
                          Text(
                            'Registrado ${descreverHora(r.dataHora)}',
                            style: textoSecundario,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!feito)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 32,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// "112 mg/dL · Na faixa": valor em negrito e a classificacao com icone, na
// cor da faixa (nunca so a cor).
class _GlicemiaClassificada extends StatelessWidget {
  final double mgDl;

  const _GlicemiaClassificada({required this.mgDl});

  @override
  Widget build(BuildContext context) {
    final classificacao = FaixasGlicemia.classificar(mgDl);
    final cor = corDaClassificacao(classificacao);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(
          formatarGlicemia(mgDl),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconeDaClassificacao(classificacao), size: 20, color: cor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                descreverClassificacao(classificacao),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
