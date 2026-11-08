import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/momentos_glicemia.dart';
import '../../domain/lembretes/lembrete.dart';
import '../shared/erro_formulario.dart';
import 'lembretes_viewmodel.dart';

// Pergunta o novo horario do aviso de um momento da glicemia (ou da insulina
// lenta). O horario se digita em numeros - "0630" vira 06:30 -, como em "Meus
// remedios": o seletor de hora do sistema sairia em ingles, porque o app nao
// tem as localizacoes do Flutter. Os botoes ocupam a largura toda, um embaixo do
// outro, como no dialogo de confirmacao.
Future<void> mostrarDialogoDeHorario(
  BuildContext context, {
  required LembretesViewModel viewModel,
  required Lembrete lembrete,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogoDeHorario(viewModel: viewModel, lembrete: lembrete),
  );
}

class _DialogoDeHorario extends StatefulWidget {
  final LembretesViewModel viewModel;
  final Lembrete lembrete;

  const _DialogoDeHorario({required this.viewModel, required this.lembrete});

  @override
  State<_DialogoDeHorario> createState() => _DialogoDeHorarioState();
}

class _DialogoDeHorarioState extends State<_DialogoDeHorario> {
  late final TextEditingController _campo;
  String? _erro;
  bool _ocupado = false;

  String get _momento => widget.lembrete.nomeDoMomento!;

  @override
  void initState() {
    super.initState();
    _campo = TextEditingController(text: widget.lembrete.horario);
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    final salvou =
        await widget.viewModel.definirHorarioDoMomento(_momento, _campo.text);
    if (!mounted) return;
    if (salvou) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _ocupado = false;
      _erro = 'Horário inválido. Digite 4 números, por exemplo 0730 para 07:30.';
    });
  }

  Future<void> _voltarAoPadrao() async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    final voltou = await widget.viewModel.restaurarHorarioDoMomento(_momento);
    if (!mounted) return;
    if (voltou) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _ocupado = false;
      _erro = 'Não foi possível voltar ao horário padrão. Tente de novo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final padrao = MomentoGlicemia.porNome(_momento).horarioPadrao;
    final alterado = widget.viewModel.horarioFoiAlterado(_momento);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mudar horário',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.lembrete.resumo,
              style: const TextStyle(fontSize: 18, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _campo,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _salvar(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:hH.]')),
                LengthLimitingTextInputFormatter(5),
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Horário',
                hintText: '0800',
                helperText: 'Digite 4 números. Ex.: 0800 é 08:00.',
                // O guia pede texto de pelo menos 16sp (o padrao do campo e 12).
                helperStyle: TextStyle(fontSize: 16),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              ErroFormulario(_erro!),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _ocupado ? null : _salvar,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Salvar horário'),
            ),
            if (alterado && padrao != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _voltarAoPadrao,
                icon: const Icon(Icons.restore_rounded),
                label: Text('Voltar para $padrao'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _ocupado ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
