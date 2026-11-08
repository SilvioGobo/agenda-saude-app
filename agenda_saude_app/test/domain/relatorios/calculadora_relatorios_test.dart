import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/domain/relatorios/calculadora_relatorios.dart';
import 'package:agenda_saude_app/domain/relatorios/resumo_do_dia.dart';

const _cafe = RefeicaoPlanejada(id: 'cafe', nome: 'Café');
const _almoco = RefeicaoPlanejada(id: 'almoco', nome: 'Almoço');
const _jantar = RefeicaoPlanejada(id: 'jantar', nome: 'Jantar');

Paciente _paciente({
  bool diabetes = false,
  bool usaInsulina = false,
  bool cardiopatia = false,
  List<RefeicaoPlanejada>? plano = const [_cafe, _almoco],
  int? aguaMl,
  int? sonoMaxHoras,
  List<Medicamento> medicamentos = const [],
}) {
  return Paciente(
    id: 'paciente_01',
    nome: 'José Silva',
    email: 'jose@email.com',
    perfil: 'Paciente',
    medicamentos: medicamentos,
    possuiDiabetes: diabetes,
    usaInsulina: diabetes ? usaInsulina : null,
    possuiCardiopatia: cardiopatia,
    codigoVinculo: 'ABC123',
    refeicoes: plano,
    metas: aguaMl == null && sonoMaxHoras == null
        ? null
        : MetasPersonalizadas(
            imc: 24.7,
            classificacaoImc: ClassificacaoImc.adequado,
            hidratacaoMl: aguaMl ?? 2000,
            sonoMinHoras: 7,
            sonoMaxHoras: sonoMaxHoras ?? 9,
            passos: 6000,
            exercicioMinutosSemana: 150,
            calorias: 1800,
            carboidratosG: 225,
            proteinasG: 90,
            gordurasG: 60,
            fibrasG: 25,
            gorduraSaturadaMaxG: 14,
            acucarLivreMaxG: 45,
            sodioMaxMg: 2000,
          ),
  );
}

RegistroAgua _agua(DateTime quando, [int ml = 250]) => RegistroAgua(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      quantidadeML: ml,
    );

RegistroRefeicao _refeicao(String refeicaoId, DateTime quando) =>
    RegistroRefeicao(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      refeicaoId: refeicaoId,
      nome: refeicaoId,
    );

// A noite como o app grava: ao acordar, inicio e fim valem o instante do
// registro.
RegistroSono _sono(DateTime quando, {double horas = 7.5, int qualidade = 4}) =>
    RegistroSono(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      dataFim: quando,
      horasTotais: horas,
      qualidade: qualidade,
    );

const _losartana = Medicamento(
  id: 'm1',
  nome: 'Losartana',
  dose: '50 mg',
  horarios: ['08:00'],
);
const _metformina = Medicamento(
  id: 'm2',
  nome: 'Metformina',
  dose: '500 mg',
  horarios: ['12:00', '20:00'],
);

RegistroMedicacao _dose(String medicamentoId, String horario, DateTime quando) =>
    RegistroMedicacao(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      medicamentoId: medicamentoId,
      horario: horario,
      nome: medicamentoId,
    );

RegistroExercicio _exercicio(
  DateTime quando, {
  int minutos = 30,
  String tipo = 'Caminhada',
  String intensidade = 'Moderada',
}) =>
    RegistroExercicio(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      tipoExercicio: tipo,
      duracaoMinutos: minutos,
      intensidade: intensidade,
    );

RegistroDiabete _diabete(
  DateTime quando, {
  double? glicose,
  String momento = 'Ao acordar',
  double? dose,
  String? tipo,
}) =>
    RegistroDiabete(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      nivelGlicose: glicose,
      momento: momento,
      doseInsulina: dose,
      tipoInsulina: tipo,
    );

BatimentoCardiaco _bpm(int valor, DateTime quando) => BatimentoCardiaco(
      id: '',
      pacienteId: 'paciente_01',
      bpm: valor,
      timestamp: quando,
    );

Alerta _alerta(String tipo, DateTime quando) => Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: tipo,
      mensagem: 'alerta $tipo',
      dataHora: quando,
    );

// Varios copos de uma vez, de hora em hora a partir das 8h do dia.
List<RegistroAgua> _copos(DateTime dia, int quantidade) => [
      for (var i = 0; i < quantidade; i++)
        _agua(DateTime(dia.year, dia.month, dia.day, 8 + i)),
    ];

