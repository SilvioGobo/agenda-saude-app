'use strict';

// Ambiente dos testes das security rules: o emulador do Firestore com o
// firestore.rules da raiz do repositorio, num projeto `demo-*` (nada sai para
// o Firebase real). O endereco do emulador vem de FIRESTORE_EMULATOR_HOST,
// que o `firebase emulators:exec` ja define (ver CLAUDE.md, "Comandos").

const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { setLogLevel } = require('firebase/firestore');

const ID_DO_PROJETO = 'demo-rules';

// O SDK avisa cada gravacao negada (PERMISSION_DENIED); nos testes isso e o
// esperado e so polui a saida.
setLogLevel('error');

async function criarAmbiente() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST nao definido: suba o emulador do Firestore ' +
        '(npm run test:emulador) ou defina o endereco dele.',
    );
  }
  return initializeTestEnvironment({
    projectId: ID_DO_PROJETO,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
}

// Grava os documentos sem passar pelas rules (o "estado do banco" do teste).
async function semearDocumentos(ambiente, documentos) {
  await ambiente.withSecurityRulesDisabled(async (contexto) => {
    const banco = contexto.firestore();
    for (const [caminho, dados] of Object.entries(documentos)) {
      await banco.doc(caminho).set(dados);
    }
  });
}

module.exports = { criarAmbiente, semearDocumentos };
