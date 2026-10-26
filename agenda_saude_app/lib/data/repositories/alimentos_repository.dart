import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/alimentos/alimento.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';

// Carrega o catalogo de alimentos (TACO) que vai dentro do app, em
// `assets/alimentos/taco.json`. Fica no aparelho: a busca funciona sem
// internet e nada do que o paciente digita sai dele. O arquivo e lido uma vez
// e guardado.
class AlimentosRepository {
  static const String arquivoPadrao = 'assets/alimentos/taco.json';

  // Instancia compartilhada pelo app, para o arquivo ser lido uma vez so.
  static final AlimentosRepository compartilhado = AlimentosRepository();

  final Future<String> Function() _lerTexto;
  Future<CatalogoAlimentos>? _catalogo;

  // `lerTexto` troca a leitura do asset (nos testes, por um texto qualquer).
  AlimentosRepository({Future<String> Function()? lerTexto})
    : _lerTexto = lerTexto ?? (() => rootBundle.loadString(arquivoPadrao));

  Future<CatalogoAlimentos> carregar() {
    return _catalogo ??= _ler().catchError((Object erro) {
      // Uma falha nao fica guardada: a proxima tentativa le de novo.
      _catalogo = null;
      throw erro;
    });
  }

  Future<CatalogoAlimentos> _ler() async {
    final lista = jsonDecode(await _lerTexto()) as List<dynamic>;
    return CatalogoAlimentos(
      lista
          .map(
            (item) => Alimento.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
