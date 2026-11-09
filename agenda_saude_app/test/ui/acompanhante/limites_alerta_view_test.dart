import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/limites_alerta_view.dart';
import 'package:agenda_saude_app/ui/acompanhante/limites_alerta_viewmodel.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DadosMedicosRepository dadosRepository;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    await fakeFirestore
        .collection('usuarios')
        .doc('paciente_01')
        .set({'nome': 'Maria Souza', 'perfil': 'Paciente'});
  });

  LimitesAlertaViewModel formulario({
    bool possuiCardiopatia = true,
    LimitesAlerta? limitesAtuais,
  }) {
    return LimitesAlertaViewModel(
      paciente: Paciente(
        id: 'paciente_01',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: possuiCardiopatia,
        codigoVinculo: 'ABC123',
      ),
      acompanhanteId: 'cuidador_01',
      limitesAtuais: limitesAtuais,
      dadosRepository: dadosRepository,
    );
  }

  // Abre a tela por cima de uma tela vazia, como o painel faz, e guarda o que
  // ela devolveu ao fechar. Sem [escalaDaFonte], numa tela alta o bastante
  // para os dois contadores ficarem montados sem rolar.
  Future<List<bool?>> abrir(
    WidgetTester tester,
    LimitesAlertaViewModel viewModel, {
    double escalaDaFonte = 1,
  }) async {
    if (escalaDaFonte == 1) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final resultados = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escalaDaFonte)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => resultados.add(
                  await Navigator.of(context)
                      .push(LimitesAlertaView.rota(viewModel)),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return resultados;
  }

  testWidgets('Mostra os limites de agora, as duas perguntas e a zona padrão do paciente', (
    tester,
  ) async {
    await abrir(tester, formulario());

    expect(find.text('Limites de alerta'), findsOneWidget);
    expect(find.textContaining('o alerta de Maria dispara'), findsOneWidget);
    expect(find.text('1. BATIMENTOS MÍNIMOS'), findsOneWidget);
    expect(find.text('2. BATIMENTOS MÁXIMOS'), findsOneWidget);
    // Cardiopata sem limites definidos: comeca na zona padrao de 60 a 90.
    expect(find.text('60 BPM'), findsOneWidget);
    expect(find.text('90 BPM'), findsOneWidget);
    expect(find.text('ZONA PADRÃO: 60 A 90 BPM'), findsOneWidget);
    expect(find.text('Usando a zona padrão'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('5 minutos'), 200);
    expect(find.textContaining('médico de Maria'), findsOneWidget);
  });

  testWidgets('Mais e Menos mudam os valores de 5 em 5 e o padrão volta com um toque', (
    tester,
  ) async {
    await abrir(tester, formulario());

    // O primeiro contador e o minimo; o segundo, o maximo.
    await tester.tap(find.text('Menos').first);
    await tester.ensureVisible(find.text('Mais').last);
    await tester.tap(find.text('Mais').last);
    await tester.tap(find.text('Mais').last);
    await tester.pumpAndSettle();

    expect(find.text('55 BPM'), findsOneWidget);
    expect(find.text('100 BPM'), findsOneWidget);

    await tester.ensureVisible(find.text('Voltar ao padrão'));
    await tester.tap(find.text('Voltar ao padrão'));
    await tester.pumpAndSettle();

    expect(find.text('60 BPM'), findsOneWidget);
    expect(find.text('90 BPM'), findsOneWidget);
    expect(find.text('Usando a zona padrão'), findsOneWidget);
  });

  testWidgets('O botão desliga quando o valor chega ao fim da faixa', (
    tester,
  ) async {
    await abrir(
      tester,
      formulario(
        limitesAtuais: const LimitesAlerta(bpmMinimo: 40, bpmMaximo: 150),
      ),
    );

    final menosDoMinimo = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Menos').first,
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(menosDoMinimo.onPressed, isNull);
  });

  testWidgets('Salvar grava os limites no paciente e fecha a tela', (
    tester,
  ) async {
    final viewModel = formulario();
    final resultados = await abrir(tester, viewModel);

    await tester.ensureVisible(find.text('Mais').last);
    await tester.tap(find.text('Mais').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('SALVAR'), 200);
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(resultados, [true]);
    expect(find.text('Limites de alerta'), findsNothing);
    expect(viewModel.limitesSalvos?.bpmMaximo, 95);
    final doc =
        await fakeFirestore.collection('usuarios').doc('paciente_01').get();
    expect(doc.data()!['limitesAlerta']['bpmMaximo'], 95);
  });

  testWidgets('"Voltar" fecha sem salvar', (tester) async {
    final resultados = await abrir(tester, formulario());

    await tester.ensureVisible(find.text('Mais').last);
    await tester.tap(find.text('Mais').last);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(resultados, [false]);
    final doc =
        await fakeFirestore.collection('usuarios').doc('paciente_01').get();
    expect(doc.data()!.containsKey('limitesAlerta'), isFalse);
  });

  testWidgets('Não estoura com a fonte em 200% num celular pequeno', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await abrir(tester, formulario(), escalaDaFonte: 2);

    await tester.scrollUntilVisible(find.text('ZONA PADRÃO: 60 A 90 BPM'), 200);
    await tester.scrollUntilVisible(find.text('SALVAR'), 200);
    expect(find.text('SALVAR'), findsOneWidget);
  });
}
