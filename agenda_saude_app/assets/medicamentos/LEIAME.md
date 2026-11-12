# Catálogo de remédios (`anvisa.json`)

Lista dos medicamentos **com registro ativo na Anvisa**, para o paciente escolher o
remédio pelo nome em "Meus remédios", na triagem e nas alergias. Fonte: **dados
abertos da Anvisa**, arquivo `DADOS_ABERTOS_MEDICAMENTOS.csv`
(<https://dados.anvisa.gov.br/dados/DADOS_ABERTOS_MEDICAMENTOS.csv>), baixado em
12/11/2026.

## Campos

| Campo         | Significado                                                       |
| ------------- | ----------------------------------------------------------------- |
| `nome`        | nome do produto, como no registro (`NOME_PRODUTO`)                |
| `substancias` | princípios ativos (`PRINCIPIO_ATIVO`) sem o sal nem a água         |

Exemplo: `{"nome": "Novalgina", "substancias": ["Dipirona"]}`. A alergia a remédio é
guardada pelo princípio ativo e comparada com `substancias`: quem tem alergia a
dipirona recebe o aviso ao escolher Novalgina, Anador ou Dorflex.

## Como foi gerado

`python3 gerar_catalogo.py DADOS_ABERTOS_MEDICAMENTOS.csv anvisa.json` (o script
está nesta pasta). Regras:

- Entram só os registros com situação **Ativo** das categorias genérico, similar,
  novo, específico, biológico e fitoterápico. Ficam de fora os dinamizados
  (homeopáticos, quase todos sem nome), os de baixo risco (notificados, sem princípio
  ativo), radiofármacos, gases medicinais e produtos de terapia avançada.
- Um item por nome: os registros de vários laboratórios com o mesmo nome viram um só
  (comparando sem acento e sem maiúsculas), com a grafia acentuada.
- Nome: genérico sai como frase ("Losartana potássica + hidroclorotiazida") e marca
  como título ("Novalgina Flash"), com siglas e números em maiúsculas ("Glifage XR",
  "Puran T4", "AAS"). Sai o que está entre parênteses ("(port. 344/98 – lista B1)").
- Princípio ativo sem o sal e sem a água: "cloridrato de metformina" → "Metformina",
  "dipirona monoidratada" → "Dipirona", "losartana potássica" → "Losartana". Quando o
  sal é o próprio remédio, fica inteiro ("Cloreto de potássio", "Carbonato de lítio").
  Planta medicinal fica com gênero e espécie ("Passiflora incarnata").

Total: 6.663 remédios e 1.933 princípios ativos. Nunca editar à mão: regerar da fonte.
