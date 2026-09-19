import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_view.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_viewmodel.dart';
import 'package:agenda_saude_app/ui/sincronizacao/sincronizacao_bpm_viewmodel.dart';

import '../../core/services/fake_health_service.dart';

void main() {
  testWidgets('Painel do paciente mostra saudação, BPM e atalhos', (
    tester,
  ) async {
    final fakeFirestore = FakeFirebaseFirestore();
    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );

    final dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => PacienteViewModel(
                paciente: paciente,
                dadosRepository: dadosRepository,
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => SincronizacaoBpmViewModel(
                paciente: paciente,
                healthService: FakeHealthService(),
                dadosRepository: dadosRepository,
                plataformaSuportada: false,
              )..iniciar(),
            ),
          ],
          child: const PacienteView(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Olá, José'), findsOneWidget);
    expect(find.text('Sem leitura recente'), findsOneWidget);
    expect(find.text('AGUARDANDO LEITURA'), findsOneWidget);
    expect(find.text('Smartwatch indisponível'), findsOneWidget);
    expect(find.text('Código para o acompanhante'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Minha Rotina'), findsOneWidget);
    expect(find.text('Falar com Acompanhante'), findsOneWidget);
  });
}
