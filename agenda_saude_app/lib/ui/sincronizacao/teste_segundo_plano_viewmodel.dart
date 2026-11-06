import 'package:flutter/foundation.dart';

import '../../core/services/health_service.dart';
import '../../core/services/leitura_segundo_plano_service.dart';

// Estado do cartao do teste B2 (RF04.2) na tela "Meu smartwatch": se o
// Health Connect deste aparelho oferece a leitura com o app fechado, se a
// permissao foi concedida e se a leitura a cada 15 minutos esta ligada.
class TesteSegundoPlanoViewModel extends ChangeNotifier {
  final HealthService _healthService;
  final LeituraSegundoPlanoService _leituraSegundoPlano;

  TesteSegundoPlanoViewModel({
    HealthService? healthService,
    LeituraSegundoPlanoService? leituraSegundoPlano,
  })  : _healthService = healthService ?? HealthServiceImpl(),
        _leituraSegundoPlano =
            leituraSegundoPlano ?? LeituraSegundoPlanoServiceImpl();

  bool _verificando = true;
  bool get verificando => _verificando;

  // Null enquanto nao verificado (ou se a verificacao falhou).
  bool? _disponivel;
  bool? get disponivel => _disponivel;

  bool? _permissaoConcedida;
  bool? get permissaoConcedida => _permissaoConcedida;

  bool? _ligado;
  bool? get ligado => _ligado;

  // Resultado da ultima acao, para o teste anotar.
  String? _mensagem;
  String? get mensagem => _mensagem;

  bool _descartado = false;

  Future<void> verificar() async {
    _verificando = true;
    notifyListeners();
    try {
      _disponivel = await _healthService.leituraEmSegundoPlanoDisponivel();
      _permissaoConcedida = await _healthService.temPermissaoSegundoPlano();
      _ligado = await _leituraSegundoPlano.estaLigada();
      _mensagem = null;
    } catch (erro) {
      _mensagem = 'Não foi possível verificar: $erro';
    }
    _verificando = false;
    _notificar();
  }

  Future<void> pedirPermissao() async {
    await _executar(() async {
      _permissaoConcedida =
          await _healthService.solicitarPermissaoSegundoPlano();
      _mensagem = _permissaoConcedida!
          ? 'Permissão concedida.'
          : 'Permissão não concedida.';
    });
  }

  Future<void> ligar() async {
    await _executar(() async {
      await _leituraSegundoPlano.ligar();
      _ligado = true;
      _mensagem = 'Leitura ligada. Feche o app e confira as leituras novas '
          'no card do acompanhante depois de 15 minutos ou mais.';
    });
  }

  Future<void> desligar() async {
    await _executar(() async {
      await _leituraSegundoPlano.desligar();
      _ligado = false;
      _mensagem = 'Leitura com o app fechado desligada.';
    });
  }

  Future<void> lerUmaVezAgora() async {
    await _executar(() async {
      await _leituraSegundoPlano.lerUmaVezAgora();
      _mensagem = 'Leitura em segundo plano agendada. O resultado aparece no '
          'log ("BPM em segundo plano").';
    });
  }

  Future<void> _executar(Future<void> Function() acao) async {
    try {
      await acao();
    } catch (erro) {
      _mensagem = 'Falhou: $erro';
    }
    _notificar();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
