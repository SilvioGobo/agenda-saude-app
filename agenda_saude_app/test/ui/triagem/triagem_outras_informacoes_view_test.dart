import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_outras_informacoes_view.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_viewmodel.dart';

void main() {
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
      expect(find.text('Alergias e restrições alimentares'), findsOneWidget);
      expect(find.text('Medicamentos em uso contínuo'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);
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
}
