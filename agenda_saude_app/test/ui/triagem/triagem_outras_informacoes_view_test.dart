import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_outras_informacoes_view.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';
import '../shared/escolher_na_busca.dart';

void main() {
  // Triagem com as etapas obrigatorias respondidas, aberta na ultima etapa. O
  // painel de verdade liga no Firebase e nos sensores: aqui ele e so um texto.
  // Devolve os pacientes com que o painel foi montado.
  Future<List<Paciente>> montarTriagemPreenchida(
    WidgetTester tester, {
    required DateTime dataNascimento,
    FakeFirebaseFirestore? firestore,
  }) async {
    final pacientesNoPainel = <Paciente>[];
    final viewModel = TriagemViewModel(
      paciente: Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      ),
      pacienteRepository: PacienteRepository(
        firestore: firestore ?? FakeFirebaseFirestore(),
      ),
    )
      ..responderDiabetes(false)
      ..responderCardiopatia(false)
      ..definirDataNascimento(dataNascimento)
      ..selecionarSexoBiologico('Feminino')
      ..definirAltura('165')
      ..definirPeso('70')
      ..selecionarNivelAtividadeFisica('Leve');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: ChangeNotifierProvider.value(
          value: viewModel,
          child: TriagemOutrasInformacoesView(
            construirPainel: (paciente) {
              pacientesNoPainel.add(paciente);
              return const Scaffold(body: Text('Painel do paciente'));
            },
            carregarAlimentos: catalogoDeTeste,
            carregarRemedios: carregarRemediosPequeno,
          ),
        ),
      ),
    );
    return pacientesNoPainel;
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Etapa 4 (Outras Informações) mostra o progresso e os campos opcionais',
    (tester) async {
      final pacienteRecemCadastrado = Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => TriagemViewModel(
              paciente: pacienteRecemCadastrado,
              pacienteRepository:
                  PacienteRepository(firestore: FakeFirebaseFirestore()),
            ),
            child: const TriagemOutrasInformacoesView(),
          ),
        ),
      );

      expect(find.text('Outras Informações'), findsOneWidget);
      expect(find.text('Etapa 4 de 4'), findsOneWidget);
      expect(find.text('Alergia a alimentos'), findsOneWidget);
      expect(find.text('Alergia a remédios'), findsOneWidget);
      expect(find.text('Outras alergias ou restrições'), findsOneWidget);
      expect(find.text('Medicamentos em uso contínuo'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);
    },
  );

  testWidgets(
    'Deve escolher as alergias e os remédios em uso nas listas e salvar',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await montarTriagemPreenchida(
        tester,
        dataNascimento: DateTime(1960, 5, 10),
        firestore: firestore,
      );

      // Alergia a alimento: cada preparo do camarao vira um "Camarão" so.
      await tocar(tester, 'Adicionar alimento');
      expect(find.text('Alergia a alimento'), findsOneWidget);
      await escolherNaBusca(tester, 'camar', 'Camarão');
      expect(find.text('Camarão'), findsOneWidget);

      // Alergia a remedio: a marca leva ao principio ativo.
      await tocar(tester, 'Adicionar remédio');
      await escolherNaBusca(tester, 'novalg', 'Dipirona');
      expect(find.text('Dipirona'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ex.: látex, picada de abelha'),
        'Látex',
      );

      // O remedio em uso com dipirona avisa da alergia antes de entrar.
      await tocar(tester, 'Adicionar remédio em uso');
      await tester.enterText(find.byType(TextField).last, 'novalg');
      await tester.pumpAndSettle();
      expect(find.text('ALERGIA A DIPIRONA'), findsOneWidget);
      await tester.tap(find.text('Novalgina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher outro'));
      await tester.pumpAndSettle();
      await escolherNaBusca(tester, 'losar', 'Losartana potássica');
      expect(find.text('Losartana potássica'), findsOneWidget);

      await tocar(tester, 'Concluir');

      final salvo =
          (await firestore.collection('usuarios').doc('paciente_001').get())
              .data()!;
      expect(salvo['alergiasAlimentos'], ['Camarão']);
      expect(salvo['alergiasRemedios'], ['Dipirona']);
      expect(salvo['alergias'], 'Látex');
      expect(salvo['medicamentosEmUso'], [
        {
          'nome': 'Losartana potássica',
          'substancias': ['Losartana'],
        },
      ]);
    },
  );

  testWidgets(
    'O campo de outras alergias tem uma linha só, com o texto no meio',
    (tester) async {
      await montarTriagemPreenchida(
        tester,
        dataNascimento: DateTime(1960, 5, 10),
      );

      final campo = find.widgetWithText(
        TextFormField,
        'Ex.: látex, picada de abelha',
      );
      // Uma linha de texto (18) e o espaco do tema: antes eram duas linhas.
      expect(tester.getSize(campo).height, lessThan(64));
    },
  );

  testWidgets(
    'Não deve concluir se os dados obrigatórios de outras etapas faltarem',
    (tester) async {
      final pacienteRecemCadastrado = Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => TriagemViewModel(
              paciente: pacienteRecemCadastrado,
              pacienteRepository:
                  PacienteRepository(firestore: FakeFirebaseFirestore()),
            ),
            child: const TriagemOutrasInformacoesView(),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Concluir'));
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(find.text('Etapa 4 de 4'), findsOneWidget);
      expect(find.textContaining('Preencha data de nascimento'), findsOneWidget);
    },
  );

  testWidgets(
    'Ao concluir a triagem, deve mostrar as metas calculadas antes do painel',
    (tester) async {
      final pacienteRecemCadastrado = Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );
      final fakeFirestore = FakeFirebaseFirestore();
      final viewModel = TriagemViewModel(
        paciente: pacienteRecemCadastrado,
        pacienteRepository: PacienteRepository(firestore: fakeFirestore),
      )
        ..responderDiabetes(false)
        ..responderCardiopatia(false)
        ..definirDataNascimento(DateTime(1960, 5, 10))
        ..selecionarSexoBiologico('Feminino')
        ..definirAltura('165')
        ..definirPeso('70')
        ..selecionarNivelAtividadeFisica('Leve');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: viewModel,
            child: const TriagemOutrasInformacoesView(),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Concluir'));
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(find.text('Suas metas'), findsOneWidget);
      expect(find.text('Aceitar e continuar'), findsOneWidget);
      expect(find.text('Ajustar metas'), findsOneWidget);

      final salvo = await fakeFirestore
          .collection('usuarios')
          .doc('paciente_001')
          .get();
      expect(salvo.data()!['metas'], isNotNull);
      expect(salvo.data()!['triagemConcluida'], true);
    },
  );

  testWidgets(
    'Ao aceitar as metas, deve abrir o painel do paciente sem volta',
    (tester) async {
      final pacientesNoPainel = await montarTriagemPreenchida(
        tester,
        dataNascimento: DateTime(1960, 5, 10),
      );

      await tester.ensureVisible(find.text('Concluir'));
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Suas metas'), findsOneWidget);

      // A etapa 4 ja saiu da arvore quando o paciente toca aqui: o botao nao
      // pode depender do context dela.
      await tester.tap(find.text('Aceitar e continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Painel do paciente'), findsOneWidget);
      expect(find.text('Suas metas'), findsNothing);
      expect(pacientesNoPainel.last.metas, isNotNull);
      expect(pacientesNoPainel.last.triagemConcluida, isTrue);
      // O "voltar" nao retorna para as metas nem para a triagem.
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'Sem metas calculadas, deve ir direto ao painel do paciente',
    (tester) async {
      // Menor de idade: as formulas das metas valem a partir dos 18 anos.
      final hoje = DateTime.now();
      final pacientesNoPainel = await montarTriagemPreenchida(
        tester,
        dataNascimento: DateTime(hoje.year - 10, hoje.month),
      );

      await tester.ensureVisible(find.text('Concluir'));
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(find.text('Painel do paciente'), findsOneWidget);
      expect(find.text('Suas metas'), findsNothing);
      expect(pacientesNoPainel.last.metas, isNull);
    },
  );
}
