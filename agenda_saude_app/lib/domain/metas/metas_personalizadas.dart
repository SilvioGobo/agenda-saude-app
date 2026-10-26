import '../../core/constants/meta_hidratacao.dart';

enum ClassificacaoImc { baixoPeso, adequado, sobrepeso, obesidade }

// Metas e limites diarios sugeridos para um paciente, calculados por
// [CalculadoraMetas] a partir da triagem (RF02). Sao sugestoes: nao
// substituem a orientacao de medico ou nutricionista.
//
// Ficam gravadas em `usuarios/{uid}.metas`: assim o acompanhante enxerga as
// mesmas metas e uma correcao de formula numa versao futura do app nao muda a
// meta de ninguem sem aviso.
class MetasPersonalizadas {
  final double imc;
  final ClassificacaoImc classificacaoImc;

  // Rotina diaria (RF03)
  final int hidratacaoMl;
  final int sonoMinHoras;
  final int sonoMaxHoras;
  final int passos;
  final int exercicioMinutosSemana;

  // Alimentacao: metas de energia e macronutrientes
  final int calorias;
  final int carboidratosG;
  final int proteinasG;
  final int gordurasG;
  final int fibrasG;

  // Alimentacao: limites maximos (relevantes para diabeticos e cardiopatas)
  final int gorduraSaturadaMaxG;
  final int acucarLivreMaxG;
  final int sodioMaxMg;

  // Verdadeiro quando o paciente mudou alguma meta da rotina a mao. Serve para
  // avisar antes de um novo calculo substituir o que ele escolheu.
  final bool ajustadaManualmente;

  const MetasPersonalizadas({
    required this.imc,
    required this.classificacaoImc,
    required this.hidratacaoMl,
    required this.sonoMinHoras,
    required this.sonoMaxHoras,
    required this.passos,
    required this.exercicioMinutosSemana,
    required this.calorias,
    required this.carboidratosG,
    required this.proteinasG,
    required this.gordurasG,
    required this.fibrasG,
    required this.gorduraSaturadaMaxG,
    required this.acucarLivreMaxG,
    required this.sodioMaxMg,
    this.ajustadaManualmente = false,
  });

  // A tela de hidratacao conta em copos de 250 ml (Figura 14 do TCC).
  int get hidratacaoCopos => hidratacaoMl ~/ MetaHidratacao.mlPorCopo;

  // Metas da rotina que o paciente pode mudar. As nutricionais ficam de fora
  // de proposito: dependem de orientacao profissional.
  MetasPersonalizadas comAjustes({
    int? hidratacaoMl,
    int? passos,
    int? exercicioMinutosSemana,
  }) {
    return MetasPersonalizadas(
      imc: imc,
      classificacaoImc: classificacaoImc,
      hidratacaoMl: hidratacaoMl ?? this.hidratacaoMl,
      sonoMinHoras: sonoMinHoras,
      sonoMaxHoras: sonoMaxHoras,
      passos: passos ?? this.passos,
      exercicioMinutosSemana:
          exercicioMinutosSemana ?? this.exercicioMinutosSemana,
      calorias: calorias,
      carboidratosG: carboidratosG,
      proteinasG: proteinasG,
      gordurasG: gordurasG,
      fibrasG: fibrasG,
      gorduraSaturadaMaxG: gorduraSaturadaMaxG,
      acucarLivreMaxG: acucarLivreMaxG,
      sodioMaxMg: sodioMaxMg,
      ajustadaManualmente: true,
    );
  }

  factory MetasPersonalizadas.fromJson(Map<String, dynamic> json) {
    int inteiro(String chave, [int padrao = 0]) =>
        (json[chave] as num?)?.toInt() ?? padrao;

    return MetasPersonalizadas(
      imc: (json['imc'] as num?)?.toDouble() ?? 0,
      classificacaoImc: ClassificacaoImc.values.firstWhere(
        (classificacao) => classificacao.name == json['classificacaoImc'],
        orElse: () => ClassificacaoImc.adequado,
      ),
      hidratacaoMl: inteiro('hidratacaoMl', MetaHidratacao.mlDiaria),
      sonoMinHoras: inteiro('sonoMinHoras', 7),
      sonoMaxHoras: inteiro('sonoMaxHoras', 9),
      passos: inteiro('passos'),
      exercicioMinutosSemana: inteiro('exercicioMinutosSemana'),
      calorias: inteiro('calorias'),
      carboidratosG: inteiro('carboidratosG'),
      proteinasG: inteiro('proteinasG'),
      gordurasG: inteiro('gordurasG'),
      fibrasG: inteiro('fibrasG'),
      gorduraSaturadaMaxG: inteiro('gorduraSaturadaMaxG'),
      acucarLivreMaxG: inteiro('acucarLivreMaxG'),
      sodioMaxMg: inteiro('sodioMaxMg'),
      ajustadaManualmente: json['ajustadaManualmente'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imc': imc,
      'classificacaoImc': classificacaoImc.name,
      'hidratacaoMl': hidratacaoMl,
      'sonoMinHoras': sonoMinHoras,
      'sonoMaxHoras': sonoMaxHoras,
      'passos': passos,
      'exercicioMinutosSemana': exercicioMinutosSemana,
      'calorias': calorias,
      'carboidratosG': carboidratosG,
      'proteinasG': proteinasG,
      'gordurasG': gordurasG,
      'fibrasG': fibrasG,
      'gorduraSaturadaMaxG': gorduraSaturadaMaxG,
      'acucarLivreMaxG': acucarLivreMaxG,
      'sodioMaxMg': sodioMaxMg,
      'ajustadaManualmente': ajustadaManualmente,
    };
  }
}
