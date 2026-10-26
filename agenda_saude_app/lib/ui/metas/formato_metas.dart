import '../../domain/metas/metas_personalizadas.dart';

// Formatacao em portugues dos numeros das metas: "2.000" (milhar com ponto)
// e "24,7" (decimal com virgula). O app nao usa o pacote intl.
String formatarMilhar(int valor) {
  final digitos = valor.abs().toString();
  final texto = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) texto.write('.');
    texto.write(digitos[i]);
  }
  return valor < 0 ? '-$texto' : texto.toString();
}

String formatarDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');

String rotuloClassificacaoImc(ClassificacaoImc classificacao) {
  return switch (classificacao) {
    ClassificacaoImc.baixoPeso => 'Abaixo do peso',
    ClassificacaoImc.adequado => 'Peso adequado',
    ClassificacaoImc.sobrepeso => 'Sobrepeso',
    ClassificacaoImc.obesidade => 'Obesidade',
  };
}
