import 'dart:io';

import 'package:agenda_saude_app/data/repositories/alimentos_repository.dart';
import 'package:agenda_saude_app/data/repositories/remedios_repository.dart';
import 'package:agenda_saude_app/domain/alimentos/catalogo_alimentos.dart';
import 'package:agenda_saude_app/domain/medicacao/catalogo_remedios.dart';
import 'package:agenda_saude_app/domain/medicacao/remedio.dart';

// Os testes usam o catalogo real (`assets/alimentos/taco.json`), lido do disco:
// assim as contas conferidas nos testes usam os mesmos valores da TACO que o
// app usa. O `flutter test` roda na raiz do projeto.
const String arquivoDoCatalogo = 'assets/alimentos/taco.json';

// Lido uma vez e de forma sincrona: dentro de um `testWidgets` o relogio e
// falso e uma leitura de arquivo de verdade nunca terminaria.
final String _textoDoCatalogo = File(arquivoDoCatalogo).readAsStringSync();

AlimentosRepository alimentosRepositoryDeTeste() {
  return AlimentosRepository(lerTexto: () async => _textoDoCatalogo);
}

Future<CatalogoAlimentos> catalogoDeTeste() {
  return alimentosRepositoryDeTeste().carregar();
}

// Ids de alimentos da TACO e seus valores por 100 g, para as contas dos testes:
//  3  Arroz, tipo 1, cozido           128 kcal  P 2,5  G 0,2  C 28,1  fibra 1,6  Na 1
//  53 Pão, trigo, francês             300 kcal  P 8,0  G 3,1  C 58,6  fibra 2,3  Na 648
//  182 Banana, prata, crua             98 kcal  P 1,3  G 0,1  C 26,0  fibra 2,0  Na 0
//  410 Frango, peito, sem pele, grelhado 159 kcal P 32,0 G 2,5 C 0,0  fibra 0,0  Na 50
//  561 Feijão, carioca, cozido         76 kcal  P 4,8  G 0,5  C 13,6  fibra 8,5  Na 2
const int idArrozCozido = 3;
const int idPaoFrances = 53;
const int idBananaPrata = 182;
const int idFrangoGrelhado = 410;
const int idFeijaoCarioca = 561;

// O catalogo de remedios de verdade (`assets/medicamentos/anvisa.json`), lido
// do disco como o de alimentos.
const String arquivoDeRemedios = 'assets/medicamentos/anvisa.json';

final String _textoDeRemedios = File(arquivoDeRemedios).readAsStringSync();

RemediosRepository remediosRepositoryDeTeste() {
  return RemediosRepository(lerTexto: () async => _textoDeRemedios);
}

// Um catalogo pequeno, para as telas: a busca fica previsivel nos testes.
CatalogoRemedios catalogoDeRemediosPequeno() {
  return CatalogoRemedios(const [
    Remedio(nome: 'Cloridrato de metformina', substancias: ['Metformina']),
    Remedio(nome: 'Dipirona', substancias: ['Dipirona']),
    Remedio(
      nome: 'Dorflex',
      substancias: ['Cafeína', 'Dipirona', 'Orfenadrina'],
    ),
    Remedio(nome: 'Glifage XR', substancias: ['Metformina']),
    Remedio(nome: 'Losartana potássica', substancias: ['Losartana']),
    Remedio(nome: 'Novalgina', substancias: ['Dipirona']),
  ]);
}

Future<CatalogoRemedios> carregarRemediosPequeno() =>
    Future.value(catalogoDeRemediosPequeno());
