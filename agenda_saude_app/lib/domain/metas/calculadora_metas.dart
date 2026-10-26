import 'dart:math' as math;

import '../../core/constants/meta_hidratacao.dart';
import '../models/paciente.dart';
import 'metas_personalizadas.dart';

// Niveis de atividade da triagem (mesmos rotulos da tela). O fator multiplica
// a taxa metabolica basal para estimar o gasto energetico total (valores
// classicos de Harris-Benedict/FAO). A meta de passos e progressiva: o
// sedentario comeca num patamar alcancavel e sobe ao mudar de nivel.
enum _NivelAtividade {
  sedentario('Sedentário', 1.2, 5000, 4000),
  leve('Leve', 1.375, 7000, 5000),
  moderado('Moderado', 1.55, 8000, 6000),
  intenso('Intenso', 1.725, 10000, 8000);

  final String rotulo;
  final double fator;
  final int passosAdulto;
  final int passosIdoso;

  const _NivelAtividade(
    this.rotulo,
    this.fator,
    this.passosAdulto,
    this.passosIdoso,
  );

  static _NivelAtividade? deRotulo(String? rotulo) {
    for (final nivel in values) {
      if (nivel.rotulo == rotulo) return nivel;
    }
    return null;
  }
}

// Gera as metas diarias a partir dos dados da triagem, so com formulas
// consagradas e deterministicas (sem IA), para o resultado ser auditavel e
// testavel. Referencias:
//  - Energia: Mifflin-St Jeor (1990), recomendada pela Academy of Nutrition
//    and Dietetics, x fator de atividade.
//  - IMC: OMS para adultos; Lipschitz (1994) para idosos >= 60 anos, que e o
//    criterio do SISVAN/Ministerio da Saude.
//  - Macronutrientes: faixas AMDR (IOM) e da Sociedade Brasileira de Diabetes
//    (carboidratos 45-60%, proteinas 15-20%, lipidios 20-35%); proteina de
//    1,0 g/kg (adultos) e 1,2 g/kg (idosos, PROT-AGE/ESPEN).
//  - Fibras: 14 g/1000 kcal (IOM), minimo de 25 g/dia (OMS).
//  - Sodio < 2000 mg/dia e acucar livre < 10% das kcal (OMS; 5% para
//    diabeticos); gordura saturada < 10% das kcal (< 7% para cardiopatas,
//    conforme a diretriz da SBC/AHA).
//  - Agua: 35 ml/kg (adultos) e 30 ml/kg (idosos), entre 1,5 e 3,5 L.
//  - Atividade: 150 min/semana de aerobico moderado (OMS 2020).
//  - Passos: patamares de reducao de mortalidade em Paluch et al. (2022):
//    6-8 mil para >= 60 anos e 8-10 mil para os mais novos.
//  - Sono: National Sleep Foundation, 7-9 h (7-8 h para idosos).
class CalculadoraMetas {
  CalculadoraMetas._();

  static const int idadeMinima = 18;
  static const int idadeMaxima = 120;
  static const int idadeIdoso = 60;

  // Pisos calorico minimos sem supervisao profissional.
  static const int caloriasMinimasMulher = 1200;
  static const int caloriasMinimasHomem = 1500;

