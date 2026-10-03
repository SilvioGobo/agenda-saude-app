import 'package:flutter/material.dart';

// Paleta do app (detalhes e exemplos em GUIA_VISUAL.md, na raiz do repo).
//
// As cores de marca vem do ColorScheme gerado a partir de `semente` pelo
// Material 3 - use sempre `Theme.of(context).colorScheme` para elas. Valores
// gerados (tema claro), so para referencia:
//   primary            #006B5F   onPrimary            #FFFFFF
//   primaryContainer   #9EF2E3   onPrimaryContainer   #00201C
//   secondaryContainer #CCE8E2   onSecondaryContainer #06201C
//   surface (fundo)    #F4FBF8   onSurface (texto)    #161D1B
//   surfaceContainerLow (cards) #EFF5F2
//   onSurfaceVariant (texto secundario) #3F4946
//
// Aqui ficam as cores SEMANTICAS (estado de saude e avisos), que o
// ColorScheme nao cobre. Cada uma tem trio cor / container / onContainer,
// no mesmo esquema do Material 3. Todas foram conferidas para contraste de
// pelo menos 4,5:1 (WCAG AA para texto comum, AAA para texto grande) sobre o
// fundo do app, sobre os cards e sobre o proprio container - requisito de
// alto contraste para idosos (NF004). Nao usar Colors.green/red/orange
// direto: os tons padrao ficam abaixo de 3:1 no fundo claro.
class AppCores {
  AppCores._();

  // Verde-agua do mockup do TCC; gera toda a paleta de marca.
  static const Color semente = Color(0xFF14B8A6);

  // Sucesso / estado normal (ex.: "ESTÁVEL"). Contraste 6,2:1 no fundo.
  static const Color sucesso = Color(0xFF146C2E);
  static const Color sucessoContainer = Color(0xFFD3F5D9);
  static const Color onSucessoContainer = Color(0xFF002108);

  // Aviso que pede uma acao, sem ser emergencia (ex.: smartwatch
  // desconectado). Laranja escuro: 6,2:1 no fundo.
  static const Color aviso = Color(0xFF8B5000);
  static const Color avisoContainer = Color(0xFFFFDCBE);
  static const Color onAvisoContainer = Color(0xFF2D1600);

  // Perigo / alerta de saude (ex.: BPM fora da zona) e mensagens de erro.
  // Mesmos tons do `error` do Material 3: 6,2:1 no fundo.
  static const Color perigo = Color(0xFFBA1A1A);
  static const Color perigoContainer = Color(0xFFFFDAD6);
  static const Color onPerigoContainer = Color(0xFF410002);
}
