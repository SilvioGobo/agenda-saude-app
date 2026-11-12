import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../configuracoes/configuracoes_viewmodel.dart';
import '../lembretes/lembretes_viewmodel.dart';
import '../localizacao/compartilhamento_localizacao_viewmodel.dart';
import '../sincronizacao/sincronizacao_bpm_viewmodel.dart';
import 'paciente_viewmodel.dart';

// Menu lateral do painel do paciente, aberto pelo botao "Menu". Guarda o que
// o paciente usa pouco (metas, personalizar a rotina, codigo de vinculo,
// conexao do smartwatch, compartilhamento da localizacao, lembretes,
// acessibilidade, sair) para o painel ficar so com o BPM e os atalhos principais. Itens com 72dp de altura,
// icone 32 e texto 20, com uma linha de explicacao embaixo (NF004). O perfil,
// no topo, abre "Meus dados" (as respostas da triagem).
class MenuPaciente extends StatelessWidget {
  final VoidCallback aoAbrirMeusDados;
  final VoidCallback aoAbrirMetas;
  final VoidCallback aoAbrirPersonalizarRotina;
  final VoidCallback aoAbrirCodigo;
  final VoidCallback aoAbrirSmartwatch;
  final VoidCallback aoAbrirLocalizacao;
  final VoidCallback aoAbrirLembretes;
  final VoidCallback aoAbrirAcessibilidade;
  final VoidCallback aoSair;

  const MenuPaciente({
    super.key,
    required this.aoAbrirMeusDados,
    required this.aoAbrirMetas,
    required this.aoAbrirPersonalizarRotina,
    required this.aoAbrirCodigo,
    required this.aoAbrirSmartwatch,
    required this.aoAbrirLocalizacao,
    required this.aoAbrirLembretes,
    required this.aoAbrirAcessibilidade,
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

  ({String texto, Color cor}) _situacaoLocalizacao(
    BuildContext context,
    CompartilhamentoLocalizacaoViewModel localizacao,
  ) {
    final neutra = Theme.of(context).colorScheme.onSurfaceVariant;
    switch (localizacao.estado) {
      case EstadoCompartilhamento.verificando:
        return (texto: 'Verificando...', cor: neutra);
      case EstadoCompartilhamento.ativo:
        return localizacao.mensagemErro == null
            ? (texto: 'Compartilhando', cor: AppCores.sucesso)
            : (texto: 'Falha ao enviar', cor: AppCores.aviso);
      case EstadoCompartilhamento.desligado:
        return (texto: 'Não compartilhada', cor: neutra);
      case EstadoCompartilhamento.naoSuportado:
        return (texto: 'Indisponível neste celular', cor: neutra);
      case EstadoCompartilhamento.semPermissao:
        return (texto: 'Sem permissão', cor: AppCores.aviso);
      case EstadoCompartilhamento.gpsDesligado:
        return (texto: 'GPS desligado', cor: AppCores.aviso);
      case EstadoCompartilhamento.erro:
        return (texto: 'Com problema', cor: AppCores.aviso);
    }
  }

  ({String texto, Color cor}) _situacaoLembretes(
    BuildContext context,
    LembretesViewModel lembretes,
  ) {
    final neutra = Theme.of(context).colorScheme.onSurfaceVariant;
    switch (lembretes.situacao) {
      case SituacaoLembretes.ativos:
        return (texto: 'Ligados', cor: AppCores.sucesso);
      case SituacaoLembretes.desligados:
        return (texto: 'Desligados', cor: neutra);
      case SituacaoLembretes.semLembretes:
        return (texto: 'Remédios e horários da glicemia', cor: neutra);
      case SituacaoLembretes.semPermissao:
        return (texto: 'Notificações desativadas', cor: AppCores.aviso);
      case SituacaoLembretes.semAlarmeExato:
        return (texto: 'Podem atrasar', cor: AppCores.aviso);
      case SituacaoLembretes.naoSuportado:
        return (texto: 'Indisponíveis neste celular', cor: neutra);
    }
  }

  ({String texto, Color cor}) _situacaoAcessibilidade(
    BuildContext context,
    ConfiguracoesViewModel configuracoes,
  ) {
    final neutra = Theme.of(context).colorScheme.onSurfaceVariant;
    if (!configuracoes.suportado) {
      return (texto: 'Indisponível neste celular', cor: neutra);
    }
    return configuracoes.narradorLigado
        ? (texto: 'Narrador ligado', cor: AppCores.sucesso)
        : (texto: 'Narrador desligado', cor: neutra);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PacienteViewModel>();
    final sincronizacao = context.watch<SincronizacaoBpmViewModel>();
    final localizacao = context.watch<CompartilhamentoLocalizacaoViewModel>();
    final lembretes = context.watch<LembretesViewModel>();
    final configuracoes = context.watch<ConfiguracoesViewModel>();
    final situacao = _situacaoSmartwatch(context, sincronizacao);
    final situacaoLocalizacao = _situacaoLocalizacao(context, localizacao);
    final situacaoLembretes = _situacaoLembretes(context, lembretes);
    final situacaoAcessibilidade =
        _situacaoAcessibilidade(context, configuracoes);
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
            _Perfil(
              nome: nome,
              aoTocar: () => _tocar(context, aoAbrirMeusDados),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _ItemMenu(
              icone: Icons.flag_rounded,
              rotulo: 'Minhas metas',
              descricao: 'Água, passos, calorias e mais',
              aoTocar: () => _tocar(context, aoAbrirMetas),
            ),
            _ItemMenu(
              icone: Icons.tune_rounded,
              rotulo: 'Personalizar rotina',
              descricao: 'Remédios, refeições e metas',
              aoTocar: () => _tocar(context, aoAbrirPersonalizarRotina),
            ),
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
            _ItemMenu(
              icone: Icons.location_on_rounded,
              rotulo: 'Minha localização',
              descricao: situacaoLocalizacao.texto,
              corDescricao: situacaoLocalizacao.cor,
              aoTocar: () => _tocar(context, aoAbrirLocalizacao),
            ),
            _ItemMenu(
              icone: Icons.notifications_active_rounded,
              rotulo: 'Meus lembretes',
              descricao: situacaoLembretes.texto,
              corDescricao: situacaoLembretes.cor,
              aoTocar: () => _tocar(context, aoAbrirLembretes),
            ),
            _ItemMenu(
              icone: Icons.accessibility_new_rounded,
              rotulo: 'Acessibilidade',
              descricao: situacaoAcessibilidade.texto,
              corDescricao: situacaoAcessibilidade.cor,
              aoTocar: () => _tocar(context, aoAbrirAcessibilidade),
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

// O perfil no topo do menu: a inicial do nome com um lapis, o nome e "Ver e
// mudar meus dados". A linha toda e o botao (mais facil de acertar que so o
// circulo) e abre "Meus dados".
class _Perfil extends StatelessWidget {
  final String nome;
  final VoidCallback aoTocar;

  const _Perfil({required this.nome, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nomeExibido = nome.isEmpty ? 'Paciente' : nome;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Semantics(
        button: true,
        label: 'Meus dados, $nomeExibido. Toque para ver e mudar as '
            'respostas da triagem.',
        excludeSemantics: true,
        onTap: aoTocar,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aoTocar,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
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
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeExibido,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ver e mudar meus dados',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
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