  // Devolve null quando faltam dados da triagem (contas anteriores aos campos
  // fisicos) ou eles sao implausiveis; quem chama deve cair nos valores
  // padrao. A restricao de liquido do medico (`paciente.limiteLiquidoMl`,
  // ex.: insuficiencia cardiaca) limita a meta de hidratacao.
  static MetasPersonalizadas? calcular(Paciente paciente, {DateTime? hoje}) {
    final nascimento = paciente.dataNascimento;
    final peso = paciente.pesoKg;
    final altura = paciente.alturaCm;
    final nivel = _NivelAtividade.deRotulo(paciente.nivelAtividadeFisica);
    final masculino = paciente.sexoBiologico == 'Masculino';
    final feminino = paciente.sexoBiologico == 'Feminino';

    if (nascimento == null || peso == null || altura == null || nivel == null) {
      return null;
    }
    if (!masculino && !feminino) return null;
    if (altura < 100 || altura > 250 || peso < 30 || peso > 400) return null;

    final idade = idadeEm(nascimento, hoje ?? DateTime.now());
    if (idade < idadeMinima || idade > idadeMaxima) return null;

    final idoso = idade >= idadeIdoso;
    final alturaM = altura / 100;
    final imc = peso / (alturaM * alturaM);
    final classificacao = classificarImc(imc, idoso: idoso);

    // Energia
    final taxaMetabolicaBasal =
        10 * peso + 6.25 * altura - 5 * idade + (masculino ? 5 : -161);
    final gastoTotal = taxaMetabolicaBasal * nivel.fator;
    final piso = masculino ? caloriasMinimasHomem : caloriasMinimasMulher;
    final calorias = math.max(
      piso,
      _arredondar(gastoTotal * _fatorAjustePeso(classificacao, idoso), 10),
    );

    // Macronutrientes: proteina pelo peso (mantida entre 15% e 25% das kcal),
    // gordura em 30% e carboidrato com o restante (45-55%).
    final proteinaKcal = (peso * (idoso ? 1.2 : 1.0) * 4)
        .clamp(calorias * 0.15, calorias * 0.25)
        .toDouble();
    final gorduraKcal = calorias * 0.30;
    final carboidratoKcal = calorias - proteinaKcal - gorduraKcal;

    final fracaoSaturada = paciente.possuiCardiopatia ? 0.07 : 0.10;
    final fracaoAcucar = paciente.possuiDiabetes ? 0.05 : 0.10;

    return MetasPersonalizadas(
      imc: imc,
      classificacaoImc: classificacao,
      hidratacaoMl: _hidratacaoMl(peso, idoso, paciente.limiteLiquidoMl),
      sonoMinHoras: 7,
      sonoMaxHoras: idoso ? 8 : 9,
      passos: idoso ? nivel.passosIdoso : nivel.passosAdulto,
      exercicioMinutosSemana: 150,
      calorias: calorias,
      carboidratosG: (carboidratoKcal / 4).round(),
      proteinasG: (proteinaKcal / 4).round(),
      gordurasG: (gorduraKcal / 9).round(),
      fibrasG: math.max(25, (14 * calorias / 1000).round()),
      gorduraSaturadaMaxG: (calorias * fracaoSaturada / 9).round(),
      acucarLivreMaxG: (calorias * fracaoAcucar / 4).round(),
      sodioMaxMg: 2000,
    );
  }

  static int idadeEm(DateTime nascimento, DateTime hoje) {
    final jaFezAniversario =
        hoje.month > nascimento.month ||
        (hoje.month == nascimento.month && hoje.day >= nascimento.day);
    return hoje.year - nascimento.year - (jaFezAniversario ? 0 : 1);
  }

  static ClassificacaoImc classificarImc(double imc, {required bool idoso}) {
    if (idoso) {
      if (imc < 22) return ClassificacaoImc.baixoPeso;
      if (imc <= 27) return ClassificacaoImc.adequado;
      return ClassificacaoImc.sobrepeso;
    }
    if (imc < 18.5) return ClassificacaoImc.baixoPeso;
    if (imc < 25) return ClassificacaoImc.adequado;
    if (imc < 30) return ClassificacaoImc.sobrepeso;
    return ClassificacaoImc.obesidade;
  }

  // Deficit moderado para sobrepeso/obesidade (menor em idosos, para nao
  // perder massa muscular) e superavit leve para baixo peso.
  static double _fatorAjustePeso(ClassificacaoImc classificacao, bool idoso) {
    return switch (classificacao) {
      ClassificacaoImc.baixoPeso => 1.10,
      ClassificacaoImc.adequado => 1.0,
      ClassificacaoImc.sobrepeso => idoso ? 0.90 : 0.85,
      ClassificacaoImc.obesidade => 0.85,
    };
  }

  // Arredondada para copos inteiros, porque a tela de hidratacao conta copos.
  static int _hidratacaoMl(double peso, bool idoso, int? limiteLiquidoMl) {
    final bruto = (peso * (idoso ? 30 : 35)).clamp(1500, 3500).toDouble();
    var copos = (bruto / MetaHidratacao.mlPorCopo).round();
    if (limiteLiquidoMl != null) {
      copos = math.max(
        1,
        math.min(copos, limiteLiquidoMl ~/ MetaHidratacao.mlPorCopo),
      );
    }
    return copos * MetaHidratacao.mlPorCopo;
  }

  static int _arredondar(double valor, int multiplo) =>
      (valor / multiplo).round() * multiplo;
}
