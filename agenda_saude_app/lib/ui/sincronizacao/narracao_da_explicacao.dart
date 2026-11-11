import '../shared/texto_narrado.dart';

// O que o narrador le na explicacao "Como funciona?" dos batimentos ("Ouvir
// esta tela", RF 08.2): o caminho das medicoes, o que fazer quando elas nao
// chegam e onde fica o Saude Connect. "Aplicativo" por extenso, que a voz le
// melhor do que "app".
String narrarExplicacaoBatimentos() => montarTextoNarrado([
      'O Agenda Saúde não se liga direto no relógio',
      'O relógio mede os batimentos, o aplicativo do relógio manda as '
          'medições para o Saúde Connect, e o Agenda Saúde lê os batimentos '
          'de lá',
      'Se eles não aparecem, abra o aplicativo do seu relógio, ligue a opção '
          'Saúde Connect e permita a frequência cardíaca',
      'As medições podem levar alguns minutos para chegar',
      'Para achar o Saúde Connect, abra as Configurações do celular e procure '
          'por Saúde Connect',
    ]);
