import 'package:flutter/material.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/theme/app_cores.dart';

// Textos, cores e icones da glicemia e da insulina, compartilhados pelo
// checklist do paciente e pelo card do acompanhante para os dois mostrarem
// o mesmo valor do mesmo jeito.

// "112 mg/dL" - glicemia capilar sempre como numero inteiro.
String formatarGlicemia(double mgDl) => '${mgDl.round()} mg/dL';

// "112 miligramas por decilitro", para o leitor de tela.
String falarGlicemia(double mgDl) =>
    '${mgDl.round()} miligramas por decilitro';

// "6 unidades", "1 unidade", "6,5 unidades" (virgula decimal).
String formatarDose(double unidades) {
  final inteiro = unidades == unidades.roundToDouble();
  final numero = inteiro
      ? unidades.round().toString()
      : unidades.toString().replaceAll('.', ',');
  return '$numero ${unidades == 1 ? 'unidade' : 'unidades'}';
}

// "Insulina rápida: 6 unidades".
String descreverInsulina(String? tipo, double unidades) {
  final nomeTipo = (tipo == null || tipo.isEmpty) ? '' : ' ${tipo.toLowerCase()}';
  return 'Insulina$nomeTipo: ${formatarDose(unidades)}';
}

String descreverClassificacao(ClassificacaoGlicemia classificacao) {
  switch (classificacao) {
    case ClassificacaoGlicemia.muitoBaixa:
      return 'Muito baixa';
    case ClassificacaoGlicemia.baixa:
      return 'Baixa';
    case ClassificacaoGlicemia.naFaixa:
      return 'Na faixa';
    case ClassificacaoGlicemia.alta:
      return 'Alta';
    case ClassificacaoGlicemia.muitoAlta:
      return 'Muito alta';
  }
}

// Hipoglicemia e glicemia muito alta sao alerta de saude (vermelho); alta e
// aviso (laranja). O texto da classificacao sempre acompanha a cor.
Color corDaClassificacao(ClassificacaoGlicemia classificacao) {
  switch (classificacao) {
    case ClassificacaoGlicemia.naFaixa:
      return AppCores.sucesso;
    case ClassificacaoGlicemia.alta:
      return AppCores.aviso;
    case ClassificacaoGlicemia.muitoBaixa:
    case ClassificacaoGlicemia.baixa:
    case ClassificacaoGlicemia.muitoAlta:
      return AppCores.perigo;
  }
}

IconData iconeDaClassificacao(ClassificacaoGlicemia classificacao) {
  switch (classificacao) {
    case ClassificacaoGlicemia.muitoBaixa:
    case ClassificacaoGlicemia.baixa:
      return Icons.arrow_downward_rounded;
    case ClassificacaoGlicemia.naFaixa:
      return Icons.check_circle_rounded;
    case ClassificacaoGlicemia.alta:
    case ClassificacaoGlicemia.muitoAlta:
      return Icons.arrow_upward_rounded;
  }
}

// "às 07:10".
String descreverHora(DateTime dataHora) {
  String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
  return 'às ${doisDigitos(dataHora.hour)}:${doisDigitos(dataHora.minute)}';
}
