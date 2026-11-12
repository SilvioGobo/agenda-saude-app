import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../alergias/secao_alergias.dart';
import '../rotina/meus_remedios_view.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/perguntas_aninhadas.dart';
import '../shared/rotulo_pergunta.dart';
import '../shared/seletor_sim_nao.dart';
import 'triagem_viewmodel.dart';

// As perguntas da triagem, as mesmas no assistente do primeiro acesso (uma
// etapa por tela) e em "Meus dados" (todas numa tela so). Leem e escrevem no
// TriagemViewModel; os campos de texto abrem com o que ja esta nele (em "Meus
// dados", as respostas que o paciente ja deu).

// Numero para o campo de texto: "165", "72,5", "1,5".
String _numeroParaCampo(double? valor) {
  if (valor == null) return '';
  final texto = valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toString();
  return texto.replaceAll('.', ',');
}

// Data de nascimento, sexo, altura, peso e nivel de atividade (etapa 1).
class PerguntasSobreVoce extends StatefulWidget {
  const PerguntasSobreVoce({super.key});

  @override
  State<PerguntasSobreVoce> createState() => _PerguntasSobreVoceState();
}

class _PerguntasSobreVoceState extends State<PerguntasSobreVoce> {
  late final TextEditingController _alturaController;
  late final TextEditingController _pesoController;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<TriagemViewModel>();
    _alturaController = TextEditingController(
      text: _numeroParaCampo(viewModel.alturaCm),
    );
    _pesoController = TextEditingController(
      text: _numeroParaCampo(viewModel.pesoKg),
    );
  }

  @override
  void dispose() {
    _alturaController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataNascimento(
    BuildContext context,
    TriagemViewModel viewModel,
  ) async {
    final agora = DateTime.now();
    final dataSelecionada = await showDatePicker(
      context: context,
      initialDate: viewModel.dataNascimento ??
          DateTime(agora.year - 65, agora.month, agora.day),
      firstDate: DateTime(agora.year - 120),
      lastDate: agora,
      helpText: 'Data de nascimento',
    );
    if (dataSelecionada != null) {
      viewModel.definirDataNascimento(dataSelecionada);
    }
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    Widget nivel(String rotulo) => Expanded(
          child: BotaoSelecionavel(
            rotulo: rotulo,
            selecionado: viewModel.nivelAtividadeFisica == rotulo,
            aoTocar: () => viewModel.selecionarNivelAtividadeFisica(rotulo),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloPergunta('Data de nascimento'),
        OutlinedButton(
          onPressed: () => _selecionarDataNascimento(context, viewModel),
          child: Text(
            viewModel.dataNascimento != null
                ? _formatarData(viewModel.dataNascimento!)
                : 'Selecionar data',
          ),
        ),
        const SizedBox(height: 20),
        const RotuloPergunta('Sexo biológico'),
        Row(
          children: [
            Expanded(
              child: BotaoSelecionavel(
                rotulo: 'Masculino',
                selecionado: viewModel.sexoBiologico == 'Masculino',
                aoTocar: () => viewModel.selecionarSexoBiologico('Masculino'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BotaoSelecionavel(
                rotulo: 'Feminino',
                selecionado: viewModel.sexoBiologico == 'Feminino',
                aoTocar: () => viewModel.selecionarSexoBiologico('Feminino'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _alturaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Altura (cm)'),
                onChanged: viewModel.definirAltura,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _pesoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
                onChanged: viewModel.definirPeso,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const RotuloPergunta('Nível de atividade física habitual'),
        Row(children: [nivel('Sedentário'), const SizedBox(width: 12), nivel('Leve')]),
        const SizedBox(height: 12),
        Row(
          children: [nivel('Moderado'), const SizedBox(width: 12), nivel('Intenso')],
        ),
      ],
    );
  }
}

// Diabetes: se tem, o tipo e a insulina (etapa 2).
class PerguntasDiabetes extends StatefulWidget {
  const PerguntasDiabetes({super.key});

  @override
  State<PerguntasDiabetes> createState() => _PerguntasDiabetesState();
}

class _PerguntasDiabetesState extends State<PerguntasDiabetes> {
  late final TextEditingController _tipoInsulinaController;

  @override
  void initState() {
    super.initState();
    _tipoInsulinaController = TextEditingController(
      text: context.read<TriagemViewModel>().tipoInsulina,
    );
  }

  @override
  void dispose() {
    _tipoInsulinaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloPergunta('Você possui diabetes?'),
        SeletorSimNao(
          valor: viewModel.possuiDiabetes,
          aoResponder: (valor) {
            viewModel.responderDiabetes(valor);
            // O ViewModel apaga o tipo de insulina; o campo apaga junto.
            if (!valor) _tipoInsulinaController.clear();
          },
        ),
        if (viewModel.possuiDiabetes == true) ...[
          const SizedBox(height: 16),
          PerguntasAninhadas(
            children: [
              const RotuloPergunta('Qual tipo?', pequeno: true),
              Row(
                children: [
                  for (final tipo in ['Tipo 1', 'Tipo 2']) ...[
                    if (tipo != 'Tipo 1') const SizedBox(width: 12),
                    Expanded(
                      child: BotaoSelecionavel(
                        rotulo: tipo,
                        pequeno: true,
                        selecionado: viewModel.tipoDiabetes == tipo,
                        aoTocar: () => viewModel.selecionarTipoDiabetes(tipo),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              const RotuloPergunta('Usa insulina?', pequeno: true),
              SeletorSimNao(
                valor: viewModel.usaInsulina,
                aoResponder: (valor) {
                  viewModel.responderUsaInsulina(valor);
                  if (!valor) _tipoInsulinaController.clear();
                },
                pequeno: true,
              ),
              if (viewModel.usaInsulina == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _tipoInsulinaController,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de insulina (opcional)',
                  ),
                  onChanged: viewModel.definirTipoInsulina,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// Cardiopatia: se tem, qual, marcapasso e restricao de liquido (etapa 3).
class PerguntasCardiopatia extends StatefulWidget {
  const PerguntasCardiopatia({super.key});

  @override
  State<PerguntasCardiopatia> createState() => _PerguntasCardiopatiaState();
}

class _PerguntasCardiopatiaState extends State<PerguntasCardiopatia> {
  late final TextEditingController _tipoCardiopatiaController;
  late final TextEditingController _limiteLiquidoController;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<TriagemViewModel>();
    _tipoCardiopatiaController = TextEditingController(
      text: viewModel.tipoCardiopatia,
    );
    _limiteLiquidoController = TextEditingController(
      text: _numeroParaCampo(viewModel.limiteLiquidoLitros),
    );
  }

  @override
  void dispose() {
    _tipoCardiopatiaController.dispose();
    _limiteLiquidoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();
    final corAninhada = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloPergunta('Você possui alguma cardiopatia?'),
        SeletorSimNao(
          valor: viewModel.possuiCardiopatia,
          aoResponder: (valor) {
            viewModel.responderCardiopatia(valor);
            // O ViewModel apaga as respostas de dentro; os campos apagam junto.
            if (!valor) {
              _tipoCardiopatiaController.clear();
              _limiteLiquidoController.clear();
            }
          },
        ),
        if (viewModel.possuiCardiopatia == true) ...[
          const SizedBox(height: 16),
          PerguntasAninhadas(
            children: [
              TextField(
                controller: _tipoCardiopatiaController,
                style: TextStyle(fontSize: 14, color: corAninhada),
                decoration: const InputDecoration(
                  labelText: 'Qual? (opcional)',
                ),
                onChanged: viewModel.definirTipoCardiopatia,
              ),
              const SizedBox(height: 20),
              const RotuloPergunta('Usa marcapasso?', pequeno: true),
              SeletorSimNao(
                valor: viewModel.usaMarcapasso,
                aoResponder: viewModel.responderUsaMarcapasso,
                pequeno: true,
              ),
              const SizedBox(height: 20),
              const RotuloPergunta(
                'Seu médico limitou a quantidade de líquido por dia?',
                pequeno: true,
              ),
              SeletorSimNao(
                valor: viewModel.possuiRestricaoLiquido,
                aoResponder: (valor) {
                  viewModel.responderRestricaoLiquido(valor);
                  if (!valor) _limiteLiquidoController.clear();
                },
                pequeno: true,
              ),
              if (viewModel.possuiRestricaoLiquido == true) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _limiteLiquidoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(fontSize: 14, color: corAninhada),
                  decoration: const InputDecoration(
                    labelText: 'Quantos litros por dia? (ex.: 1,5)',
                  ),
                  onChanged: viewModel.definirLimiteLiquido,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// Alergias a alimentos, a remedios e as outras (etapa 4), ligadas ao
// TriagemViewModel.
class PerguntasAlergias extends StatelessWidget {
  // Os catalogos das buscas; null = os do app (os testes passam outros).
  final Future<CatalogoAlimentos> Function()? carregarAlimentos;
  final Future<CatalogoRemedios> Function()? carregarRemedios;

  const PerguntasAlergias({
    super.key,
    this.carregarAlimentos,
    this.carregarRemedios,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return SecaoAlergias(
      alimentos: viewModel.alergiasAlimentos,
      remedios: viewModel.alergiasRemedios,
      outras: viewModel.outrasAlergias,
      aoAdicionarAlimento: viewModel.adicionarAlergiaAlimento,
      aoTirarAlimento: viewModel.tirarAlergiaAlimento,
      aoAdicionarRemedio: viewModel.adicionarAlergiaRemedio,
      aoTirarRemedio: viewModel.tirarAlergiaRemedio,
      aoMudarOutras: viewModel.definirOutrasAlergias,
      carregarAlimentos: carregarAlimentos,
      carregarRemedios: carregarRemedios,
    );
  }
}

// Remedios em uso continuo, escolhidos na lista da Anvisa (etapa 4). O que
// tem algo das alergias a remedios sai marcado.
class PerguntaMedicamentosEmUso extends StatelessWidget {
  // O catalogo da busca; null = o do app (os testes passam outro).
  final Future<CatalogoRemedios> Function()? carregarRemedios;

  const PerguntaMedicamentosEmUso({super.key, this.carregarRemedios});

  Future<void> _adicionar(BuildContext context) async {
    final viewModel = context.read<TriagemViewModel>();
    final escolhido = await MeusRemediosView.escolherRemedio(
      context,
      alergias: viewModel.alergiasRemedios,
      carregarCatalogo: carregarRemedios,
    );
    if (escolhido == null || !context.mounted) return;
    viewModel.adicionarMedicamentoEmUso(escolhido);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloPergunta('Medicamentos em uso contínuo'),
        if (viewModel.medicamentosEmUso.isEmpty)
          Text(
            'Nenhum.',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (final remedio in viewModel.medicamentosEmUso) ...[
          ItemDaLista(
            texto: remedio.nome,
            alergia: viewModel.alergiaDoMedicamentoEmUso(remedio),
            aoTirar: () => viewModel.tirarMedicamentoEmUso(remedio),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _adicionar(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar remédio em uso'),
        ),
      ],
    );
  }
}
