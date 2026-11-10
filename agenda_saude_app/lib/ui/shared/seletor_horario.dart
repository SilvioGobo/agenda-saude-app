import 'package:flutter/material.dart';

import '../../domain/medicacao/horario_medicacao.dart';

// Abre o seletor de hora do Flutter (o relogio) e devolve o horario escolhido
// em "HH:MM", ou null se a pessoa cancelar. A pessoa toca na hora (de 00 a 11
// no anel de fora, de 12 a 23 no de dentro), o relogio passa sozinho para os
// minutos (de 5 em 5 ao tocar; arrastando o ponteiro, minuto a minuto) e ela
// confirma em OK.
//
// - Sempre em 24 horas, qualquer que seja a configuracao do celular: "20:00",
//   e nao "8:00 PM".
// - So o relogio, sem o icone de teclado: o guia visual pede escolha em vez de
//   campo de texto, e o icone ao lado de "Cancelar" e "OK" nao cabe na linha
//   dos botoes com a fonte grande (a linha quebra e estoura a janela).
// - A fonte do celular aumenta o seletor ate 110%: o Flutter calcula o tamanho
//   da janela com esse limite. Os numeros da hora escolhida ja sao grandes.
//
// O tamanho do titulo e dos botoes vem do tema (`timePickerTheme`). `inicial`
// vem em "HH:MM"; se nao for um horario, o relogio abre nas 08:00.
Future<String?> mostrarSeletorDeHorario(
  BuildContext context, {
  required String inicial,
  String titulo = 'ESCOLHA O HORÁRIO',
}) async {
  final partes = (normalizarHorario(inicial) ?? '08:00').split(':');
  final escolhido = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: int.parse(partes[0]),
      minute: int.parse(partes[1]),
    ),
    initialEntryMode: TimePickerEntryMode.dialOnly,
    // Os textos vao escritos aqui, e nao so pelas traducoes do app, para o
    // seletor ser o mesmo nos testes (que montam o app sem elas).
    helpText: titulo,
    cancelText: 'Cancelar',
    confirmText: 'OK',
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: child!,
      ),
    ),
  );
  if (escolhido == null) return null;
  return formatarHorario(escolhido.hour, escolhido.minute);
}
