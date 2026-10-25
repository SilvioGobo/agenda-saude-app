import 'package:flutter/material.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/theme/app_cores.dart';

// Textos, cores e icones da glicemia e da insulina, compartilhados pelo
// checklist do paciente e pelo card do acompanhante para os dois mostrarem
// o mesmo valor do mesmo jeito.

// Espaco que nao quebra linha e "juncao de palavras" (invisivel): mantem
// numero e unidade juntos na mesma linha, sem "60 mg/" numa linha e "dL" na
// outra.
const String _espacoFixo = '\u00A0';
const String _semQuebra = '\u2060';

// Tira os caracteres de "nao quebrar linha" - para textos do leitor de tela.
String semMarcasDeQuebra(String texto) =>
    texto.replaceAll(_espacoFixo, ' ').replaceAll(_semQuebra, '');

// "112 mg/dL" - glicemia capilar sempre como numero inteiro.
String formatarGlicemia(double mgDl) =>
    '${mgDl.round()}${_espacoFixo}mg/${_semQuebra}dL';

// "112 miligramas por decilitro", para o leitor de tela.
String falarGlicemia(double mgDl) =>
    '${mgDl.round()} miligramas por decilitro';

// "6 unidades", "1 unidade", "6,5 unidades" (virgula decimal).
String formatarDose(double unidades) {
  final inteiro = unidades == unidades.roundToDouble();
  final numero = inteiro
      ? unidades.round().toString()
      : unidades.toString().replaceAll('.', ',');
  return '$numero$_espacoFixo${unidades == 1 ? 'unidade' : 'unidades'}';
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

// Selo da faixa da glicemia ("NA FAIXA", "BAIXA"...): texto em caixa alta,
// icone e fundo na cor da faixa - nunca so a cor.
class SeloFaixaGlicemia extends StatelessWidget {
  final ClassificacaoGlicemia classificacao;

  const SeloFaixaGlicemia(this.classificacao, {super.key});

  @override
  Widget build(BuildContext context) {
    final cor = corDaClassificacao(classificacao);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconeDaClassificacao(classificacao), size: 22, color: cor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              descreverClassificacao(classificacao).toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Erro em caixa alta com icone, anunciado pelo leitor de tela.
class TextoErroDiabete extends StatelessWidget {
  final String texto;

  const TextoErroDiabete(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, color: AppCores.perigo, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.bold,
                color: AppCores.perigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
