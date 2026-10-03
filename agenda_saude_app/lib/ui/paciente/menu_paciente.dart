import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../sincronizacao/sincronizacao_bpm_viewmodel.dart';
import 'paciente_viewmodel.dart';

// Menu lateral do painel do paciente, aberto pelo botao "Menu". Guarda o que
// o paciente usa pouco (codigo de vinculo, conexao do smartwatch, sair) para
// o painel ficar so com o BPM e os atalhos principais. Itens com 72dp de
// altura, icone 32 e texto 20, com uma linha de explicacao embaixo (NF004).
class MenuPaciente extends StatelessWidget {
  final VoidCallback aoAbrirCodigo;
  final VoidCallback aoAbrirSmartwatch;
  final VoidCallback aoSair;

  const MenuPaciente({
    super.key,
    required this.aoAbrirCodigo,
    required this.aoAbrirSmartwatch,
    required this.aoSair,
  });

  // Fecha o menu antes de executar a acao, para que ao voltar da tela
  // aberta o paciente caia direto no painel.
  void _tocar(BuildContext context, VoidCallback acao) {
    Navigator.of(context).pop();
    acao();
  }

  ({String texto, Color cor}) _situacaoSmartwatch(
    BuildContext context,
    SincronizacaoBpmViewModel sincronizacao,
  ) {
    final neutra = Theme.of(context).colorScheme.onSurfaceVariant;
    switch (sincronizacao.estado) {
      case EstadoSincronizacao.verificando:
        return (texto: 'Verificando...', cor: neutra);
      case EstadoSincronizacao.ativa:
        return sincronizacao.mensagemErro == null
            ? (texto: 'Conectado', cor: AppCores.sucesso)
            : (texto: 'Falha ao sincronizar', cor: AppCores.aviso);
      case EstadoSincronizacao.naoSuportado:
        return (texto: 'Indisponível neste celular', cor: neutra);
      case EstadoSincronizacao.healthConnectAusente:
      case EstadoSincronizacao.semPermissao:
      case EstadoSincronizacao.erro:
        return (texto: 'Desconectado', cor: AppCores.aviso);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PacienteViewModel>();
    final sincronizacao = context.watch<SincronizacaoBpmViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final situacao = _situacaoSmartwatch(context, sincronizacao);
    final nome = viewModel.paciente.nome.trim();

    return Drawer(
      width: min(MediaQuery.sizeOf(context).width * 0.88, 400),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    iconSize: 28,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Fechar'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      nome.isEmpty ? '?' : nome[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome.isEmpty ? 'Paciente' : nome,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Paciente',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _ItemMenu(
              icone: Icons.key_rounded,
              rotulo: 'Meu código de vínculo',
              descricao: 'Para seu acompanhante se vincular a você',
              aoTocar: () => _tocar(context, aoAbrirCodigo),
            ),
            _ItemMenu(
              icone: Icons.watch_rounded,
              rotulo: 'Meu smartwatch',
              descricao: situacao.texto,
              corDescricao: situacao.cor,
              aoTocar: () => _tocar(context, aoAbrirSmartwatch),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _ItemMenu(
              icone: Icons.logout_rounded,
              rotulo: 'Sair da conta',
              aoTocar: () => _tocar(context, aoSair),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String? descricao;
  final Color? corDescricao;
  final VoidCallback aoTocar;

  const _ItemMenu({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.descricao,
    this.corDescricao,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        onTap: aoTocar,
        minTileHeight: 72,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(icone, size: 32, color: colorScheme.primary),
        title: Text(
          rotulo,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: descricao == null
            ? null
            : Text(
                descricao!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: corDescricao == null
                      ? FontWeight.normal
                      : FontWeight.w600,
                  color: corDescricao ?? colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
