import '../shared/texto_narrado.dart';
import 'paciente_viewmodel.dart' show StatusCardiaco;

// O que o narrador le no painel do paciente ("Ouvir esta tela", RF 08.2): como
// estao os batimentos agora e para onde ele pode ir. Sao so os pontos
// principais do painel - e nao o texto de cada cartao -, para ouvir em poucos
// segundos.
//
// [status] diz o que o painel mostra no lugar de destaque: um BPM estavel, alto
// ou baixo (com [bpm] e [medidoEm]) ou, em `semLeitura`, o aviso que ocupa o
// lugar dele (smartwatch com problema ou ainda sem medicao), cujo texto vem em
// [semLeituraTitulo] e [semLeituraDescricao].
String narrarPainel({
  required String primeiroNome,
  required StatusCardiaco status,
  int? bpm,
  DateTime? medidoEm,
  DateTime? agora,
  String? semLeituraTitulo,
  String? semLeituraDescricao,
}) {
  final relogio = agora ?? DateTime.now();
  final temLeitura = bpm != null &&
      medidoEm != null &&
      status != StatusCardiaco.semLeitura;
  final quando = temLeitura ? falarQuando(medidoEm, relogio) : '';

  const atalhos = 'Nesta tela você pode abrir Minha Rotina, Meus Relatórios ou '
      'Falar com Acompanhante';

  if (!temLeitura) {
    return montarTextoNarrado([
      'Olá, $primeiroNome',
      semLeituraTitulo ?? 'Aguardando medição',
      semLeituraDescricao ??
          'Use o smartwatch no pulso. Seus batimentos aparecem aqui assim que '
              'ele medir',
      atalhos,
    ]);
  }

  if (status == StatusCardiaco.estavel) {
    return montarTextoNarrado([
      'Olá, $primeiroNome',
      'Seus batimentos estão em $bpm por minuto, medidos $quando',
      'Está tudo estável',
      atalhos,
    ]);
  }

  // Alto ou baixo: o alerta vem primeiro e o que fazer fecha o texto; a lista
  // de atalhos ficaria entre o aviso e a ajuda.
  final direcao = status == StatusCardiaco.alto ? 'altos' : 'baixos';
  return montarTextoNarrado([
    'Olá, $primeiroNome',
    'Atenção! Seus batimentos estão $direcao: $bpm por minuto, medidos $quando',
    'Fique em repouso',
    'Se não melhorar ou se sentir mal, fale com seu acompanhante',
    'Para ligar, toque em Falar com Acompanhante',
  ]);
}
