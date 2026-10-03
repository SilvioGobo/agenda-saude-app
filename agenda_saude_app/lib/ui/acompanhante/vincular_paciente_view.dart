import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../core/constants/codigo_vinculo.dart';
import '../../domain/models/acompanhante.dart';
import 'vincular_paciente_viewmodel.dart';

// Tela de vinculo de um novo paciente (RF05.4). O acompanhante digita o codigo
// que o paciente ve no menu do app dele; a tela mostra o nome encontrado e so
// grava o vinculo apos a confirmacao. Fecha devolvendo `true` quando conclui.
class VincularPacienteView extends StatefulWidget {
  const VincularPacienteView({super.key});

  static Widget comProviders(Acompanhante acompanhante) {
    return ChangeNotifierProvider(
      create: (_) => VincularPacienteViewModel(acompanhante: acompanhante),
      child: const VincularPacienteView(),
    );
  }

  @override
  State<VincularPacienteView> createState() => _VincularPacienteViewState();
}

class _VincularPacienteViewState extends State<VincularPacienteView> {
  final _codigoController = TextEditingController();

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _buscar(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await context.read<VincularPacienteViewModel>().buscarPaciente(
          _codigoController.text,
        );
  }

  Future<void> _confirmar(BuildContext context) async {
    final viewModel = context.read<VincularPacienteViewModel>();
    final sucesso = await viewModel.confirmarVinculo();
    if (!context.mounted || !sucesso) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VincularPacienteViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final encontrado = viewModel.pacienteEncontrado;

    return Scaffold(
      appBar: AppBar(title: const Text('Vincular paciente')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.link_rounded, size: 56, color: colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Peça ao paciente o código de vínculo (no app dele, em '
                'Menu > Meu código de vínculo) e digite abaixo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              if (encontrado == null) ...[
                TextField(
                  controller: _codigoController,
                  enabled: !viewModel.carregando,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: tamanhoCodigoVinculo,
                  inputFormatters: [
                    // Aceita so o alfabeto do codigo e ja converte para
                    // maiusculas enquanto digita.
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    _MaiusculasFormatter(),
                  ],
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Código de vínculo',
                    hintText: 'ABC123',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _buscar(context),
                ),
                const SizedBox(height: 24),
                if (viewModel.mensagemErro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      viewModel.mensagemErro!,
                      style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed:
                      viewModel.carregando ? null : () => _buscar(context),
                  icon: viewModel.carregando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                  label: const Text('Buscar paciente'),
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            _inicial(encontrado.nomePaciente),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Paciente encontrado',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          encontrado.nomePaciente,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Você passará a acompanhar os dados de saúde desta pessoa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (viewModel.mensagemErro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      viewModel.mensagemErro!,
                      style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed:
                      viewModel.carregando ? null : () => _confirmar(context),
                  icon: viewModel.carregando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Confirmar vínculo'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: viewModel.carregando
                      ? null
                      : () {
                          _codigoController.clear();
                          viewModel.digitarOutroCodigo();
                        },
                  child: const Text('Digitar outro código'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _inicial(String nome) {
    final limpo = nome.trim();
    return limpo.isEmpty ? '?' : limpo[0].toUpperCase();
  }
}

class _MaiusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
