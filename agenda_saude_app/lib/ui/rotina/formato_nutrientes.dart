import '../../domain/alimentos/nutrientes.dart';
import '../metas/formato_metas.dart';

// Textos dos nutrientes em portugues: calorias e gramas sem casas decimais
// (a precisao da TACO nao justifica mais que isso numa refeicao).
String formatarKcal(double kcal) => '${formatarMilhar(kcal.round())} kcal';

String formatarGramas(double gramas) => '${gramas.round()} g';

// "128 kcal · carboidratos 28 g · proteínas 3 g · gorduras 0 g"
String descreverNutrientes(Nutrientes nutrientes) {
  return '${formatarKcal(nutrientes.kcal)} · '
      'carboidratos ${formatarGramas(nutrientes.carboidratoG)} · '
      'proteínas ${formatarGramas(nutrientes.proteinaG)} · '
      'gorduras ${formatarGramas(nutrientes.gorduraG)}';
}

// Quantidade em gramas como o paciente digita: "150" ou "62,5".
String formatarQuantidade(double gramas) {
  return gramas == gramas.roundToDouble()
      ? gramas.round().toString()
      : gramas.toStringAsFixed(1).replaceAll('.', ',');
}
