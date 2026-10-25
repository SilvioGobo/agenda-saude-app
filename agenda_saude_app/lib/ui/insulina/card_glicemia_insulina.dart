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
// TCC), exibido so para quem marcou diabetes na triagem. Pensado para idosos
// (NF004): titulos, estados e botoes em caixa alta, e cada momento diz com
// todas as letras o que esta acontecendo - "AINDA NÃO ANOTADO / TOQUE AQUI
// PARA ANOTAR" ou "ANOTADO ÀS 07:10" com o valor grande e a faixa ("NA
// FAIXA", "BAIXA"...) em texto, icone e cor. Para corrigir um valor errado
// ha um botao "CORRIGIR" proprio, que apaga o registro (depois de confirmar)
// e abre a anotacao de novo.
class CardGlicemiaInsulina extends StatelessWidget {
  const CardGlicemiaInsulina({super.key});

  Future<void> _anotar(BuildContext context, MomentoGlicemia momento) async {
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
    _avisar(context, '${momento.rotulo}: ANOTADO COM SUCESSO.');
  }

  Future<void> _corrigir(
    BuildContext context,
    RegistroDiabete registro,
  ) async {
    final viewModel = context.read<GlicemiaInsulinaViewModel>();
    final momento = MomentoGlicemia.porNome(registro.momento);
    final confirmou = await mostrarDialogoConfirmacao(
      context,
      titulo: 'CORRIGIR ${momento.rotulo}?',
      mensagem: 'O que foi anotado (${_resumoEmTexto(registro)}) será '
          'apagado. Depois, a tela de anotação abre para você digitar o '
          'valor certo.',
      rotuloConfirmar: 'APAGAR E ANOTAR DE NOVO',
      iconeConfirmar: Icons.edit_rounded,
      rotuloCancelar: 'CANCELAR',
    );
    if (!confirmou || !context.mounted) return;
    final apagou = await viewModel.apagarRegistro(registro);
    if (!apagou || !context.mounted) return;
    await _anotar(context, momento);
  }

  void _avisar(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GlicemiaInsulinaViewModel>();
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
              const _TextoErro(
                'NÃO FOI POSSÍVEL CARREGAR SUA GLICEMIA DE HOJE. VOLTE E '
                'ABRA ESTA TELA DE NOVO.',
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
                  mensagem: 'Sua última medição foi '
                      '${formatarGlicemia(ultima.nivelGlicose!)}. Faça o que '
                      'o seu médico orientou para glicemia baixa e meça de '
                      'novo em 15 minutos.',
                  icone: Icons.arrow_downward_rounded,
                ),
                const SizedBox(height: 16),
              ],
              for (final item in viewModel.itensDoDia) ...[
                if (item.registro == null)
                  _MomentoPendente(
                    momento: item.momento,
                    aoTocar: () => _anotar(context, item.momento),
                  )
                else
                  _MomentoAnotado(
                    rotulo: item.momento.rotulo,
                    registro: item.registro!,
                    aoCorrigir: () => _corrigir(context, item.registro!),
                  ),
                const SizedBox(height: 12),
              ],
              for (final registro in viewModel.outrasMedicoes) ...[
                _MomentoAnotado(
                  rotulo: MomentoGlicemia.outraMedicao.rotulo,
                  registro: registro,
                  aoCorrigir: () => _corrigir(context, registro),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () =>
                    _anotar(context, MomentoGlicemia.outraMedicao),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  iconSize: 28,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('ANOTAR OUTRA MEDIÇÃO'),
              ),
            ],
            if (viewModel.mensagemErro != null) ...[
              const SizedBox(height: 12),
              _TextoErro(viewModel.mensagemErro!.toUpperCase()),
            ],
          ],
        ),
      ),
    );
  }
}

