package com.example.agenda_saude_app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (e nao FlutterActivity) e exigido pelo plugin health
// para abrir a tela de permissoes do Health Connect no Android 14+.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Depois de duas negativas o Android deixa de mostrar o pop-up de
        // permissao; a unica saida e o usuario liberar nas configuracoes do
        // Health Connect, que abrimos por aqui.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_HEALTH_CONNECT)
            .setMethodCallHandler { call, result ->
                if (call.method == "abrirConfiguracoes") {
                    try {
                        startActivity(Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    companion object {
        private const val CANAL_HEALTH_CONNECT = "agenda_saude_app/health_connect"
    }
}
