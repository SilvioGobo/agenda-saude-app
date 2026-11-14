import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/medicacao/catalogo_remedios.dart';
import '../../domain/medicacao/remedio.dart';

// Carrega o catalogo de remedios (medicamentos registrados na Anvisa) que vai
// dentro do app, em `assets/medicamentos/anvisa.json`. Como o de alimentos,
// fica no aparelho: a busca funciona sem internet e nada do que o paciente
// digita sai dele. O arquivo e lido uma vez e guardado.
class RemediosRepository {
  static const String arquivoPadrao = 'assets/medicamentos/anvisa.json';

  // Instancia compartilhada pelo app, para o arquivo ser lido uma vez so.
  static final RemediosRepository compartilhado = RemediosRepository();

  final Future<String> Function() _lerTexto;
  Future<CatalogoRemedios>? _catalogo;

  // `lerTexto` troca a leitura do asset (nos testes, por um texto qualquer).
  RemediosRepository({Future<String> Function()? lerTexto})
    : _lerTexto = lerTexto ?? (() => rootBundle.loadString(arquivoPadrao));

  Future<CatalogoRemedios> carregar() {
    return _catalogo ??= _ler().catchError((Object erro) {
      // Uma falha nao fica guardada: a proxima tentativa le de novo.
      _catalogo = null;
      throw erro;
    });
  }

  Future<CatalogoRemedios> _ler() async {
    final lista = jsonDecode(await _lerTexto()) as List<dynamic>;
    return CatalogoRemedios(
      lista
          .map(
            (item) => Remedio.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