// "112 mg/dL e insulina rápida: 6 unidades" - usado no dialogo de corrigir.
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
    final feitas = viewModel.medicoesFeitas;
    final total = viewModel.totalMedicoes;

    return Semantics(
      container: true,
      label: pronto
          ? 'Glicemia e Insulina: $feitas de $total medições feitas hoje.'
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
                    'GLICEMIA E INSULINA',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (pronto)
                    Text(
                      'HOJE: $feitas DE $total MEDIÇÕES',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: feitas == total
                            ? AppCores.sucesso
                            : colorScheme.onSurfaceVariant,
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

// Momento ainda sem anotacao: o cartao inteiro e um botao (minimo 88dp) com
// circulo vazio, o nome do momento e o convite "TOQUE AQUI PARA ANOTAR".
class _MomentoPendente extends StatelessWidget {
  final MomentoGlicemia momento;
  final VoidCallback aoTocar;

  const _MomentoPendente({required this.momento, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '${momento.nome}: ainda não anotado. Toque para anotar.',
      onTap: aoTocar,
      excludeSemantics: true,
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.primary, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 36,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NomeMomento(momento.rotulo),
                        const SizedBox(height: 4),
                        Text(
                          'AINDA NÃO ANOTADO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'TOQUE AQUI PARA ANOTAR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 36,
                    color: colorScheme.primary,
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

// Momento ja anotado: check verde e "ANOTADO ÀS 07:10", o valor da glicemia
// grande com a faixa logo abaixo, a dose de insulina e o botao "CORRIGIR".
class _MomentoAnotado extends StatelessWidget {
  final String rotulo;
  final RegistroDiabete registro;
  final VoidCallback aoCorrigir;

  const _MomentoAnotado({
    required this.rotulo,
    required this.registro,
    required this.aoCorrigir,
  });

  String get _rotuloParaLeitor {
    final r = registro;
    final partes = <String>['${r.momento}: anotado ${descreverHora(r.dataHora)}'];
    if (r.temGlicemia) {
      final classificacao = FaixasGlicemia.classificar(r.nivelGlicose!);
      partes.add('Glicemia ${falarGlicemia(r.nivelGlicose!)}, '
          '${descreverClassificacao(classificacao).toLowerCase()}');
    }
    if (r.temInsulina) {
      partes.add(descreverInsulina(r.tipoInsulina, r.doseInsulina!)
          .replaceFirst(':', ','));
    }
    return semMarcasDeQuebra('${partes.join('. ')}.');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final r = registro;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppCores.sucesso, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: _rotuloParaLeitor,
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 36,
                    color: AppCores.sucesso,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NomeMomento(rotulo),
                        const SizedBox(height: 4),
                        Text(
                          'ANOTADO ${descreverHora(r.dataHora).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppCores.sucesso,
                          ),
                        ),
                        if (r.temGlicemia) ...[
                          const SizedBox(height: 8),
                          _ValorGlicemia(mgDl: r.nivelGlicose!),
                        ],
                        if (r.temInsulina) ...[
                          const SizedBox(height: 8),
                          Text(
                            descreverInsulina(r.tipoInsulina, r.doseInsulina!)
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Corrigir $rotulo',
            onTap: aoCorrigir,
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: aoCorrigir,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                iconSize: 24,
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('CORRIGIR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NomeMomento extends StatelessWidget {
  final String texto;

  const _NomeMomento(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// Valor grande ("112 mg/dL") e, embaixo, o selo da faixa ("NA FAIXA",
// "BAIXA"...).
class _ValorGlicemia extends StatelessWidget {
  final double mgDl;

  const _ValorGlicemia({required this.mgDl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatarGlicemia(mgDl),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        SeloFaixaGlicemia(FaixasGlicemia.classificar(mgDl)),
      ],
    );
  }
}

// Erro em caixa alta com icone, anunciado pelo leitor de tela.
class _TextoErro extends StatelessWidget {
  final String texto;

  const _TextoErro(this.texto);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, color: AppCores.perigo, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.bold,
                color: AppCores.perigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
