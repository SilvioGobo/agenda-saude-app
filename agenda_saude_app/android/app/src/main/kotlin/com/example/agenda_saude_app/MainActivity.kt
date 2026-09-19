package com.example.agenda_saude_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (e nao FlutterActivity) e exigido pelo plugin health
// para abrir a tela de permissoes do Health Connect no Android 14+.
class MainActivity : FlutterFragmentActivity()
