import 'package:flutter/material.dart';

// "Salvar" do canto direito da barra superior (`BarraSuperiorFormulario`):
// preenchido, por ser a acao principal da tela, com o check e o texto - idosos
// nem sempre reconhecem icones soltos (NF004). Enquanto grava, o check vira um
// indicador de progresso e o botao fica desligado, para nao gravar duas vezes,
// sem mudar de cor. Com a fonte do celular muito aumentada ele encolhe para
// caber na barra, como o `BotaoBarraSuperior`.
class BotaoSalvar extends StatelessWidget {
  final bool salvando;
  final VoidCallback aoTocar;

  const BotaoSalvar({
    super.key,
    required this.salvando,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: FilledButton.icon(
          onPressed: salvando ? null : aoTocar,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            iconSize: 26,
            disabledBackgroundColor: colorScheme.primary,
            disabledForegroundColor: colorScheme.onPrimary,
          ),
          icon: salvando
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Salvar'),
        ),
      ),
    );
  }
}
