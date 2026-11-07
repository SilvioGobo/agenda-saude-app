import 'package:flutter/material.dart';

import '../../core/services/telefone_service.dart';

// Botao grande que liga para um numero (Figuras 13 e 16 do TCC): abre o
// discador do celular com o numero ja digitado, e a pessoa so confirma a
// chamada. Mesmo tamanho do BotaoGrande (72dp, texto 20, icone 30), com as
// cores de quem usa: verde para ligar para alguem, vermelho/branco para a
// emergencia. Se o celular nao abrir o discador (ex.: tablet sem chip), avisa
// com o numero, para a pessoa ligar de outro aparelho.
class BotaoLigar extends StatelessWidget {
  final String rotulo;
  final String numero;
  final IconData icone;
  final Color corFundo;
  final Color corTexto;
  // Permite aos testes trocar o discador por um falso.
  final TelefoneService? telefoneService;

  const BotaoLigar({
    super.key,
    required this.rotulo,
    required this.numero,
    required this.corFundo,
    required this.corTexto,
    this.icone = Icons.call_rounded,
    this.telefoneService,
  });

  Future<void> _ligar(BuildContext context) async {
    final abriu = await (telefoneService ?? TelefoneServiceImpl()).ligar(numero);
    if (abriu || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Não foi possível abrir o telefone deste celular. Ligue para '
          '$numero.',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _ligar(context),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        backgroundColor: corFundo,
        foregroundColor: corTexto,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        iconSize: 30,
      ),
      icon: Icon(icone),
      label: Text(rotulo, maxLines: 2, textAlign: TextAlign.center),
    );
  }
}
