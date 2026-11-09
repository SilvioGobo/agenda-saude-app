'use strict';

// Firestore falso em memoria para os testes das funcoes agendadas: guarda os
// documentos por caminho ("colecao/id") e responde as consultas que elas usam
// (`where` com ==, >=, <, `orderBy` e `limit`) e o `create` que falha quando o
// documento ja existe, como o Firestore de verdade.

function valorComparavel(valor) {
  if (valor && typeof valor.toMillis === 'function') return valor.toMillis();
  if (valor instanceof Date) return valor.getTime();
  return valor;
}

function passa(dados, [campo, operador, esperado]) {
  const valor = valorComparavel(dados[campo]);
  const alvo = valorComparavel(esperado);
  switch (operador) {
    case '==':
      return valor === alvo;
    case '>=':
      return valor >= alvo;
    case '>':
      return valor > alvo;
    case '<':
      return valor < alvo;
    case '<=':
      return valor <= alvo;
    default:
      throw new Error(`Operador nao suportado no falso: ${operador}`);
  }
}

function criarFirestoreFalso(documentosIniciais = {}) {
  const documentos = new Map(Object.entries(documentosIniciais));
  const consultas = [];

  function documento(colecao, id) {
    const caminho = `${colecao}/${id}`;
    return {
      id,
      async get() {
        const dados = documentos.get(caminho);
        return { id, exists: dados !== undefined, data: () => dados };
      },
      async create(dados) {
        if (documentos.has(caminho)) {
          const erro = new Error(`ALREADY_EXISTS: ${caminho}`);
          erro.code = 6;
          throw erro;
        }
        documentos.set(caminho, dados);
      },
      async set(dados) {
        documentos.set(caminho, dados);
      },
      async update(campos) {
        if (!documentos.has(caminho)) throw new Error(`NOT_FOUND: ${caminho}`);
        documentos.set(caminho, { ...documentos.get(caminho), ...campos });
      },
    };
  }

  function consulta(colecao, filtros = [], ordem = null, limite = null) {
    return {
      where(campo, operador, valor) {
        return consulta(colecao, [...filtros, [campo, operador, valor]], ordem, limite);
      },
      orderBy(campo, direcao = 'asc') {
        return consulta(colecao, filtros, { campo, direcao }, limite);
      },
      limit(quantos) {
        return consulta(colecao, filtros, ordem, quantos);
      },
      doc(id) {
        return documento(colecao, id);
      },
      async get() {
        consultas.push({ colecao, filtros });
        let encontrados = [...documentos.entries()]
          .filter(([caminho]) => caminho.startsWith(`${colecao}/`))
          .map(([caminho, dados]) => ({
            id: caminho.slice(colecao.length + 1),
            dados,
          }))
          .filter(({ dados }) => filtros.every((filtro) => passa(dados, filtro)));
        if (ordem) {
          const sinal = ordem.direcao === 'desc' ? -1 : 1;
          encontrados.sort(
            (a, b) =>
              sinal *
              (valorComparavel(a.dados[ordem.campo]) -
                valorComparavel(b.dados[ordem.campo])),
          );
        }
        if (limite !== null) encontrados = encontrados.slice(0, limite);
        const docs = encontrados.map(({ id, dados }) => ({
          id,
          data: () => dados,
        }));
        return { docs, empty: docs.length === 0, size: docs.length };
      },
    };
  }

  return {
    documentos,
    consultas,
    collection(colecao) {
      return consulta(colecao);
    },
    // Os documentos de uma colecao, por id (para conferir o que foi criado).
    daColecao(colecao) {
      return Object.fromEntries(
        [...documentos.entries()]
          .filter(([caminho]) => caminho.startsWith(`${colecao}/`))
          .map(([caminho, dados]) => [caminho.slice(colecao.length + 1), dados]),
      );
    },
  };
}

module.exports = { criarFirestoreFalso };
