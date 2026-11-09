import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/acessibilidade/configuracao_narrador.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';

import '../../core/services/fake_tts_service.dart';

// Nao consegue guardar nem ler as preferencias (ex.: armazenamento cheio).
class _PreferenciasQueFalham extends PreferenciasRepository {
  @override
  Future<ConfiguracaoNarrador> narrador() => throw Exception('sem leitura');

  @override
  Future<void> salvarNarradorLigado(bool ligado) =>
      throw Exception('sem espaco');

  @override
  Future<void> salvarVelocidadeDoNarrador(VelocidadeNarracao velocidade) =>
      throw Exception('sem espaco');
}

// A voz do sistema recusa falar; com `soNaPrimeiraVez`, so na primeira tentativa.
class _VozQueFalha extends FakeTtsService {
  final bool soNaPrimeiraVez;
  bool _jaFalhou = false;

  _VozQueFalha({this.soNaPrimeiraVez = false});

  @override
  Future<void> falar(String texto) async {
    if (!soNaPrimeiraVez || !_jaFalhou) {
      _jaFalhou = true;
      throw Exception('motor de voz ausente');
    }
    return super.falar(texto);
  }
}

void main() {
  group('ConfiguracoesViewModel Testes', () {
    late FakeTtsService tts;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tts = FakeTtsService();
    });

    ConfiguracoesViewModel criar({
      PreferenciasRepository? preferencias,
      FakeTtsService? voz,
    }) {
      return ConfiguracoesViewModel(
        preferencias: preferencias ?? PreferenciasRepository(),
        ttsService: voz ?? tts,
      );
    }

    Future<ConfiguracoesViewModel> carregado({FakeTtsService? voz}) async {
      final viewModel = criar(voz: voz);
      await viewModel.carregar();
      return viewModel;
    }

    group('carregar', () {
      test('Deve vir desligado, na velocidade normal', () async {
        final viewModel = criar();
        expect(viewModel.carregando, isTrue);

        await viewModel.carregar();

        expect(viewModel.carregando, isFalse);
        expect(viewModel.narradorLigado, isFalse);
        expect(viewModel.velocidade, VelocidadeNarracao.normal);
      });

      test('Deve carregar o que o paciente tinha escolhido', () async {
        SharedPreferences.setMockInitialValues({
          'narrador.ligado': true,
          'narrador.velocidade': 'rapido',
        });

        final viewModel = await carregado();

        expect(viewModel.narradorLigado, isTrue);
        expect(viewModel.velocidade, VelocidadeNarracao.rapido);
      });

      test('Deve deixar a voz pronta, já na velocidade escolhida', () async {
        SharedPreferences.setMockInitialValues({'narrador.velocidade': 'devagar'});

        await carregado();

        expect(tts.inicializacoes, 1);
        expect(tts.velocidade, VelocidadeNarracao.devagar.taxa);
      });

      test('Não deve falar nada ao carregar, mesmo com o narrador ligado', () async {
        SharedPreferences.setMockInitialValues({'narrador.ligado': true});

        await carregado();

        expect(tts.faladas, isEmpty);
      });

      test('Deve avisar quando o aparelho não tem a voz em português', () async {
        final viewModel = await carregado(
          voz: FakeTtsService(vozEmPortugues: false),
        );

        expect(viewModel.faltaVozEmPortugues, isTrue);
      });

      test('Não deve avisar de voz faltando quando ela existe', () async {
        final viewModel = await carregado();

        expect(viewModel.faltaVozEmPortugues, isFalse);
      });

      test('Deve se declarar não suportado, sem mexer na voz, onde não há voz do sistema', () async {
        final voz = FakeTtsService(disponivel: false);

        final viewModel = await carregado(voz: voz);

        expect(viewModel.suportado, isFalse);
        expect(voz.inicializacoes, 0);
      });

      test('Deve usar o padrão se não conseguir ler a configuração guardada', () async {
        final viewModel = criar(preferencias: _PreferenciasQueFalham());

        await viewModel.carregar();

        expect(viewModel.carregando, isFalse);
        expect(viewModel.narradorLigado, isFalse);
        expect(viewModel.velocidade, VelocidadeNarracao.normal);
      });
    });

    group('ligar e desligar', () {
      test('Deve ligar o narrador, guardar a escolha e confirmar falando', () async {
        final viewModel = await carregado();

        await viewModel.alternarNarrador(true);

        expect(viewModel.narradorLigado, isTrue);
        expect(tts.faladas, ['Narrador ligado.']);
        expect((await PreferenciasRepository().narrador()).ligado, isTrue);
      });

      test('Deve desligar o narrador e calar a voz', () async {
        SharedPreferences.setMockInitialValues({'narrador.ligado': true});
        final viewModel = await carregado();

        await viewModel.alternarNarrador(false);

        expect(viewModel.narradorLigado, isFalse);
        expect(tts.paradas, 1);
        expect(tts.faladas, isEmpty);
        expect((await PreferenciasRepository().narrador()).ligado, isFalse);
      });

      test('Não deve fazer nada se já está como foi pedido', () async {
        final viewModel = await carregado();

        await viewModel.alternarNarrador(false);

        expect(tts.paradas, 0);
        expect(tts.faladas, isEmpty);
      });

      test('Deve lembrar que está ligado na próxima vez que o app abre', () async {
        final primeiro = await carregado();
        await primeiro.alternarNarrador(true);

        final segundo = await carregado(voz: FakeTtsService());

        expect(segundo.narradorLigado, isTrue);
      });

      test('Não deve ligar se não conseguir guardar a escolha', () async {
        final viewModel = criar(preferencias: _PreferenciasQueFalham());
        await viewModel.carregar();

        await viewModel.alternarNarrador(true);

        expect(viewModel.narradorLigado, isFalse);
        expect(viewModel.mensagemErro, isNotNull);
        expect(tts.faladas, isEmpty);
      });

      test('Deve avisar os ouvintes quando a escolha muda', () async {
        final viewModel = await carregado();
        var avisos = 0;
        viewModel.addListener(() => avisos++);

        await viewModel.alternarNarrador(true);

        expect(avisos, greaterThan(0));
      });
    });

    group('velocidade', () {
      test('Deve escolher a velocidade, guardar, aplicar à voz e falar um exemplo', () async {
        final viewModel = await carregado();

        await viewModel.escolherVelocidade(VelocidadeNarracao.devagar);

        expect(viewModel.velocidade, VelocidadeNarracao.devagar);
        expect(tts.velocidade, VelocidadeNarracao.devagar.taxa);
        expect(tts.faladas, ['Estou falando devagar.']);
        expect(
          (await PreferenciasRepository().narrador()).velocidade,
          VelocidadeNarracao.devagar,
        );
      });

      test('Deve falar um exemplo diferente para cada velocidade', () async {
        final viewModel = await carregado();

        await viewModel.escolherVelocidade(VelocidadeNarracao.normal);
        await viewModel.escolherVelocidade(VelocidadeNarracao.rapido);

        expect(tts.faladas, [
          'Estou falando na velocidade normal.',
          'Estou falando rápido.',
        ]);
      });

      test('Deve poder escolher a velocidade com o narrador desligado', () async {
        final viewModel = await carregado();
        expect(viewModel.narradorLigado, isFalse);

        await viewModel.escolherVelocidade(VelocidadeNarracao.rapido);

        expect(viewModel.velocidade, VelocidadeNarracao.rapido);
      });

      test('Deve manter a velocidade que tinha se não conseguir guardar a nova', () async {
        final viewModel = criar(preferencias: _PreferenciasQueFalham());
        await viewModel.carregar();

        await viewModel.escolherVelocidade(VelocidadeNarracao.rapido);

        expect(viewModel.velocidade, VelocidadeNarracao.normal);
        expect(viewModel.mensagemErro, isNotNull);
        expect(tts.faladas, isEmpty);
      });
    });

    group('testar a voz', () {
      test('Deve falar uma frase de teste', () async {
        final viewModel = await carregado();

        await viewModel.testarVoz();

        expect(tts.faladas, hasLength(1));
        expect(tts.faladas.single, contains('narrador do Agenda Saúde'));
      });

      test('Deve avisar, sem quebrar, quando a voz do sistema recusa falar', () async {
        final viewModel = await carregado(voz: _VozQueFalha());

        await viewModel.testarVoz();

        expect(viewModel.mensagemErro, contains('voz do sistema'));
      });

      test('Deve limpar o aviso de erro na tentativa seguinte', () async {
        final voz = _VozQueFalha(soNaPrimeiraVez: true);
        final viewModel = await carregado(voz: voz);
        await viewModel.testarVoz();
        expect(viewModel.mensagemErro, isNotNull);

        await viewModel.testarVoz();

        expect(viewModel.mensagemErro, isNull);
        expect(voz.faladas, hasLength(1));
      });

      test('Não deve falar onde não há voz do sistema', () async {
        final voz = FakeTtsService(disponivel: false);
        final viewModel = await carregado(voz: voz);

        await viewModel.testarVoz();

        expect(voz.faladas, isEmpty);
      });
    });

    group('ouvir esta tela', () {
      // O narrador ja vem ligado, como depois de o paciente te-lo ligado.
      Future<ConfiguracoesViewModel> ligado({
        FakeTtsService? voz,
        String velocidade = 'normal',
      }) async {
        SharedPreferences.setMockInitialValues({
          'narrador.ligado': true,
          'narrador.velocidade': velocidade,
        });
        return carregado(voz: voz);
      }

      test('Deve ler o texto em voz alta com o narrador ligado', () async {
        final viewModel = await ligado();

        final falou = await viewModel.ouvir('Sua rotina de hoje.');

        expect(falou, isTrue);
        expect(tts.faladas, ['Sua rotina de hoje.']);
        expect(viewModel.falando, isTrue);
      });

      test('Não deve falar com o narrador desligado', () async {
        final viewModel = await carregado();

        final falou = await viewModel.ouvir('Sua rotina de hoje.');

        expect(falou, isFalse);
        expect(tts.faladas, isEmpty);
        expect(viewModel.falando, isFalse);
      });

      test('Não deve falar onde não há voz do sistema', () async {
        final voz = FakeTtsService(disponivel: false);
        final viewModel = await ligado(voz: voz);

        final falou = await viewModel.ouvir('Olá');

        expect(falou, isFalse);
        expect(voz.faladas, isEmpty);
      });

      test('Deve falar na velocidade que o paciente escolheu', () async {
        final viewModel = await ligado(velocidade: 'devagar');

        await viewModel.ouvir('Olá');

        expect(tts.velocidade, VelocidadeNarracao.devagar.taxa);
      });

      test('Deve voltar a "não falando" quando a voz termina o texto', () async {
        final viewModel = await ligado();
        await viewModel.ouvir('Olá');
        expect(viewModel.falando, isTrue);

        tts.terminarDeFalar();

        expect(viewModel.falando, isFalse);
      });

      test('Deve avisar os ouvintes quando começa e quando termina de falar', () async {
        final viewModel = await ligado();
        final estados = <bool>[];
        viewModel.addListener(() => estados.add(viewModel.falando));

        await viewModel.ouvir('Olá');
        tts.terminarDeFalar();

        expect(estados, [true, false]);
      });

      test('Deve parar a leitura quando o paciente pede', () async {
        final viewModel = await ligado();
        await viewModel.ouvir('Olá');

        await viewModel.pararDeOuvir();

        expect(viewModel.falando, isFalse);
        expect(tts.paradas, 1);
      });

      test('Deve calar a leitura em andamento ao desligar o narrador', () async {
        final viewModel = await ligado();
        await viewModel.ouvir('Olá');

        await viewModel.alternarNarrador(false);

        expect(viewModel.falando, isFalse);
        expect(tts.paradas, 1);
      });

      test('Deve esperar a configuração carregar antes de decidir se fala', () async {
        SharedPreferences.setMockInitialValues({'narrador.ligado': true});
        final viewModel = criar();
        expect(viewModel.carregando, isTrue);

        final falou = viewModel.ouvir('Olá');
        await viewModel.carregar();

        expect(await falou, isTrue);
        expect(tts.faladas, ['Olá']);
      });

      testWidgets('Não deve ficar esperando para sempre se a configuração nunca carrega', (tester) async {
        final viewModel = criar();

        final falou = viewModel.ouvir('Olá');
        await tester.pump(const Duration(seconds: 6));

        expect(await falou, isFalse);
        expect(tts.faladas, isEmpty);
      });

      test('Deve avisar, sem quebrar, quando a voz do sistema recusa falar', () async {
        final viewModel = await ligado(voz: _VozQueFalha());

        final falou = await viewModel.ouvir('Olá');

        expect(falou, isFalse);
        expect(viewModel.falando, isFalse);
        expect(viewModel.mensagemErro, contains('voz do sistema'));
      });

      test('Deve calar a voz quando o ViewModel é descartado falando', () async {
        final viewModel = await ligado();
        await viewModel.ouvir('Olá');

        viewModel.dispose();

        expect(tts.paradas, 1);
        expect(tts.ouvinteDaFala, isNull);
      });

      test('Não deve mexer na voz ao ser descartado sem estar falando', () async {
        final viewModel = await ligado();

        viewModel.dispose();

        expect(tts.paradas, 0);
      });
    });
  });
}