void main() {
  final dia = DateTime(2026, 11, 1);

  group('CalculadoraRelatorios.resumirDia Testes', () {
    group('Hidratação', () {
      test('Deve somar os copos do dia e comparar com a meta padrão de 2 litros', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          agua: _copos(dia, 6),
        );

        expect(resumo.hidratacao.totalMl, 1500);
        expect(resumo.hidratacao.metaMl, 2000);
        expect(resumo.hidratacao.copos, 6);
        expect(resumo.hidratacao.metaCopos, 8);
        expect(resumo.hidratacao.progresso, 0.75);
        expect(resumo.hidratacao.registrou, isTrue);
        expect(resumo.hidratacao.metaAtingida, isFalse);
      });

      test('Deve usar a meta calculada na triagem e não deixar a barra passar de 100%', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(aguaMl: 1500),
          dia: dia,
          agua: _copos(dia, 8),
        );

        expect(resumo.hidratacao.metaMl, 1500);
        expect(resumo.hidratacao.totalMl, 2000);
        expect(resumo.hidratacao.progresso, 1);
        expect(resumo.hidratacao.metaAtingida, isTrue);
      });

      test('Deve dizer que não registrou quando não há nenhum copo', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
        );

        expect(resumo.hidratacao.registrou, isFalse);
        expect(resumo.hidratacao.totalMl, 0);
        expect(resumo.hidratacao.progresso, 0);
        expect(resumo.hidratacao.metaAtingida, isFalse);
      });
    });

    group('Refeições', () {
      test('Deve marcar como feitas só as refeições do plano que têm registro', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(plano: const [_cafe, _almoco, _jantar]),
          dia: dia,
          refeicoes: [
            _refeicao('almoco', DateTime(2026, 11, 1, 12)),
            _refeicao('cafe', DateTime(2026, 11, 1, 7)),
          ],
        );

        final refeicoes = resumo.refeicoes;
        expect(refeicoes.total, 3);
        expect(refeicoes.feitas, 2);
        expect(refeicoes.todasFeitas, isFalse);
        expect(refeicoes.progresso, closeTo(2 / 3, 0.0001));
        expect(
          refeicoes.planejadas.map((item) => item.feita),
          [true, true, false],
        );
        expect(refeicoes.planejadas.first.feitaEm, DateTime(2026, 11, 1, 7));
      });

      test('Deve contar a refeição marcada em dois aparelhos uma vez só, pela primeira marcação', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          refeicoes: [
            _refeicao('cafe', DateTime(2026, 11, 1, 8)),
            _refeicao('cafe', DateTime(2026, 11, 1, 7, 30)),
          ],
        );

        expect(resumo.refeicoes.feitas, 1);
        expect(
          resumo.refeicoes.planejadas.first.feitaEm,
          DateTime(2026, 11, 1, 7, 30),
        );
      });

      test('Deve separar as refeições marcadas que saíram do plano', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          refeicoes: [_refeicao('ceia', DateTime(2026, 11, 1, 22))],
        );

        expect(resumo.refeicoes.feitas, 0);
        expect(resumo.refeicoes.foraDoPlano.single.refeicaoId, 'ceia');
        expect(resumo.refeicoes.registrou, isTrue);
      });

      test('Deve considerar todas feitas só quando o plano tem refeições e todas foram marcadas', () {
        final completo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          refeicoes: [
            _refeicao('cafe', DateTime(2026, 11, 1, 7)),
            _refeicao('almoco', DateTime(2026, 11, 1, 12)),
          ],
        );
        final semPlano = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(plano: const []),
          dia: dia,
        );

        expect(completo.refeicoes.todasFeitas, isTrue);
        expect(completo.refeicoes.progresso, 1);
        expect(semPlano.refeicoes.total, 0);
        expect(semPlano.refeicoes.todasFeitas, isFalse);
        expect(semPlano.refeicoes.progresso, 0);
      });
    });

    group('Glicemia e insulina', () {
      test('Não deve ter o bloco de diabetes para quem não tem diabetes', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
        );

        expect(resumo.diabetes, isNull);
      });

      test('Deve montar o checklist do dia e as estatísticas das medições', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(diabetes: true, usaInsulina: true),
          dia: dia,
          diabete: [
            _diabete(
              DateTime(2026, 11, 1, 22),
              momento: 'Insulina lenta (22h)',
              dose: 14,
              tipo: 'Lenta',
            ),
            _diabete(
              DateTime(2026, 11, 1, 7),
              glicose: 112,
              dose: 6,
              tipo: 'Rápida',
            ),
            _diabete(
              DateTime(2026, 11, 1, 11, 30),
              glicose: 62,
              momento: 'Antes do almoço',
            ),
            _diabete(
              DateTime(2026, 11, 1, 18),
              glicose: 190,
              momento: 'Antes do jantar',
            ),
            _diabete(
              DateTime(2026, 11, 1, 15),
              glicose: 260,
              momento: 'Outra medição',
            ),
          ],
        );

        final diabetes = resumo.diabetes!;
        expect(
          diabetes.checklist.map((item) => item.momento.nome),
          [
            'Ao acordar',
            'Antes do almoço',
            'Antes do jantar',
            'Antes de dormir',
            'Insulina lenta (22h)',
          ],
        );
        expect(
          diabetes.checklist.map((item) => item.feito),
          [true, true, true, false, true],
        );
        expect(diabetes.medicoesPrevistas, 4);
        expect(diabetes.medicoesFeitas, 3);
        expect(diabetes.completo, isFalse);
        expect(diabetes.outrasMedicoes.single.nivelGlicose, 260);

        final glicemia = diabetes.glicemia;
        expect(glicemia.medicoes, 4);
        expect(glicemia.media, 156);
        expect(glicemia.menor, 62);
        expect(glicemia.maior, 260);
        expect(glicemia.naFaixa, 1);
        expect(glicemia.baixas, 1);
        expect(glicemia.altas, 2);
        expect(glicemia.muitoAltas, 1);
        expect(glicemia.temCritica, isTrue);

        expect(diabetes.insulinaTotal, 20);
        expect(diabetes.aplicacoes, 2);
        // Do mais antigo para o mais recente.
        expect(diabetes.registros.first.dataHora, DateTime(2026, 11, 1, 7));
        expect(diabetes.registros.last.dataHora, DateTime(2026, 11, 1, 22));
      });

      test('Deve considerar o checklist completo quando todos os momentos têm registro', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(diabetes: true),
          dia: dia,
          diabete: [
            _diabete(DateTime(2026, 11, 1, 7), glicose: 100),
            _diabete(
              DateTime(2026, 11, 1, 11),
              glicose: 110,
              momento: 'Antes do almoço',
            ),
            _diabete(
              DateTime(2026, 11, 1, 17),
              glicose: 120,
              momento: 'Antes do jantar',
            ),
            _diabete(
              DateTime(2026, 11, 1, 21),
              glicose: 130,
              momento: 'Antes de dormir',
            ),
          ],
        );

        // Sem insulina, o checklist tem so as 4 medicoes.
        expect(resumo.diabetes!.checklist.length, 4);
        expect(resumo.diabetes!.completo, isTrue);
        expect(resumo.diabetes!.glicemia.temCritica, isFalse);
      });

      test('Deve usar o registro mais recente quando um momento foi registrado duas vezes', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(diabetes: true),
          dia: dia,
          diabete: [
            _diabete(DateTime(2026, 11, 1, 8), glicose: 90),
            _diabete(DateTime(2026, 11, 1, 7), glicose: 300),
          ],
        );

        expect(resumo.diabetes!.checklist.first.registro!.nivelGlicose, 90);
      });

      test('Deve classificar as medições nos limites das faixas', () {
        final estatisticas = EstatisticasGlicemia.de([
          _diabete(dia, glicose: 53), // muito baixa
          _diabete(dia, glicose: 69), // baixa
          _diabete(dia, glicose: 70), // na faixa
          _diabete(dia, glicose: 180), // na faixa
          _diabete(dia, glicose: 181), // alta
          _diabete(dia, glicose: 250), // alta
          _diabete(dia, glicose: 251), // muito alta
          _diabete(dia, momento: 'Insulina lenta (22h)', dose: 10), // sem glicemia
        ]);

        expect(estatisticas.medicoes, 7);
        expect(estatisticas.baixas, 2);
        expect(estatisticas.naFaixa, 2);
        expect(estatisticas.altas, 3);
        expect(estatisticas.muitoAltas, 1);
      });

      test('Deve devolver estatísticas vazias sem nenhuma medição', () {
        final estatisticas = EstatisticasGlicemia.de(const []);

        expect(estatisticas.medicoes, 0);
        expect(estatisticas.media, isNull);
        expect(estatisticas.menor, isNull);
        expect(estatisticas.maior, isNull);
        expect(estatisticas.temCritica, isFalse);
      });
    });

    group('Batimentos e alertas', () {
      test('Deve resumir os batimentos e contar as leituras fora da zona padrão (60 a 100)', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          batimentos: [
            _bpm(55, DateTime(2026, 11, 1, 6)),
            _bpm(70, DateTime(2026, 11, 1, 9)),
            _bpm(100, DateTime(2026, 11, 1, 12)),
            _bpm(101, DateTime(2026, 11, 1, 15)),
          ],
        );

        final batimentos = resumo.batimentos;
        expect(batimentos.leituras, 4);
        expect(batimentos.media, 81.5);
        expect(batimentos.minimo, 55);
        expect(batimentos.maximo, 101);
        expect(batimentos.foraDaZona, 2);
        expect(batimentos.zonaMinima, 60);
        expect(batimentos.zonaMaxima, 100);
      });

      test('Deve usar a zona mais estreita do cardiopata (60 a 90)', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(cardiopatia: true),
          dia: dia,
          batimentos: [
            _bpm(55, DateTime(2026, 11, 1, 6)),
            _bpm(70, DateTime(2026, 11, 1, 9)),
            _bpm(91, DateTime(2026, 11, 1, 12)),
          ],
        );

        expect(resumo.batimentos.foraDaZona, 2);
        expect(resumo.batimentos.zonaMaxima, 90);
      });

      test('Deve indicar que não há leituras quando o smartwatch não mediu', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
        );

        expect(resumo.batimentos.temLeituras, isFalse);
        expect(resumo.batimentos.media, isNull);
        expect(resumo.batimentos.zonaMinima, 60);
      });

      test('Deve montar a curva do dia com as leituras resumidas em pontos', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          batimentos: [
            // Do mais recente para o mais antigo, como a consulta devolve.
            _bpm(90, DateTime(2026, 11, 1, 15, 4)),
            _bpm(80, DateTime(2026, 11, 1, 9, 8)),
            _bpm(70, DateTime(2026, 11, 1, 9, 2)),
          ],
        );

        final serie = resumo.batimentos.serie!;
        expect(resumo.batimentos.temSerie, isTrue);
        expect(serie.inicio, DateTime(2026, 11, 1));
        expect(serie.fim, DateTime(2026, 11, 2));
        expect(serie.pontos.map((p) => p.inicio), [
          DateTime(2026, 11, 1, 9, 0),
          DateTime(2026, 11, 1, 15, 0),
        ]);
        expect(serie.pontos.map((p) => p.media), [75, 90]);
      });

      test('Deve montar a curva só com o que é do dia do relatório', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          batimentos: [
            _bpm(70, DateTime(2026, 11, 1, 9)),
            _bpm(99, DateTime(2026, 11, 2, 9)),
          ],
        );

        expect(resumo.batimentos.serie!.pontos, hasLength(1));
      });

      test('Não deve ter curva quando o smartwatch não mediu', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
        );

        expect(resumo.batimentos.serie, isNull);
        expect(resumo.batimentos.temSerie, isFalse);
      });

      test('Não deve montar a curva quando só se contam as leituras, sem o dia', () {
        final batimentos = CalculadoraRelatorios.resumirBatimentos(
          [_bpm(70, DateTime(2026, 11, 1, 9))],
          possuiCardiopatia: false,
        );

        expect(batimentos.leituras, 1);
        expect(batimentos.serie, isNull);
      });

      test('Deve ordenar os alertas do mais recente para o mais antigo e contá-los por tipo', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          alertas: [
            _alerta(Alerta.tipoAtencao, DateTime(2026, 11, 1, 10)),
            _alerta(Alerta.tipoEmergencia, DateTime(2026, 11, 1, 15)),
            _alerta(Alerta.tipoAtencao, DateTime(2026, 11, 1, 8)),
          ],
        );

        expect(resumo.alertas.first.tipo, Alerta.tipoEmergencia);
        expect(resumo.alertas.last.dataHora, DateTime(2026, 11, 1, 8));
        expect(resumo.emergencias, 1);
        expect(resumo.avisos, 2);
        expect(resumo.temAlertaGrave, isTrue);
      });

      test('Aviso de atenção sozinho não é alerta grave, mas hipoglicemia é', () {
        final soAviso = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          alertas: [_alerta(Alerta.tipoAtencao, DateTime(2026, 11, 1, 10))],
        );
        final hipoglicemia = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(diabetes: true),
          dia: dia,
          diabete: [_diabete(DateTime(2026, 11, 1, 7), glicose: 55)],
        );

        expect(soAviso.temAlertaGrave, isFalse);
        expect(hipoglicemia.temAlertaGrave, isTrue);
      });
    });

    group('Sono', () {
      test('Deve mostrar a noite registrada e comparar com a meta padrão de 7 a 9 horas', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          sono: [_sono(DateTime(2026, 11, 1, 6, 30), horas: 8, qualidade: 5)],
        );

        expect(resumo.sono.registrou, isTrue);
        expect(resumo.sono.registro!.horasTotais, 8);
        expect(resumo.sono.registro!.qualidade, 5);
        expect(resumo.sono.metaMinHoras, 7);
        expect(resumo.sono.metaMaxHoras, 9);
        expect(resumo.sono.metaAtingida, isTrue);
      });

      test('Sem noite registrada, o sono não conta como registrado nem como meta atingida', () {
        final resumo =
            CalculadoraRelatorios.resumirDia(paciente: _paciente(), dia: dia);

        expect(resumo.sono.registrou, isFalse);
        expect(resumo.sono.registro, isNull);
        expect(resumo.sono.metaAtingida, isFalse);
      });

      test('Deve atingir a meta a partir do mínimo, sem penalizar quem dormiu mais', () {
        SonoDoDia comHoras(double horas) => CalculadoraRelatorios.resumirDia(
              paciente: _paciente(),
              dia: dia,
              sono: [_sono(DateTime(2026, 11, 1, 6, 30), horas: horas)],
            ).sono;

        expect(comHoras(6.5).metaAtingida, isFalse);
        expect(comHoras(7).metaAtingida, isTrue);
        expect(comHoras(11).metaAtingida, isTrue);
      });

      test('Deve usar a meta de sono calculada para o paciente', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(sonoMaxHoras: 8),
          dia: dia,
        );

        expect(resumo.sono.metaMinHoras, 7);
        expect(resumo.sono.metaMaxHoras, 8);
      });

      test('Quando há mais de uma noite no dia, vale a mais recente', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          sono: [
            _sono(DateTime(2026, 11, 1, 9), horas: 8),
            _sono(DateTime(2026, 11, 1, 6), horas: 5),
          ],
        );

        expect(resumo.sono.registro!.horasTotais, 8);
      });
    });

    group('Medicação', () {
      final doisRemedios = _paciente(medicamentos: const [_losartana, _metformina]);

      test('Deve listar as doses do plano em ordem de horário e marcar as tomadas', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: doisRemedios,
          dia: dia,
          medicacoes: [
            _dose('m2', '12:00', DateTime(2026, 11, 1, 12, 20)),
            _dose('m1', '08:00', DateTime(2026, 11, 1, 8, 10)),
          ],
        );

        final m = resumo.medicacao;
        expect(m.planejadas.map((d) => '${d.dose.nome} ${d.dose.horario}'),
            ['Losartana 08:00', 'Metformina 12:00', 'Metformina 20:00']);
        expect(m.planejadas.map((d) => d.tomada), [true, true, false]);
        expect(m.planejadas.first.tomadaEm, DateTime(2026, 11, 1, 8, 10));
        expect(m.tomadas, 2);
        expect(m.total, 3);
        expect(m.todasTomadas, isFalse);
        expect(m.progresso, closeTo(2 / 3, 0.0001));
        expect(m.registrou, isTrue);
      });

      test('Deve valer a primeira marcação quando a dose foi marcada duas vezes', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: doisRemedios,
          dia: dia,
          medicacoes: [
            _dose('m1', '08:00', DateTime(2026, 11, 1, 10, 0)),
            _dose('m1', '08:00', DateTime(2026, 11, 1, 8, 5)),
          ],
        );

        expect(resumo.medicacao.planejadas.first.tomadaEm,
            DateTime(2026, 11, 1, 8, 5));
        expect(resumo.medicacao.tomadas, 1);
      });

      test('Deve guardar à parte as doses que já não estão na lista, sem contá-las como tomadas', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(medicamentos: const [_losartana]),
          dia: dia,
          medicacoes: [
            // O remedio mudou de horario depois.
            _dose('m1', '07:00', DateTime(2026, 11, 1, 7, 10)),
            // E outro foi apagado.
            _dose('m9', '09:00', DateTime(2026, 11, 1, 9, 5)),
          ],
        );

        final m = resumo.medicacao;
        expect(m.tomadas, 0);
        expect(m.foraDoPlano.map((r) => r.medicamentoId), ['m1', 'm9']);
        expect(m.registrou, isTrue);
        expect(resumo.temRegistros, isTrue);
      });

      test('Sem remédios cadastrados, não há doses e elas não entram na conta do dia', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
        );

        expect(resumo.medicacao.total, 0);
        expect(resumo.medicacao.todasTomadas, isFalse);
        expect(resumo.medicacao.registrou, isFalse);
        expect(resumo.itensTotais, 3);
      });
    });

    group('Exercício', () {
      test('Deve listar os exercícios do dia, do mais antigo para o mais recente, e somar os minutos', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          exercicios: [
            _exercicio(DateTime(2026, 11, 1, 17), minutos: 20, tipo: 'Alongamento'),
            _exercicio(DateTime(2026, 11, 1, 7), minutos: 40),
          ],
        );

        expect(resumo.exercicio.fez, isTrue);
        expect(resumo.exercicio.registros.map((r) => r.tipoExercicio),
            ['Caminhada', 'Alongamento']);
        expect(resumo.exercicio.minutos, 60);
      });

      test('Sem exercício no dia, nada foi feito', () {
        final resumo =
            CalculadoraRelatorios.resumirDia(paciente: _paciente(), dia: dia);

        expect(resumo.exercicio.fez, isFalse);
        expect(resumo.exercicio.minutos, 0);
        expect(resumo.exercicio.registros, isEmpty);
      });

      test('Deve comparar os minutos da semana até o dia com a meta padrão de 150', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          exercicios: [_exercicio(DateTime(2026, 11, 1, 7), minutos: 30)],
          exerciciosDaSemana: [
            _exercicio(DateTime(2026, 10, 27, 8), minutos: 60),
            _exercicio(DateTime(2026, 11, 1, 7), minutos: 30),
          ],
        );

        expect(resumo.exercicio.temProgressoDaSemana, isTrue);
        expect(resumo.exercicio.minutosNaSemana, 90);
        expect(resumo.exercicio.metaSemanalMinutos, 150);
        expect(resumo.exercicio.minutosQueFaltavam, 60);
        expect(resumo.exercicio.progressoDaSemana, closeTo(0.6, 0.0001));
        expect(resumo.exercicio.metaDaSemanaAtingida, isFalse);
      });

      test('Deve atingir a meta da semana e travar a barra em 100%', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          exerciciosDaSemana: [
            _exercicio(DateTime(2026, 10, 27, 8), minutos: 120),
            _exercicio(DateTime(2026, 10, 30, 8), minutos: 60),
          ],
        );

        expect(resumo.exercicio.minutosNaSemana, 180);
        expect(resumo.exercicio.metaDaSemanaAtingida, isTrue);
        expect(resumo.exercicio.minutosQueFaltavam, 0);
        expect(resumo.exercicio.progressoDaSemana, 1);
      });

      test('Sem a semana lida, o progresso fica desconhecido em vez de zerado', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          exercicios: [_exercicio(DateTime(2026, 11, 1, 7))],
        );

        expect(resumo.exercicio.temProgressoDaSemana, isFalse);
        expect(resumo.exercicio.minutosNaSemana, isNull);
        expect(resumo.exercicio.progressoDaSemana, 0);
        expect(resumo.exercicio.metaDaSemanaAtingida, isFalse);
        expect(resumo.exercicio.minutosQueFaltavam, 0);
      });

      test('Deve usar a meta de exercício calculada para o paciente', () {
        final paciente = _paciente().copyWith(
          metas: MetasPersonalizadas(
            imc: 24.7,
            classificacaoImc: ClassificacaoImc.adequado,
            hidratacaoMl: 2000,
            sonoMinHoras: 7,
            sonoMaxHoras: 9,
            passos: 6000,
            exercicioMinutosSemana: 90,
            calorias: 1800,
            carboidratosG: 225,
            proteinasG: 90,
            gordurasG: 60,
            fibrasG: 25,
            gorduraSaturadaMaxG: 14,
            acucarLivreMaxG: 45,
            sodioMaxMg: 2000,
          ),
        );

        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: paciente,
          dia: dia,
          exerciciosDaSemana: [_exercicio(DateTime(2026, 11, 1, 7), minutos: 90)],
        );

        expect(resumo.exercicio.metaSemanalMinutos, 90);
        expect(resumo.exercicio.metaDaSemanaAtingida, isTrue);
      });
    });

    group('Situação do dia', () {
      test('Quem tem remédios só fecha o dia completo com todas as doses tomadas', () {
        final paciente = _paciente(medicamentos: const [_losartana, _metformina]);
        ResumoDoDia resumir(List<RegistroMedicacao> doses) =>
            CalculadoraRelatorios.resumirDia(
              paciente: paciente,
              dia: dia,
              agua: _copos(dia, 8),
              refeicoes: [
                _refeicao('cafe', DateTime(2026, 11, 1, 7)),
                _refeicao('almoco', DateTime(2026, 11, 1, 12)),
              ],
              sono: [_sono(DateTime(2026, 11, 1, 6, 30))],
              medicacoes: doses,
            );

        final faltando = resumir([
          _dose('m1', '08:00', DateTime(2026, 11, 1, 8, 5)),
          _dose('m2', '12:00', DateTime(2026, 11, 1, 12, 5)),
        ]);
        expect(faltando.itensTotais, 4);
        expect(faltando.itensCompletos, 3);
        expect(faltando.situacao, SituacaoDoDia.parcial);

        final todas = resumir([
          _dose('m1', '08:00', DateTime(2026, 11, 1, 8, 5)),
          _dose('m2', '12:00', DateTime(2026, 11, 1, 12, 5)),
          _dose('m2', '20:00', DateTime(2026, 11, 1, 20, 5)),
        ]);
        expect(todas.itensCompletos, 4);
        expect(todas.situacao, SituacaoDoDia.completo);
      });

      test('Só uma dose tomada já tira o dia de "sem registro"', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(medicamentos: const [_losartana]),
          dia: dia,
          medicacoes: [_dose('m1', '08:00', DateTime(2026, 11, 1, 8, 5))],
        );

        expect(resumo.temRegistros, isTrue);
        expect(resumo.situacao, SituacaoDoDia.parcial);
      });

      test('Só o exercício já tira o dia de "sem registro", mas não conta como item da rotina', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          exercicios: [_exercicio(DateTime(2026, 11, 1, 7))],
        );

        expect(resumo.temRegistros, isTrue);
        expect(resumo.situacao, SituacaoDoDia.parcial);
        expect(resumo.itensTotais, 3);
        expect(resumo.itensCompletos, 0);
      });

      test('Um dia de descanso não deixa a rotina incompleta: o exercício não entra no "dia completo"', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          agua: _copos(dia, 8),
          refeicoes: [
            _refeicao('cafe', DateTime(2026, 11, 1, 7)),
            _refeicao('almoco', DateTime(2026, 11, 1, 12)),
          ],
          sono: [_sono(DateTime(2026, 11, 1, 6, 30))],
        );

        expect(resumo.exercicio.fez, isFalse);
        expect(resumo.situacao, SituacaoDoDia.completo);
      });

      test('Sem nenhum registro da rotina o dia fica sem registro, mesmo com batimentos e alertas', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          batimentos: [_bpm(80, DateTime(2026, 11, 1, 9))],
          alertas: [_alerta(Alerta.tipoAtencao, DateTime(2026, 11, 1, 10))],
        );

        expect(resumo.temRegistros, isFalse);
        expect(resumo.situacao, SituacaoDoDia.semRegistro);
      });

      test('Com algum registro, mas faltando algo, o dia fica parcial', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          agua: _copos(dia, 2),
        );

        expect(resumo.situacao, SituacaoDoDia.parcial);
        expect(resumo.itensTotais, 3);
        expect(resumo.itensCompletos, 0);
      });

      test('Com a meta de água, todas as refeições e o sono registrado o dia fica completo', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          agua: _copos(dia, 8),
          refeicoes: [
            _refeicao('cafe', DateTime(2026, 11, 1, 7)),
            _refeicao('almoco', DateTime(2026, 11, 1, 12)),
          ],
          sono: [_sono(DateTime(2026, 11, 1, 6, 30))],
        );

        expect(resumo.situacao, SituacaoDoDia.completo);
        expect(resumo.itensCompletos, 3);
        expect(resumo.itensTotais, 3);
      });

      test('Sem o sono registrado, a água e as refeições não bastam para o dia ficar completo', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          agua: _copos(dia, 8),
          refeicoes: [
            _refeicao('cafe', DateTime(2026, 11, 1, 7)),
            _refeicao('almoco', DateTime(2026, 11, 1, 12)),
          ],
        );

        expect(resumo.situacao, SituacaoDoDia.parcial);
        expect(resumo.itensCompletos, 2);
        expect(resumo.itensTotais, 3);
      });

      test('Para o diabético, o checklist de glicemia também precisa estar completo', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(diabetes: true),
          dia: dia,
          agua: _copos(dia, 8),
          refeicoes: [
            _refeicao('cafe', DateTime(2026, 11, 1, 7)),
            _refeicao('almoco', DateTime(2026, 11, 1, 12)),
          ],
          sono: [_sono(DateTime(2026, 11, 1, 6, 30))],
          diabete: [_diabete(DateTime(2026, 11, 1, 7), glicose: 100)],
        );

        expect(resumo.itensTotais, 4);
        expect(resumo.itensCompletos, 3);
        expect(resumo.situacao, SituacaoDoDia.parcial);
      });

      test('Sem refeições no plano, só a água e o sono entram na conta', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(plano: const []),
          dia: dia,
          agua: _copos(dia, 8),
          sono: [_sono(DateTime(2026, 11, 1, 6, 30))],
        );

        expect(resumo.itensTotais, 2);
        expect(resumo.situacao, SituacaoDoDia.completo);
      });

      test('Só a noite de sono registrada já tira o dia de "sem registro"', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: dia,
          sono: [_sono(DateTime(2026, 11, 1, 6, 30))],
        );

        expect(resumo.temRegistros, isTrue);
        expect(resumo.situacao, SituacaoDoDia.parcial);
        expect(resumo.itensCompletos, 1);
      });

      test('Deve guardar o dia sem a hora', () {
        final resumo = CalculadoraRelatorios.resumirDia(
          paciente: _paciente(),
          dia: DateTime(2026, 11, 1, 15, 40),
        );

        expect(resumo.dia, DateTime(2026, 11, 1));
      });
    });
  });

  group('CalculadoraRelatorios.resumirMes Testes', () {
    // Novembro de 2026 tem 30 dias.
    final novembro = DateTime(2026, 11);

    DateTime em(int diaDoMes, [int hora = 9]) =>
        DateTime(2026, 11, diaDoMes, hora);

    test('No mês atual, só os dias anteriores a hoje contam', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 5, 18),
      );

      expect(resumo.diasNoMes, 30);
      expect(resumo.mes, DateTime(2026, 11, 1));
      expect(resumo.dias.length, 4);
      expect(resumo.dias.last.dia, DateTime(2026, 11, 4));
      expect(resumo.diaDeHoje, 5);
      expect(resumo.diaEncerrado(4), isNotNull);
      expect(resumo.diaEncerrado(5), isNull);
      expect(resumo.diaEncerrado(0), isNull);
    });

    test('Num mês passado, todos os dias contam e não há dia de hoje', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 12, 3),
      );

      expect(resumo.dias.length, 30);
      expect(resumo.diaDeHoje, isNull);
    });

    test('No primeiro dia do mês ainda não há nenhum dia encerrado', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 1, 8),
      );

      expect(resumo.dias, isEmpty);
      expect(resumo.temDiasEncerrados, isFalse);
      expect(resumo.diaDeHoje, 1);
    });

    test('Num mês futuro nenhum dia terminou', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: DateTime(2026, 12),
        hoje: DateTime(2026, 11, 20),
      );

      expect(resumo.dias, isEmpty);
      expect(resumo.diaDeHoje, isNull);
    });

    test('Deve contar fevereiro de ano bissexto com 29 dias', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: DateTime(2028, 2, 15),
        hoje: DateTime(2028, 3, 10),
      );

      expect(resumo.diasNoMes, 29);
      expect(resumo.dias.length, 29);
    });

    test('Deve distribuir os registros pelos dias e classificar cada dia', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
        agua: [
          ..._copos(em(1), 8), // meta batida
          ..._copos(em(2), 4),
          ..._copos(em(4), 2),
          // Hoje ainda nao terminou: fica de fora.
          ..._copos(em(6), 8),
        ],
        refeicoes: [
          _refeicao('cafe', em(1, 7)),
          _refeicao('almoco', em(1, 12)),
          _refeicao('cafe', em(2, 7)),
        ],
        sono: [_sono(em(1, 6))],
      );

      expect(resumo.dias.length, 5);
      expect(
        resumo.dias.map((dia) => dia.situacao),
        [
          SituacaoDoDia.completo,
          SituacaoDoDia.parcial,
          SituacaoDoDia.semRegistro,
          SituacaoDoDia.parcial,
          SituacaoDoDia.semRegistro,
        ],
      );
      expect(resumo.diasCompletos, 1);
      expect(resumo.diasParciais, 2);
      expect(resumo.diasSemRegistro, 2);
      expect(resumo.diasComRegistro, 3);
    });

    test('Deve contar cada noite no dia em que o paciente acordou e a registrou', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
        sono: [_sono(em(2, 6), horas: 6), _sono(em(4, 7), horas: 8)],
      );

      expect(resumo.dias[0].sono.registrou, isFalse);
      expect(resumo.dias[1].sono.registro!.horasTotais, 6);
      expect(resumo.dias[2].sono.registrou, isFalse);
      expect(resumo.dias[3].sono.registro!.horasTotais, 8);
    });

    test('Deve distribuir as doses tomadas pelos dias do mês', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(medicamentos: const [_losartana]),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
        medicacoes: [_dose('m1', '08:00', em(2, 8))],
      );

      expect(resumo.dias[0].medicacao.tomadas, 0);
      expect(resumo.dias[1].medicacao.tomadas, 1);
      expect(resumo.dias[1].medicacao.todasTomadas, isTrue);
      expect(resumo.dias[2].medicacao.tomadas, 0);
      expect(resumo.dias[1].situacao, SituacaoDoDia.parcial);
    });

    test('Deve distribuir os exercícios pelos dias do mês, sem o progresso da semana', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
        exercicios: [
          _exercicio(em(2, 7), minutos: 30),
          _exercicio(em(2, 18), minutos: 15),
          _exercicio(em(4, 7), minutos: 45),
        ],
      );

      expect(resumo.dias[0].exercicio.fez, isFalse);
      expect(resumo.dias[1].exercicio.minutos, 45);
      expect(resumo.dias[3].exercicio.minutos, 45);
      // O mes so le o dia a dia: a semana inteira vem do relatorio do dia.
      expect(resumo.dias[1].exercicio.temProgressoDaSemana, isFalse);
      // Dias so com exercicio ja tem registro, mas ficam parciais.
      expect(resumo.dias[1].situacao, SituacaoDoDia.parcial);
    });

    test('Deve calcular os totais de hidratação e refeições do mês', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
        agua: [..._copos(em(1), 8), ..._copos(em(2), 4), ..._copos(em(4), 2)],
        refeicoes: [
          _refeicao('cafe', em(1, 7)),
          _refeicao('almoco', em(1, 12)),
          _refeicao('cafe', em(2, 7)),
        ],
      );

      expect(resumo.metaAguaMl, 2000);
      expect(resumo.diasComAgua, 3);
      expect(resumo.diasMetaDeAgua, 1);
      // (2000 + 1000 + 500) / 3 dias com agua anotada.
      expect(resumo.mediaAguaMl, closeTo(1166.67, 0.01));
      expect(resumo.refeicoesPrevistas, 10); // 2 por dia, 5 dias
      expect(resumo.refeicoesFeitas, 3);
      expect(resumo.diasComTodasAsRefeicoes, 1);
    });

    test('Não deve ter média de água quando nenhum dia teve anotação', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
      );

      expect(resumo.mediaAguaMl, isNull);
      expect(resumo.diasComAgua, 0);
      expect(resumo.diasComRegistro, 0);
    });

    test('Deve montar as séries do gráfico com uma posição por dia do mês', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(diabetes: true),
        mes: novembro,
        hoje: DateTime(2026, 11, 5),
        agua: [..._copos(em(1), 8), ..._copos(em(3), 2)],
        diabete: [
          _diabete(em(1, 7), glicose: 100),
          _diabete(em(1, 11), glicose: 140, momento: 'Antes do almoço'),
          _diabete(em(2, 7), glicose: 90),
        ],
      );

      expect(resumo.serieAgua.length, 30);
      expect(resumo.serieAgua.take(5).toList(), [2000, null, 500, null, null]);
      expect(resumo.serieGlicemia.take(5).toList(), [120, 90, null, null, null]);
    });

    test('Deve somar a glicemia e a insulina do mês e apontar os dias com problema', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(diabetes: true, usaInsulina: true),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
        diabete: [
          _diabete(em(1, 7), glicose: 62, dose: 6, tipo: 'Rápida'),
          _diabete(em(2, 7), glicose: 300),
          _diabete(
            em(2, 22),
            momento: 'Insulina lenta (22h)',
            dose: 14,
            tipo: 'Lenta',
          ),
          _diabete(em(3, 7), glicose: 110),
        ],
      );

      expect(resumo.temDiabetes, isTrue);
      // A insulina lenta das 22h e so a dose: nao e medicao de glicemia.
      expect(resumo.glicemia.medicoes, 3);
      expect(resumo.glicemia.media, closeTo(157.33, 0.01));
      expect(resumo.glicemia.naFaixa, 1);
      expect(resumo.diasComHipoglicemia, [1]);
      expect(resumo.diasComGlicemiaMuitoAlta, [2]);
      expect(resumo.insulinaTotal, 20);
      expect(resumo.diasComInsulina, 2);
      // 4 medicoes por dia nos 5 dias encerrados; 4 feitas no total.
      expect(resumo.medicoesPrevistas, 20);
      expect(resumo.medicoesFeitas, 3);
    });

    test('Não deve ter bloco de diabetes no mês de quem não tem diabetes', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 6),
      );

      expect(resumo.temDiabetes, isFalse);
      expect(resumo.glicemia.medicoes, 0);
    });

    test('Deve marcar como dia de alerta grave a emergência, a hipoglicemia e a glicemia muito alta', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(diabetes: true),
        mes: novembro,
        hoje: DateTime(2026, 11, 8),
        diabete: [
          _diabete(em(2, 7), glicose: 55), // hipoglicemia
          _diabete(em(3, 7), glicose: 300), // muito alta
          _diabete(em(4, 7), glicose: 200), // alta, mas nao e alerta grave
        ],
        alertas: [
          _alerta(Alerta.tipoEmergencia, em(5, 15)),
          _alerta(Alerta.tipoAtencao, em(6, 10)), // so um aviso
        ],
      );

      expect(resumo.diasComAlertaGrave, [2, 3, 5]);
    });

    test('Deve contar os alertas do mês e os dias em que aconteceram', () {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: _paciente(),
        mes: novembro,
        hoje: DateTime(2026, 11, 8),
        alertas: [
          _alerta(Alerta.tipoEmergencia, em(2, 15)),
          _alerta(Alerta.tipoAtencao, em(4, 10)),
          _alerta(Alerta.tipoAtencao, em(4, 16)),
          _alerta(Alerta.tipoEmergencia, em(6, 3)),
        ],
      );

      expect(resumo.emergencias, 2);
      expect(resumo.avisos, 2);
      expect(resumo.diasComEmergencia, [2, 6]);
      expect(resumo.diasComAviso, [4]);
    });
  });
}
