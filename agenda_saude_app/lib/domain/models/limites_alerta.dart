// Limites de batimentos que o acompanhante define para um paciente (RF 06.1):
// abaixo do minimo ou acima do maximo, o alerta dispara para os dois perfis,
// com o app do paciente aberto ou fechado. Ficam no doc do paciente
// (`usuarios/{uid}.limitesAlerta`); sem eles vale a zona padrao de
// ZonaSegurancaCardiaca (60 a 100 BPM, ou 60 a 90 para cardiopatas).
//
// As security rules deixam o acompanhante vinculado mudar so este campo, e so
// com valores dentro das faixas abaixo (as mesmas de `limitesAlertaValidos`,
// em firestore.rules).
class LimitesAlerta {
  // Faixas aceitas. Fora delas o limite deixaria de proteger (minimo baixo ou
  // maximo alto demais) ou dispararia o tempo todo.
  static const int menorMinimo = 40;
  static const int maiorMinimo = 90;
  static const int menorMaximo = 80;
  static const int maiorMaximo = 150;

  // Distancia minima entre o minimo e o maximo: numa zona estreita qualquer
  // variacao normal do dia (levantar, andar) viraria alerta.
  static const int distanciaMinima = 20;

  final int bpmMinimo;
  final int bpmMaximo;
  // UID do acompanhante que definiu os limites (as rules conferem que e quem
  // esta gravando) e quando, para saber de onde veio a zona do paciente.
  final String atualizadoPor;
  final DateTime? atualizadoEm;

  const LimitesAlerta({
    required this.bpmMinimo,
    required this.bpmMaximo,
    this.atualizadoPor = '',
    this.atualizadoEm,
  });

  // Os dois valores cabem nas faixas aceitas e estao longe o bastante um do
  // outro.
  static bool saoValidos(int minimo, int maximo) =>
      minimo >= menorMinimo &&
      minimo <= maiorMinimo &&
      maximo >= menorMaximo &&
      maximo <= maiorMaximo &&
      maximo - minimo >= distanciaMinima;

  bool get validos => saoValidos(bpmMinimo, bpmMaximo);

  // Do Firestore. Null quando o campo nao existe, nao tem os dois numeros ou
  // traz valores fora das faixas: o paciente fica com a zona padrao.
  static LimitesAlerta? fromJson(Object? json) {
    if (json is! Map) return null;
    final minimo = json['bpmMinimo'];
    final maximo = json['bpmMaximo'];
    if (minimo is! num || maximo is! num) return null;
    final atualizadoEm = json['atualizadoEm'];
    final limites = LimitesAlerta(
      bpmMinimo: minimo.toInt(),
      bpmMaximo: maximo.toInt(),
      atualizadoPor: json['atualizadoPor'] is String
          ? json['atualizadoPor'] as String
          : '',
      // O Firestore devolve um Timestamp, como nos outros models.
      atualizadoEm: atualizadoEm is DateTime ? atualizadoEm : atualizadoEm?.toDate(),
    );
    return limites.validos ? limites : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'bpmMinimo': bpmMinimo,
      'bpmMaximo': bpmMaximo,
      'atualizadoPor': atualizadoPor,
      if (atualizadoEm != null) 'atualizadoEm': atualizadoEm,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is LimitesAlerta &&
      other.bpmMinimo == bpmMinimo &&
      other.bpmMaximo == bpmMaximo &&
      other.atualizadoPor == atualizadoPor &&
      other.atualizadoEm == atualizadoEm;

  @override
  int get hashCode =>
      Object.hash(bpmMinimo, bpmMaximo, atualizadoPor, atualizadoEm);
}
