import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/alimentos_repository.dart';
import '../../data/repositories/dados_repository.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/alimentos/nutrientes.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/refeicao_planejada.dart';
import '../../domain/models/registro_refeicao.dart';

// Estado do cartao "Refeicoes" da rotina diaria (RF03.4): a lista de refeicoes
// do plano do paciente e quais ele ja marcou como feitas hoje. Marcar grava um
// RegistroRefeicao no Firestore; desmarcar apaga. O paciente nao descreve o
// que comeu a cada vez - so confirma que fez a refeicao, e os nutrientes do dia
// saem dos alimentos que ele cadastrou em cada refeicao. O acompanhante, que
// le a mesma colecao, ve o mesmo progresso.
class RefeicoesViewModel extends ChangeNotifier {
  // Maximo de refeicoes no plano: cobre as 6 do plano padrao de diabeticos
  // com alguma folga, sem a lista virar um problema na tela.
  static const int maximoRefeicoes = 8;

  final DadosMedicosRepository _dadosRepository;
  // Criado so ao gravar: ver o plano nao depende do Firestore.
  PacienteRepository? _pacienteRepositoryInjetado;
  PacienteRepository get _pacienteRepository =>
      _pacienteRepositoryInjetado ??= PacienteRepository();
  final AlimentosRepository _alimentosRepository;
  final ValueChanged<Paciente>? _aoAtualizarPaciente;
  final DateTime Function() _agora;

  Paciente _paciente;
  StreamSubscription<List<RegistroRefeicao>>? _assinatura;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  RefeicoesViewModel({
    required Paciente paciente,
    DadosMedicosRepository? dadosRepository,
    PacienteRepository? pacienteRepository,
    AlimentosRepository? alimentosRepository,
    ValueChanged<Paciente>? aoAtualizarPaciente,
    DateTime Function()? agora,
  }) : _paciente = paciente,
       _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
       _pacienteRepositoryInjetado = pacienteRepository,
       _alimentosRepository =
           alimentosRepository ?? AlimentosRepository.compartilhado,
       _aoAtualizarPaciente = aoAtualizarPaciente,
       _agora = agora ?? DateTime.now {
    _observarDia();
    _carregarCatalogo();
  }

  Paciente get paciente => _paciente;

  List<RefeicaoPlanejada> get refeicoes => _paciente.planoDeRefeicoes;

  // Metas do paciente, para comparar com o que as refeicoes fornecem.
  MetasPersonalizadas? get metas => _paciente.metas;

  // Catalogo de alimentos; null ate terminar de carregar (ou se falhar).
  CatalogoAlimentos? _catalogo;
  CatalogoAlimentos? get catalogo => _catalogo;

  bool _catalogoComErro = false;
  bool get catalogoComErro => _catalogoComErro;

  // Do mais recente para o mais antigo.
  List<RegistroRefeicao> _registros = const [];

  // Verdadeiro ate o Firestore entregar a primeira lista do dia.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura do dia falhou (ex.: sem permissao ou indice faltando): o que
  // esta marcado nao e confiavel, entao a tela esconde as marcacoes.
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  // Falha ao marcar/desmarcar; some na proxima tentativa.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  bool estaFeita(RefeicaoPlanejada refeicao) =>
      _registros.any((registro) => registro.refeicaoId == refeicao.id);

  int get feitas => refeicoes.where(estaFeita).length;

  int get total => refeicoes.length;

  bool get todasFeitas => total > 0 && feitas == total;

  // De 0 a 1.
  double get progresso => total == 0 ? 0 : feitas / total;

  // Alguma refeicao do plano ja tem alimentos cadastrados.
  bool get temAlimentos =>
      refeicoes.any((refeicao) => refeicao.itens.isNotEmpty);

  Nutrientes nutrientesDa(RefeicaoPlanejada refeicao) {
    final catalogo = _catalogo;
    return catalogo == null ? Nutrientes.zero : refeicao.nutrientes(catalogo);
  }

  // Tudo o que o plano de refeicoes fornece em um dia.
  Nutrientes get nutrientesPlanejados =>
      Nutrientes.somar(refeicoes.map(nutrientesDa));

  // O que o paciente ja comeu hoje: so as refeicoes que marcou como feitas.
  Nutrientes get nutrientesConsumidos =>
      Nutrientes.somar(refeicoes.where(estaFeita).map(nutrientesDa));

  // Marca a refeicao como feita ou, se ja estava, desmarca.
  Future<void> alternar(RefeicaoPlanejada refeicao) async {
    _mensagemErro = null;
    try {
      if (estaFeita(refeicao)) {
        final ids = _registros
            .where((registro) => registro.refeicaoId == refeicao.id)
            .map((registro) => registro.id)
            .toList();
        for (final id in ids) {
          await _dadosRepository.removerRegistro(id);
        }
      } else {
        await _dadosRepository.salvarRegistro(
          RegistroRefeicao(
            id: '',
            pacienteId: _paciente.id,
            dataHora: _agora(),
            refeicaoId: refeicao.id,
            nome: refeicao.nome,
          ),
        );
      }
    } catch (erro) {
      debugPrint('Falha ao marcar a refeicao ${refeicao.nome}: $erro');
      _mensagemErro = 'Não foi possível salvar. Tente de novo.';
      notifyListeners();
    }
  }

  // Grava o plano personalizado e passa a mostra-lo. Devolve false se a
  // gravacao falhar (o plano em tela continua o antigo).
  Future<bool> salvarPlano(List<RefeicaoPlanejada> novoPlano) async {
    try {
      await _pacienteRepository.salvarRefeicoes(_paciente.id, novoPlano);
    } catch (erro) {
      debugPrint('Falha ao salvar o plano de refeicoes: $erro');
      return false;
    }
    _paciente = _paciente.copyWith(refeicoes: novoPlano);
    _aoAtualizarPaciente?.call(_paciente);
    notifyListeners();
    return true;
  }

  Future<void> _carregarCatalogo() async {
    try {
      _catalogo = await _alimentosRepository.carregar();
      _catalogoComErro = false;
    } catch (erro) {
      debugPrint('Falha ao carregar o catalogo de alimentos: $erro');
      _catalogoComErro = true;
    }
    if (!_descartado) notifyListeners();
  }

  // Passa a acompanhar o dia atual e agenda a virada para o proximo, para as
  // marcacoes zerarem a meia-noite mesmo com a tela aberta.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinatura?.cancel();
    _assinatura = _dadosRepository
        .streamRefeicoesDoDia(_paciente.id, _dia)
        .listen(
          (registros) {
            _registros = registros;
            _carregando = false;
            _erroDeLeitura = false;
            notifyListeners();
          },
          onError: (Object erro) {
            debugPrint('Stream de refeicoes falhou: $erro');
            _carregando = false;
            _erroDeLeitura = true;
            notifyListeners();
          },
        );

    _timerViradaDoDia?.cancel();
    final meiaNoite = DateTime(_dia.year, _dia.month, _dia.day + 1);
    _timerViradaDoDia = Timer(meiaNoite.difference(agora), _aoVirarODia);
  }

  void _aoVirarODia() {
    _registros = const [];
    _carregando = true;
    _observarDia();
    notifyListeners();
  }

  bool _descartado = false;

  @override
  void dispose() {
    _descartado = true;
    _assinatura?.cancel();
    _timerViradaDoDia?.cancel();
    super.dispose();
  }
}
