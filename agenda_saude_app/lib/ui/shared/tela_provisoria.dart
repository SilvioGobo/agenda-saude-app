import 'package:flutter/material.dart';

// Tela temporaria usada como destino de navegacao enquanto os paineis reais
// de Paciente e Acompanhante ainda nao foram construidos no cronograma.
class TelaProvisoria extends StatelessWidget {
  final String titulo;
  final String mensagem;

  const TelaProvisoria({
    super.key,
    required this.titulo,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mensagem,
            style: const TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
