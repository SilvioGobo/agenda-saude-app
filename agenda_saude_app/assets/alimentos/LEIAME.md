# Catálogo de alimentos (`taco.json`)

Valores nutricionais **por 100 g de parte comestível**, extraídos da
**Tabela Brasileira de Composição de Alimentos – TACO, 4ª edição ampliada e
revisada** (NEPA – Núcleo de Estudos e Pesquisas em Alimentação, UNICAMP,
Campinas, 2011). A TACO permite a reprodução total ou parcial desde que a
fonte seja citada.

Arquivo original: `taco_4_edicao_ampliada_e_revisada.pdf`, publicado pelo
Conselho Federal de Nutricionistas em
<https://cfn.org.br/wp-content/uploads/2017/03/taco_4_edicao_ampliada_e_revisada.pdf>
(a página do NEPA já não oferece o arquivo).

## Campos

| Campo          | Significado                                         |
| -------------- | --------------------------------------------------- |
| `id`           | número do alimento na Tabela 1 da TACO (1 a 597)    |
| `nome`         | descrição do alimento, como na TACO                 |
| `grupo`        | um dos 15 grupos da TACO                            |
| `kcal`         | energia (kcal)                                      |
| `proteinaG`    | proteína (g)                                        |
| `gorduraG`     | lipídeos (g)                                        |
| `carboidratoG` | carboidrato (g)                                     |
| `fibraG`       | fibra alimentar (g)                                 |
| `sodioMg`      | sódio (mg)                                          |

## Como foi gerado

As páginas da Tabela 1 vêm giradas no PDF. As palavras foram lidas com
PyMuPDF por coordenadas (desfazendo a rotação) e cada valor foi ligado à sua
coluna pelo cabeçalho. Regras aplicadas:

- `Tr` (traço) vira 0; `NA` (não aplicável) em proteína/lipídeos/carboidrato
  vira 0 (ex.: óleos) e a energia do sal vira 0.
- Ficaram **de fora 4 alimentos** que a própria TACO marca com `*` ("as
  análises estão sendo reavaliadas"): iogurte sabor abacaxi, leite de vaca
  integral, leite de vaca desnatado UHT e coco verde cru.
- Notas de rodapé coladas ao nome ("Cana, aguardente 1") foram removidas.
- Conferência: em todos os 593 alimentos a energia da tabela bate com
  4·proteína + 4·carboidrato + 9·lipídeos, exceto aguardente (calorias do
  álcool) e fermento químico.

Total: 593 alimentos. Para regerar, é preciso o PDF acima e o PyMuPDF.
