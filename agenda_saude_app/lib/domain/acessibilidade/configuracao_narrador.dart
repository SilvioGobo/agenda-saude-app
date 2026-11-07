// Velocidade da fala do narrador (RF 08.3). O paciente escolhe entre poucas
// opcoes, em botoes grandes, em vez de um controle deslizante dificil de acertar.
enum VelocidadeNarracao {
  devagar('Devagar', 0.35),
  normal('Normal', 0.5),
  rapido('Rápido', 0.7);

  // Como aparece na tela.
  final String rotulo;
  // A taxa que o plugin de voz recebe, de 0 a 1: 0,5 e a fala normal (no
  // Android o plugin a dobra, e 0,5 vira a velocidade 1x do sistema).
  final double taxa;

  const VelocidadeNarracao(this.rotulo, this.taxa);

  // A velocidade guardada com este [nome] (`VelocidadeNarracao.name`); um nome
  // desconhecido ou ausente volta ao normal.
  static VelocidadeNarracao porNome(String? nome) {
    for (final velocidade in values) {
      if (velocidade.name == nome) return velocidade;
    }
    return normal;
  }
}

// O que o paciente escolheu para o narrador de voz (RF 07 e RF 08). Vale para o
// aparelho todo: a configuracao "permanece ativa globalmente no aplicativo ate
// que o usuario decida desativa-la". Vem desligado, para ninguem ouvir uma voz
// sem ter pedido.
class ConfiguracaoNarrador {
  final bool ligado;
  final VelocidadeNarracao velocidade;

  const ConfiguracaoNarrador({
    this.ligado = false,
    this.velocidade = VelocidadeNarracao.normal,
  });

  ConfiguracaoNarrador copyWith({bool? ligado, VelocidadeNarracao? velocidade}) {
    return ConfiguracaoNarrador(
      ligado: ligado ?? this.ligado,
      velocidade: velocidade ?? this.velocidade,
    );
  }
}
