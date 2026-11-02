import '../metas/formato_metas.dart';

// Textos dos relatorios em portugues. O app nao usa o pacote intl, entao os
// nomes de meses e dias da semana ficam aqui.

const List<String> _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

// DateTime.weekday: segunda = 1 ... domingo = 7.
const List<String> _diasDaSemana = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

String capitalizar(String texto) =>
    texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';

String nomeDoMes(int mes) => _meses[mes - 1];

String nomeDoDiaDaSemana(DateTime dia) => _diasDaSemana[dia.weekday - 1];

// "Novembro de 2026"
String tituloDoMes(DateTime mes) =>
    '${capitalizar(nomeDoMes(mes.month))} de ${mes.year}';

// "domingo, 1 de novembro"
String descreverDia(DateTime dia) =>
    '${nomeDoDiaDaSemana(dia)}, ${dia.day} de ${nomeDoMes(dia.month)}';

// "domingo, 1 de novembro de 2026"
String descreverDiaComAno(DateTime dia) =>
    '${descreverDia(dia)} de ${dia.year}';

// "07:10"
String formatarHora(DateTime dataHora) {
  String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
  return '${doisDigitos(dataHora.hour)}:${doisDigitos(dataHora.minute)}';
}

// "1.750 ml"
String formatarMl(int ml) => '${formatarMilhar(ml)} ml';

// 0.823 -> "82%"
String formatarPorcentagem(double fracao) => '${(fracao * 100).round()}%';

// "1 vez", "3 vezes"
String descreverVezes(int quantidade) =>
    quantidade == 1 ? '1 vez' : '$quantidade vezes';

// "dia 4", "dias 4 e 12", "dias 4, 12 e 20"
String listarDias(List<int> dias) {
  if (dias.length == 1) return 'dia ${dias.first}';
  return 'dias ${juntarComE(dias.map((dia) => '$dia').toList())}';
}

// "água", "água e refeições", "água, refeições e glicemia"
String juntarComE(List<String> itens) {
  if (itens.length <= 1) return itens.join();
  return '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';
}

// "José Silva" -> "José"; sem nome, [padrao].
String primeiroNomeDe(String nome, {String padrao = 'o paciente'}) {
  final limpo = nome.trim();
  return limpo.isEmpty ? padrao : limpo.split(RegExp(r'\s+')).first;
}
