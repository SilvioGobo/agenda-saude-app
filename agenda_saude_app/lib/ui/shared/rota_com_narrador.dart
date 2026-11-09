import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configuracoes/configuracoes_viewmodel.dart';

// A rota de uma tela aberta por cima de outra que leva junto o narrador de voz
// (o ConfiguracoesViewModel), para ela poder mostrar o botao "Ouvir esta tela".
//
// Precisa porque uma tela aberta com `Navigator.push` NAO herda os providers da
// tela que a abriu. O narrador vale para o app todo e e criado uma vez so, no
// painel; cada tela que abre outra repassa o mesmo. Sem narrador acima de
// [context] (ex.: o painel do acompanhante, que nao o tem), a rota sai igual a
// uma comum e a tela filha simplesmente nao mostra o botao.
MaterialPageRoute<T> rotaComNarrador<T>(BuildContext context, Widget tela) {
  final narrador = Provider.of<ConfiguracoesViewModel?>(context, listen: false);
  return MaterialPageRoute<T>(
    builder: (_) => narrador == null
        ? tela
        : ChangeNotifierProvider.value(value: narrador, child: tela),
  );
}
