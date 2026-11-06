import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/paciente/falar_com_acompanhante_view.dart';

import '../../core/services/fake_telefone_service.dart';

void main() {
  group('FalarComAcompanhanteView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AcompanhanteRepository acompanhanteRepository;
    late FakeTelefoneService telefoneService;

    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );

    Future<void> vincular(String id, String nome, {String? telefone}) async {
      await acompanhanteRepository.salvarAcompanhante(Acompanhante(
        id: id,
        nome: nome,
        email: '$id@email.com',
        perfil: 'Acompanhante',
        telefone: telefone,
        pacientesVinculadosIds: [],
      ));
      await acompanhanteRepository.vincularPaciente(id, paciente.id);
    }

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);
      telefoneService = FakeTelefoneService();
      await PacienteRepository(firestore: fakeFirestore).salvarPaciente(paciente);
    });

    Future<void> montar(WidgetTester tester, {double escalaTexto = 1}) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: FalarComAcompanhanteView.comProviders(
            paciente,
            acompanhanteRepository: acompanhanteRepository,
            telefoneService: telefoneService,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester tester, String texto) async {
      await tester.scrollUntilVisible(find.text(texto), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text(texto));
      await tester.pumpAndSettle();
    }

    testWidgets('Deve listar os acompanhantes com o telefone e o botão de ligar', (tester) async {
      await vincular('cuidador_01', 'Carlos Souza', telefone: '67999990000');
      await montar(tester);

      expect(find.text('FALAR COM ACOMPANHANTE'), findsOneWidget);
      expect(find.text('Carlos Souza'), findsOneWidget);
      expect(find.text('(67) 99999-0000'), findsOneWidget);
      expect(find.text('LIGAR PARA CARLOS'), findsOneWidget);
    });

    testWidgets('"Ligar" disca o telefone do acompanhante', (tester) async {
      await vincular('cuidador_01', 'Carlos Souza', telefone: '67999990000');
      await montar(tester);

      await tocar(tester, 'LIGAR PARA CARLOS');

      expect(telefoneService.numerosChamados, ['67999990000']);
    });

    testWidgets('Acompanhante sem telefone aparece sem o botão de ligar', (tester) async {
      await vincular('cuidador_01', 'Ana Lima');
      await montar(tester);

      expect(find.text('Ana Lima'), findsOneWidget);
      expect(find.text('LIGAR PARA ANA'), findsNothing);
      expect(find.text('SEM TELEFONE CADASTRADO'), findsOneWidget);
      expect(find.textContaining('Peça para Ana cadastrar o telefone'), findsOneWidget);
    });

    testWidgets('Sem acompanhante, explica como vincular e mantém o SAMU', (tester) async {
      await montar(tester);

      expect(find.text('VOCÊ AINDA NÃO TEM ACOMPANHANTE'), findsOneWidget);
      expect(find.textContaining('Meu código de vínculo'), findsOneWidget);

      await tocar(tester, 'LIGAR PARA O SAMU (192)');
      expect(telefoneService.numerosChamados, ['192']);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await vincular('cuidador_01', 'Carlos Alberto de Souza', telefone: '67999990000');
      await vincular('cuidador_02', 'Ana Lima');

      await montar(tester, escalaTexto: 2);

      await tester.scrollUntilVisible(find.text('LIGAR PARA CARLOS'), 200);
      await tester.scrollUntilVisible(find.text('SEM TELEFONE CADASTRADO'), 200);
      await tester.scrollUntilVisible(find.text('LIGAR PARA O SAMU (192)'), 200);
      expect(find.text('LIGAR PARA O SAMU (192)'), findsOneWidget);
    });
  });
}
