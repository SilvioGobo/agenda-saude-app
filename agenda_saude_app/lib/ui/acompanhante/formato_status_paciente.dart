import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/registro_agua.dart';
import '../../domain/models/registro_base.dart';
import '../../domain/models/registro_diabete.dart';
import '../../domain/models/registro_exercicio.dart';
import '../../domain/models/registro_refeicao.dart';
import '../../domain/models/registro_sono.dart';
import '../insulina/formatacao_diabete.dart';
import 'status_paciente_viewmodel.dart';

// Rotulo, icone e cor de cada status do card do paciente (Figura 15), no
// mesmo padrao do selo "ESTÁVEL" do painel do paciente (Figura 13).
// "SEM DADOS" e aviso (laranja), como os problemas do smartwatch: o vermelho
// fica so para o alerta de saude.
({String rotulo, IconData icone, Color cor}) estiloDoStatus(StatusSaude status) {
  switch (status) {
    case StatusSaude.estavel:
      return (
        rotulo: 'ESTÁVEL',
        icone: Icons.check_circle_rounded,
        cor: AppCores.sucesso,
      );
    case StatusSaude.atencao:
      return (
        rotulo: 'ATENÇÃO',
        icone: Icons.warning_rounded,
        cor: AppCores.perigo,
      );
    case StatusSaude.semDados:
      return (
        rotulo: 'SEM DADOS',
        icone: Icons.watch_off_rounded,
        cor: AppCores.aviso,
      );
  }
}

// O que o paciente fez na ultima atividade da rotina, em caixa alta e com
// verbo ("BEBEU ÁGUA: 250 ML", "MEDIU A GLICEMIA: 112 mg/dL"), para nao se
// confundir com o resumo de glicemia e insulina logo abaixo no card.
({IconData icone, String texto}) descreverAtividade(RegistroBase registro) {
  if (registro is RegistroAgua) {
    return (
      icone: Icons.water_drop_rounded,
      texto: 'BEBEU ÁGUA: ${registro.quantidadeML} ML',
    );
  }
  if (registro is RegistroRefeicao) {
    final nome = registro.nome.trim();
    return (
      icone: Icons.restaurant_rounded,
      texto: nome.isEmpty
          ? 'FEZ UMA REFEIÇÃO'
          : 'FEZ A REFEIÇÃO: ${nome.toUpperCase()}',
    );
  }
  if (registro is RegistroDiabete) {
    final partes = [
      if (registro.temGlicemia)
        'MEDIU A GLICEMIA: ${formatarGlicemia(registro.nivelGlicose!)}',
      if (registro.temInsulina)
        'APLICOU '
            '${descreverInsulina(registro.tipoInsulina, registro.doseInsulina!).toUpperCase()}',
    ];
    return (
      icone: registro.temGlicemia
          ? Icons.bloodtype_rounded
          : Icons.vaccines_rounded,
      texto: partes.isEmpty ? 'CONTROLE DO DIABETES' : partes.join(' E '),
    );
  }
  if (registro is RegistroSono) {
    return (
      icone: Icons.bedtime_rounded,
      texto: 'REGISTROU O SONO: ${_descreverHoras(registro.horasTotais)}',
    );
  }
  if (registro is RegistroExercicio) {
    final tipo = registro.tipoExercicio.trim();
    final duracao = '${registro.duracaoMinutos} MINUTOS';
    return (
      icone: Icons.directions_walk_rounded,
      texto: tipo.isEmpty
          ? 'FEZ EXERCÍCIO: $duracao'
          : 'FEZ EXERCÍCIO: ${tipo.toUpperCase()}, $duracao',
    );
  }
  return (icone: Icons.checklist_rounded, texto: 'ATIVIDADE DA ROTINA');
}

// "7 HORAS", "1 HORA E 30 MINUTOS", "45 MINUTOS".
String _descreverHoras(double horas) {
  final totalMinutos = (horas * 60).round();
  final h = totalMinutos ~/ 60;
  final min = totalMinutos % 60;
  final textoHoras = h == 1 ? '1 HORA' : '$h HORAS';
  if (min == 0) return textoHoras;
  if (h == 0) return '$min MINUTOS';
  return '$textoHoras E $min MINUTOS';
}
