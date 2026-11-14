import '../../domain/metas/metas_personalizadas.dart';
import '../shared/texto_narrado.dart';

// O que o narrador le em "Minhas metas" ("Ouvir esta tela", RF 08.2): as metas
// que o paciente acompanha no dia a dia (agua, passos, calorias, sono e
// exercicio) e para onde ir para muda-las. Os gramas de cada nutriente, os
// limites e o IMC ficam so na tela: uma lista de numeros, ouvida, cansa e nao
// fica na memoria.
//
// [primeiraVez] e a tela logo depois da triagem, quando ainda nao ha menu e o
// botao de baixo e "Aceitar e continuar" (ou "Continuar", sem metas).
String narrarMetas({
  required MetasPersonalizadas? metas,
  int? limiteLiquidoMl,
  bool primeiraVez = false,
}) {
  if (metas == null) {
    return montarTextoNarrado([
      'Ainda não foi possível calcular suas metas',
      primeiraVez
          ? 'Para seguir, toque em Continuar, embaixo'
          : 'Complete os seus dados: no menu, toque no seu nome',
    ]);
  }

  return montarTextoNarrado([
    'Suas metas por dia',
    'Beber ${contar(metas.hidratacaoCopos, 'copo', 'copos')} de água',
    if (limiteLiquidoMl != null)
      'Isso respeita o limite de água que o seu médico definiu',
    'Andar ${metas.passos} passos',
    'Comer cerca de ${metas.calorias} calorias',
    'Dormir de ${metas.sonoMinHoras} a ${metas.sonoMaxHoras} horas por noite',
    'E fazer ${metas.exercicioMinutosSemana} minutos de exercício por semana',
    'São sugestões, que não substituem a orientação do seu médico ou '
        'nutricionista',
    if (primeiraVez)
      'Para seguir, toque em Aceitar e continuar, embaixo'
    else ...[
      'Para mudar água, passos ou exercício, use Personalizar rotina, no menu',
      'Para atualizar o seu peso, toque no seu nome, no alto do menu',
    ],
  ]);
}
