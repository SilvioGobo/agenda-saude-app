import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../models/alerta.dart';
import '../models/batimento_cardiaco.dart';
import '../models/paciente.dart';
import '../models/registro_agua.dart';
import '../models/registro_diabete.dart';
import '../models/registro_refeicao.dart';
import 'resumo_do_dia.dart';
import 'resumo_do_mes.dart';

// Monta os relatorios (RF05) a partir dos registros que o paciente fez. Sao
// contas simples sobre listas - sem Firebase nem Flutter - para o resultado
// ser testavel e igual para o paciente e para o acompanhante, que leem os
// mesmos registros.
class CalculadoraRelatorios {
  CalculadoraRelatorios._();

  static DateTime inicioDoDia(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  static DateTime primeiroDiaDoMes(DateTime data) =>
      DateTime(data.year, data.month);

  static int diasNoMes(DateTime data) =>
      DateTime(data.year, data.month + 1, 0).day;

  // Resume o dia [dia] com os registros dele: as listas ja devem ser so desse
  // dia (quem consulta o Firestore filtra pelo intervalo do dia).
  static ResumoDoDia resumirDia({
    required Paciente paciente,
    required DateTime dia,
    List<RegistroAgua> agua = const [],
    List<RegistroRefeicao> refeicoes = const [],
    List<RegistroDiabete> diabete = const [],
    List<BatimentoCardiaco> batimentos = const [],
    List<Alerta> alertas = const [],
  }) {
    return ResumoDoDia(
      dia: inicioDoDia(dia),
      hidratacao: HidratacaoDoDia(
        totalMl: agua.fold(0, (soma, registro) => soma + registro.quantidadeML),
        metaMl: paciente.metaHidratacaoMl,
        registros: agua.length,
      ),
      refeicoes: RefeicoesDoDia.de(
        plano: paciente.planoDeRefeicoes,
        registros: refeicoes,
      ),
      diabetes: paciente.possuiDiabetes
          ? DiabetesDoDia.de(
              diabete,
              usaInsulina: paciente.usaInsulina == true,
            )
          : null,
      batimentos: resumirBatimentos(
        batimentos,
        possuiCardiopatia: paciente.possuiCardiopatia,
      ),
      // Do mais recente para o mais antigo, como a tela mostra.
      alertas: [...alertas]..sort((a, b) => b.dataHora.compareTo(a.dataHora)),
    );
  }

  static BatimentosDoDia resumirBatimentos(
    List<BatimentoCardiaco> leituras, {
    required bool possuiCardiopatia,
  }) {
    final minimoDaZona =
        ZonaSegurancaCardiaca.bpmMinimo(possuiCardiopatia: possuiCardiopatia);
    final maximoDaZona =
        ZonaSegurancaCardiaca.bpmMaximo(possuiCardiopatia: possuiCardiopatia);
    if (leituras.isEmpty) {
      return BatimentosDoDia(
        leituras: 0,
        zonaMinima: minimoDaZona,
        zonaMaxima: maximoDaZona,
      );
    }

    final valores = leituras.map((leitura) => leitura.bpm).toList();
    return BatimentosDoDia(
      leituras: valores.length,
      media: valores.reduce((a, b) => a + b) / valores.length,
      minimo: valores.reduce((a, b) => a < b ? a : b),
      maximo: valores.reduce((a, b) => a > b ? a : b),
      foraDaZona: valores
          .where((bpm) => bpm < minimoDaZona || bpm > maximoDaZona)
          .length,
      zonaMinima: minimoDaZona,
      zonaMaxima: maximoDaZona,
    );
  }

  // Resume o mes de [mes] a partir dos registros dele. [hoje] define quais
  // dias ja terminaram: no mes atual so os anteriores a hoje; num mes passado
  // todos; num mes futuro nenhum.
  static ResumoDoMes resumirMes({
    required Paciente paciente,
    required DateTime mes,
    required DateTime hoje,
    List<RegistroAgua> agua = const [],
    List<RegistroRefeicao> refeicoes = const [],
    List<RegistroDiabete> diabete = const [],
    List<Alerta> alertas = const [],
  }) {
    final primeiro = primeiroDiaDoMes(mes);
    final total = diasNoMes(primeiro);
    final mesAtual = primeiroDiaDoMes(hoje);

    final int ultimoEncerrado;
    if (primeiro == mesAtual) {
      ultimoEncerrado = hoje.day - 1;
    } else if (primeiro.isBefore(mesAtual)) {
      ultimoEncerrado = total;
    } else {
      ultimoEncerrado = 0;
    }

    final aguaPorDia = _agruparPorDia(agua, (r) => r.dataHora);
    final refeicoesPorDia = _agruparPorDia(refeicoes, (r) => r.dataHora);
    final diabetePorDia = _agruparPorDia(diabete, (r) => r.dataHora);
    final alertasPorDia = _agruparPorDia(alertas, (a) => a.dataHora);

    return ResumoDoMes(
      mes: primeiro,
      diasNoMes: total,
      diaDeHoje: primeiro == mesAtual ? hoje.day : null,
      dias: [
        for (var dia = 1; dia <= ultimoEncerrado; dia++)
          resumirDia(
            paciente: paciente,
            dia: DateTime(primeiro.year, primeiro.month, dia),
            agua: aguaPorDia[dia] ?? const [],
            refeicoes: refeicoesPorDia[dia] ?? const [],
            diabete: diabetePorDia[dia] ?? const [],
            alertas: alertasPorDia[dia] ?? const [],
          ),
      ],
    );
  }

  // Agrupa pelo dia do mes (1 a 31) de cada item. Os itens de um mes so
  // caem em dias desse mes, entao o dia do mes basta como chave.
  static Map<int, List<T>> _agruparPorDia<T>(
    Iterable<T> itens,
    DateTime Function(T item) dataDe,
  ) {
    final porDia = <int, List<T>>{};
    for (final item in itens) {
      porDia.putIfAbsent(dataDe(item).day, () => []).add(item);
    }
    return porDia;
  }
}
