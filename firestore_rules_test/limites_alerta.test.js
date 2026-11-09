'use strict';

// B8 (RF 06.1): o acompanhante vinculado define os limites de BPM que disparam
// o alerta do paciente. As rules deixam ele mexer so em `limitesAlerta`, com
// valores dentro das faixas de LimitesAlerta e com o proprio UID em
// `atualizadoPor`; ninguem mais (alem do paciente) grava esse campo.

const { after, before, beforeEach, describe, it } = require('node:test');
const {
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  arrayUnion,
  deleteField,
  doc,
  getDoc,
  updateDoc,
} = require('firebase/firestore');

const { criarAmbiente, semearDocumentos } = require('./ambiente');

const PACIENTE = 'paciente_01';
const CUIDADOR = 'cuidador_01';
// Acompanhante sem vinculo com o paciente.
const ESTRANHO = 'cuidador_02';
// Tem o paciente na propria lista, mas o paciente nao o tem na dele.
const SO_DE_UM_LADO = 'cuidador_03';

function limites(campos = {}) {
  return {
    bpmMinimo: 50,
    bpmMaximo: 110,
    atualizadoPor: CUIDADOR,
    atualizadoEm: Timestamp.now(),
    ...campos,
  };
}

describe('Limites de alerta (RF 06.1) Testes', () => {
  let ambiente;

  before(async () => {
    ambiente = await criarAmbiente();
  });

  after(async () => {
    await ambiente?.cleanup();
  });

  beforeEach(async () => {
    await ambiente.clearFirestore();
    await semearDocumentos(ambiente, {
      [`usuarios/${PACIENTE}`]: {
        nome: 'José Silva',
        perfil: 'Paciente',
        possuiCardiopatia: false,
        acompanhantesVinculadosIds: [CUIDADOR],
        limitesAlerta: null,
      },
      [`usuarios/${CUIDADOR}`]: {
        nome: 'Carlos Souza',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [PACIENTE],
      },
      [`usuarios/${ESTRANHO}`]: {
        nome: 'Ana Lima',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [],
      },
      [`usuarios/${SO_DE_UM_LADO}`]: {
        nome: 'Rui Prado',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [PACIENTE],
      },
    });
  });

  function docDoPacienteComo(uid) {
    return doc(ambiente.authenticatedContext(uid).firestore(), 'usuarios', PACIENTE);
  }

  it('Deve deixar o acompanhante vinculado gravar limites válidos', async () => {
    await assertSucceeds(
      updateDoc(docDoPacienteComo(CUIDADOR), { limitesAlerta: limites() }),
    );
  });

  it('Deve aceitar os extremos das faixas (40 e 150) e os limites sem data', async () => {
    await assertSucceeds(
      updateDoc(docDoPacienteComo(CUIDADOR), {
        limitesAlerta: { bpmMinimo: 40, bpmMaximo: 150, atualizadoPor: CUIDADOR },
      }),
    );
    await assertSucceeds(
      updateDoc(docDoPacienteComo(CUIDADOR), {
        limitesAlerta: limites({ bpmMinimo: 90, bpmMaximo: 110 }),
      }),
    );
  });

  it('Deve deixar o acompanhante vinculado apagar os limites (volta à zona padrão)', async () => {
    await semearDocumentos(ambiente, {
      [`usuarios/${PACIENTE}`]: {
        nome: 'José Silva',
        perfil: 'Paciente',
        acompanhantesVinculadosIds: [CUIDADOR],
        limitesAlerta: { bpmMinimo: 50, bpmMaximo: 110, atualizadoPor: CUIDADOR },
      },
    });
    await assertSucceeds(
      updateDoc(docDoPacienteComo(CUIDADOR), { limitesAlerta: deleteField() }),
    );
  });

  it('Deve negar limites fora das faixas ou que não são números inteiros', async () => {
    const invalidos = [
      limites({ bpmMinimo: 35 }),
      limites({ bpmMinimo: 95, bpmMaximo: 130 }),
      limites({ bpmMaximo: 75, bpmMinimo: 40 }),
      limites({ bpmMaximo: 160 }),
      // Menos de 20 BPM entre o minimo e o maximo.
      limites({ bpmMinimo: 80, bpmMaximo: 90 }),
      limites({ bpmMinimo: '50' }),
      limites({ bpmMaximo: 110.5 }),
      'limites',
    ];
    for (const valor of invalidos) {
      await assertFails(
        updateDoc(docDoPacienteComo(CUIDADOR), { limitesAlerta: valor }),
      );
    }
  });

  it('Deve negar os limites sem o mínimo, sem o máximo ou com campo a mais', async () => {
    const { bpmMinimo, ...semMinimo } = limites();
    const { bpmMaximo, ...semMaximo } = limites();
    const { atualizadoPor, ...semAutor } = limites();
    for (const valor of [semMinimo, semMaximo, semAutor, limites({ tempo: 5 })]) {
      await assertFails(
        updateDoc(docDoPacienteComo(CUIDADOR), { limitesAlerta: valor }),
      );
    }
  });

  it('Deve negar quando o atualizadoPor não é quem está gravando', async () => {
    await assertFails(
      updateDoc(docDoPacienteComo(CUIDADOR), {
        limitesAlerta: limites({ atualizadoPor: ESTRANHO }),
      }),
    );
  });

  it('Deve negar mudar outro campo do paciente junto com os limites', async () => {
    await assertFails(
      updateDoc(docDoPacienteComo(CUIDADOR), {
        limitesAlerta: limites(),
        possuiCardiopatia: true,
      }),
    );
  });

  it('Deve negar entrar na lista do paciente e mudar os limites na mesma gravação', async () => {
    await assertFails(
      updateDoc(docDoPacienteComo(ESTRANHO), {
        acompanhantesVinculadosIds: arrayUnion(ESTRANHO),
        limitesAlerta: limites({ atualizadoPor: ESTRANHO }),
      }),
    );
  });

  it('Deve negar o acompanhante que não está vinculado ao paciente', async () => {
    await assertFails(
      updateDoc(docDoPacienteComo(ESTRANHO), {
        limitesAlerta: limites({ atualizadoPor: ESTRANHO }),
      }),
    );
  });

  it('Deve negar o acompanhante vinculado só de um lado', async () => {
    await assertFails(
      updateDoc(docDoPacienteComo(SO_DE_UM_LADO), {
        limitesAlerta: limites({ atualizadoPor: SO_DE_UM_LADO }),
      }),
    );
  });

  it('Deve negar quem não está logado', async () => {
    const anonimo = ambiente.unauthenticatedContext().firestore();
    await assertFails(
      updateDoc(doc(anonimo, 'usuarios', PACIENTE), { limitesAlerta: limites() }),
    );
  });

  it('Deve deixar o próprio paciente gravar e apagar os limites', async () => {
    await assertSucceeds(
      updateDoc(docDoPacienteComo(PACIENTE), {
        limitesAlerta: limites({ atualizadoPor: PACIENTE }),
      }),
    );
    await assertSucceeds(
      updateDoc(docDoPacienteComo(PACIENTE), { limitesAlerta: deleteField() }),
    );
  });

  it('Deve deixar o acompanhante vinculado ler os limites e negar a leitura a quem não é vinculado', async () => {
    await assertSucceeds(getDoc(docDoPacienteComo(CUIDADOR)));
    await assertFails(getDoc(docDoPacienteComo(ESTRANHO)));
  });

  it('Deve continuar deixando um acompanhante entrar na lista do paciente (vínculo)', async () => {
    await assertSucceeds(
      updateDoc(docDoPacienteComo(ESTRANHO), {
        acompanhantesVinculadosIds: arrayUnion(ESTRANHO),
      }),
    );
  });
});
