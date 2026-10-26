import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/metas/calculadora_metas.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';

final hoje = DateTime(2026, 10, 25);

Paciente criarPaciente({
  DateTime? nascimento,
  String? sexo = 'Masculino',
  double? peso = 80,
  double? altura = 180,
  String? nivel = 'Moderado',
  bool diabetes = false,
  bool cardiopatia = false,
  int? limiteLiquidoMl,
}) {
  return Paciente(
    id: 'p1',
    nome: 'Paciente Teste',
    email: 'teste@email.com',
    perfil: 'Paciente',
    possuiDiabetes: diabetes,
    possuiCardiopatia: cardiopatia,
    codigoVinculo: 'ABC123',
    triagemConcluida: true,
    dataNascimento: nascimento ?? DateTime(1996, 1, 10),
    sexoBiologico: sexo,
    alturaCm: altura,
    pesoKg: peso,
    nivelAtividadeFisica: nivel,
    limiteLiquidoMl: limiteLiquidoMl,
  );
}

MetasPersonalizadas calcular(Paciente paciente) {
  final metas = CalculadoraMetas.calcular(paciente, hoje: hoje);
  expect(metas, isNotNull);
  return metas!;
}

void main() {
  group('CalculadoraMetas Testes', () {
    test(
      'Deve calcular as metas de um homem adulto ativo (Mifflin-St Jeor)',
      () {
        // TMB = 10*80 + 6,25*180 - 5*30 + 5 = 1780; x 1,55 = 2759 -> 2760 kcal
        final metas = calcular(criarPaciente());

        expect(metas.imc, closeTo(24.69, 0.01));
        expect(metas.classificacaoImc, ClassificacaoImc.adequado);
        expect(metas.calorias, 2760);
        // 80 kg x 1,0 g/kg seria so 11,6% das kcal; sobe para o piso de 15%.
        expect(metas.proteinasG, closeTo(104, 1));
        expect(metas.gordurasG, closeTo(92, 1));
        expect(metas.carboidratosG, closeTo(380, 1));
        expect(metas.fibrasG, 39);
        expect(metas.gorduraSaturadaMaxG, 31);
        expect(metas.acucarLivreMaxG, 69);
        expect(metas.sodioMaxMg, 2000);
        expect(metas.hidratacaoMl, 2750); // 80 kg x 35 ml = 2800 -> 11 copos
        expect(metas.hidratacaoCopos, 11);
        expect(metas.passos, 8000);
        expect(metas.exercicioMinutosSemana, 150);
        expect(metas.sonoMinHoras, 7);
        expect(metas.sonoMaxHoras, 9);
      },
    );

    test('Deve calcular as metas de uma idosa sedentaria', () {
      // TMB = 600 + 968,75 - 350 - 161 = 1057,75; x 1,2 = 1269,3 -> 1270 kcal
      final metas = calcular(
        criarPaciente(
          nascimento: DateTime(1956, 3, 1),
          sexo: 'Feminino',
          peso: 60,
          altura: 155,
          nivel: 'Sedentário',
        ),
      );

      expect(metas.classificacaoImc, ClassificacaoImc.adequado);
      expect(metas.calorias, 1270);
      expect(metas.proteinasG, closeTo(72, 1)); // 1,2 g/kg
      expect(metas.gordurasG, closeTo(42, 1));
      expect(metas.carboidratosG, closeTo(150, 1));
      expect(metas.fibrasG, 25); // minimo da OMS
      expect(metas.hidratacaoMl, 1750); // 60 kg x 30 ml = 1800 -> 7 copos
      expect(metas.passos, 4000);
      expect(metas.sonoMaxHoras, 8);
    });

    test(
      'Deve reduzir acucar para diabeticos e gordura saturada para cardiopatas',
      () {
        final base = calcular(
          criarPaciente(
            nascimento: DateTime(1956, 3, 1),
            sexo: 'Feminino',
            peso: 60,
            altura: 155,
            nivel: 'Sedentário',
          ),
        );
        final diabetica = calcular(
          criarPaciente(
            nascimento: DateTime(1956, 3, 1),
            sexo: 'Feminino',
            peso: 60,
            altura: 155,
            nivel: 'Sedentário',
            diabetes: true,
          ),
        );
        final cardiopata = calcular(
          criarPaciente(
            nascimento: DateTime(1956, 3, 1),
            sexo: 'Feminino',
            peso: 60,
            altura: 155,
            nivel: 'Sedentário',
            cardiopatia: true,
          ),
        );

        expect(base.acucarLivreMaxG, 32); // 10% das kcal
        expect(diabetica.acucarLivreMaxG, 16); // 5% das kcal
        expect(base.gorduraSaturadaMaxG, 14); // 10% das kcal
        expect(cardiopata.gorduraSaturadaMaxG, 10); // 7% das kcal
      },
    );

    test('Deve aplicar deficit calorico em adulto com obesidade', () {
      // TMB = 1520,25; x 1,375 = 2090,3; x 0,85 = 1776,8 -> 1780 kcal
      final metas = calcular(
        criarPaciente(
          nascimento: DateTime(1986, 5, 20),
          sexo: 'Feminino',
          peso: 85,
          altura: 165,
          nivel: 'Leve',
        ),
      );

      expect(metas.classificacaoImc, ClassificacaoImc.obesidade);
      expect(metas.calorias, 1780);
    });

    test('Deve aplicar superavit calorico em adulto com baixo peso', () {
      // TMB = 1473,75; x 1,375 = 2026,4; x 1,10 = 2229 -> 2230 kcal
      final metas = calcular(
        criarPaciente(
          nascimento: DateTime(2001, 2, 2),
          peso: 50,
          altura: 175,
          nivel: 'Leve',
        ),
      );

      expect(metas.classificacaoImc, ClassificacaoImc.baixoPeso);
      expect(metas.calorias, 2230);
    });

    test('Deve usar deficit menor em idoso com sobrepeso (Lipschitz)', () {
      // TMB = 1201,5; x 1,2 = 1441,8; x 0,90 = 1297,6 -> 1300 kcal
      final metas = calcular(
        criarPaciente(
          nascimento: DateTime(1961, 1, 1),
          sexo: 'Feminino',
          peso: 70,
          altura: 158,
          nivel: 'Sedentário',
        ),
      );

      expect(metas.classificacaoImc, ClassificacaoImc.sobrepeso);
      expect(metas.calorias, 1300);
    });

    test('Deve respeitar o piso calorico de mulheres e homens', () {
      // Gasto estimado de 1110 kcal, abaixo do piso de 1200.
      final mulher = calcular(
        criarPaciente(
          nascimento: DateTime(1946, 1, 1),
          sexo: 'Feminino',
          peso: 55,
          altura: 150,
          nivel: 'Sedentário',
        ),
      );
      // Gasto estimado de 1410 kcal, abaixo do piso de 1500.
      final homem = calcular(
        criarPaciente(
          nascimento: DateTime(1946, 1, 1),
          peso: 57,
          altura: 160,
          nivel: 'Sedentário',
        ),
      );

      expect(mulher.calorias, CalculadoraMetas.caloriasMinimasMulher);
      expect(homem.calorias, CalculadoraMetas.caloriasMinimasHomem);
    });

    test(
      'Deve manter a distribuicao de macronutrientes coerente com as calorias',
      () {
        final perfis = [
          criarPaciente(),
          criarPaciente(sexo: 'Feminino', peso: 52, altura: 160, nivel: 'Leve'),
          criarPaciente(
            nascimento: DateTime(1950, 4, 4),
            peso: 110,
            altura: 172,
            nivel: 'Sedentário',
            diabetes: true,
          ),
          criarPaciente(
            nascimento: DateTime(1940, 9, 9),
            sexo: 'Feminino',
            peso: 48,
            altura: 150,
            nivel: 'Leve',
            cardiopatia: true,
          ),
        ];

        for (final paciente in perfis) {
          final metas = calcular(paciente);
          final somaKcal =
              metas.carboidratosG * 4 +
              metas.proteinasG * 4 +
              metas.gordurasG * 9;
          final fracaoProteina = metas.proteinasG * 4 / metas.calorias;
          final fracaoCarbo = metas.carboidratosG * 4 / metas.calorias;

          expect(somaKcal, closeTo(metas.calorias, 10));
          expect(fracaoProteina, inInclusiveRange(0.14, 0.26));
          expect(fracaoCarbo, inInclusiveRange(0.44, 0.56));
        }
      },
    );

    test('Deve mudar de faixa etaria exatamente no aniversario de 60 anos', () {
      final nascimento = DateTime(1966, 6, 15);
      final paciente = criarPaciente(nascimento: nascimento);

      final aos59 = CalculadoraMetas.calcular(
        paciente,
        hoje: DateTime(2026, 6, 14),
      )!;
      final aos60 = CalculadoraMetas.calcular(
        paciente,
        hoje: DateTime(2026, 6, 15),
      )!;

      expect(CalculadoraMetas.idadeEm(nascimento, DateTime(2026, 6, 14)), 59);
      expect(CalculadoraMetas.idadeEm(nascimento, DateTime(2026, 6, 15)), 60);
      expect(aos59.passos, 8000);
      expect(aos60.passos, 6000);
      expect(aos59.sonoMaxHoras, 9);
      expect(aos60.sonoMaxHoras, 8);
    });

    test('Deve limitar a hidratacao entre 1,5 e 3,5 litros', () {
      final pesado = calcular(criarPaciente(peso: 120, altura: 180)); // 4200 ml
      final leve = calcular(criarPaciente(peso: 40, altura: 170)); // 1400 ml

      expect(pesado.hidratacaoMl, 3500);
      expect(leve.hidratacaoMl, 1500);
    });

    test('Deve respeitar a restricao de liquido definida pelo medico', () {
      // Sem restricao a meta seria de 2750 ml.
      int comLimite(int limiteMl) =>
          calcular(criarPaciente(limiteLiquidoMl: limiteMl)).hidratacaoMl;

      expect(comLimite(5000), 2750);
      expect(comLimite(1500), 1500);
      // 1600 ml nao fecha copos de 250 ml: arredonda para baixo.
      expect(comLimite(1600), 1500);
      expect(comLimite(100), 250);
    });

    test('Deve classificar o IMC de adultos pelos limites da OMS', () {
      ClassificacaoImc adulto(double imc) =>
          CalculadoraMetas.classificarImc(imc, idoso: false);

      expect(adulto(18.4), ClassificacaoImc.baixoPeso);
      expect(adulto(18.5), ClassificacaoImc.adequado);
      expect(adulto(24.9), ClassificacaoImc.adequado);
      expect(adulto(25), ClassificacaoImc.sobrepeso);
      expect(adulto(29.9), ClassificacaoImc.sobrepeso);
      expect(adulto(30), ClassificacaoImc.obesidade);
    });

    test('Deve classificar o IMC de idosos pelos limites de Lipschitz', () {
      ClassificacaoImc idoso(double imc) =>
          CalculadoraMetas.classificarImc(imc, idoso: true);

      expect(idoso(21.9), ClassificacaoImc.baixoPeso);
      expect(idoso(22), ClassificacaoImc.adequado);
      expect(idoso(27), ClassificacaoImc.adequado);
      expect(idoso(27.1), ClassificacaoImc.sobrepeso);
      expect(idoso(35), ClassificacaoImc.sobrepeso);
    });

    test('Deve devolver null quando faltam dados da triagem', () {
      final casos = {
        'sem peso': criarPaciente(peso: null),
        'sem altura': criarPaciente(altura: null),
        'sem sexo': criarPaciente(sexo: null),
        'sem nivel de atividade': criarPaciente(nivel: null),
      };

      for (final caso in casos.entries) {
        expect(
          CalculadoraMetas.calcular(caso.value, hoje: hoje),
          isNull,
          reason: caso.key,
        );
      }

      final semNascimento = Paciente(
        id: 'p2',
        nome: 'Sem Nascimento',
        email: 'a@b.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        sexoBiologico: 'Masculino',
        alturaCm: 180,
        pesoKg: 80,
        nivelAtividadeFisica: 'Moderado',
      );
      expect(CalculadoraMetas.calcular(semNascimento, hoje: hoje), isNull);
    });

    test('Deve devolver null para valores desconhecidos ou implausiveis', () {
      final casos = {
        'sexo desconhecido': criarPaciente(sexo: 'Outro'),
        'nivel desconhecido': criarPaciente(nivel: 'Atleta'),
        'menor de 18 anos': criarPaciente(nascimento: DateTime(2015, 1, 1)),
        'idade acima de 120': criarPaciente(nascimento: DateTime(1890, 1, 1)),
        'altura implausivel': criarPaciente(altura: 90),
        'peso implausivel': criarPaciente(peso: 20),
      };

      for (final caso in casos.entries) {
        expect(
          CalculadoraMetas.calcular(caso.value, hoje: hoje),
          isNull,
          reason: caso.key,
        );
      }
    });
  });
}
