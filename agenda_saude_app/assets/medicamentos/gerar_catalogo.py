#!/usr/bin/env python3
"""Gera `anvisa.json` (catalogo de remedios do app) a partir dos dados abertos
da Anvisa. Uso:

    curl -o DADOS_ABERTOS_MEDICAMENTOS.csv \
        https://dados.anvisa.gov.br/dados/DADOS_ABERTOS_MEDICAMENTOS.csv
    python3 gerar_catalogo.py DADOS_ABERTOS_MEDICAMENTOS.csv anvisa.json

Ver LEIAME.md (o que entra, o que fica de fora e como sai o principio ativo).
"""

import collections
import csv
import html
import io
import json
import re
import sys
import unicodedata

# Categorias que entram. Ficam de fora os dinamizados (homeopaticos, quase
# todos sem nome: "NAO DECLARADO"), os de baixo risco (notificados, sem
# principio ativo: agua oxigenada, vaselina...), radiofarmacos, gases
# medicinais e produtos de terapia avancada.
CATEGORIAS = {
    'Genérico', 'Similar', 'Novo', 'Específico', 'Biológico',
    'Fitoterápico', 'FITOTERÁPICO',
}

# Hidratos e solvatos: "monoidratada", "di-hidratado", "anidra"...
HIDRATO = re.compile(
    r'^(?:mono|di|tri|tetra|penta|hexa|hepta|hemi|hemipenta|sesqui)?-?'
    r'h?idratad[oa]s?$|^anidr[oa]s?$|^propanodiol$')
# O cation escrito como adjetivo: "losartana potassica", "dipirona sodica".
CATION_ADJETIVO = re.compile(
    r'^(?:dis|di|tri)?(?:sódic|potássic|cálcic|magnésic|amônic)[oa]s?$'
    r'|^magnesian[oa]s?$')
# O que vem junto do farmaco e nao muda o farmaco ("olmesartana medoxomila",
# "trometamol cetorolaco").
SUFIXOS = {
    'medoxomila', 'cilexetila', 'axetila', 'benzatina', 'procaína',
    'trometamol', 'trometamina', 'dietilamônio', 'resinato', 'arginina',
    'lisina', 'meglumina', 'colestiramina',
}
# O sal escrito antes: "cloridrato de metformina", "besilato de anlodipino".
SAIS = {
    'cloridrato', 'dicloridrato', 'bromidrato', 'maleato', 'dimaleato',
    'besilato', 'mesilato', 'dimesilato', 'succinato', 'tartarato',
    'hemitartarato', 'bitartarato', 'fumarato', 'hemifumarato', 'citrato',
    'sulfato', 'fosfato', 'difosfato', 'acetato', 'valerato', 'propionato',
    'dipropionato', 'furoato', 'benzoato', 'nitrato', 'lactato', 'mucato',
    'pamoato', 'embonato', 'oxalato', 'bissulfato', 'hiclato', 'decanoato',
    'enantato', 'cipionato', 'undecilato', 'tosilato', 'xinafoato',
    'brometo', 'iodeto', 'estearato', 'palmitato', 'napadisilato',
    'hidrobrometo', 'gliconato', 'gluconato', 'butilbrometo', 'metilbrometo',
}
# Quando o "sal" e o proprio remedio: "cloreto de potassio", "carbonato de
# litio", "citrato de potassio" ficam inteiros.
CATIONS = {
    'sódio', 'potássio', 'cálcio', 'magnésio', 'zinco', 'lítio', 'ferro',
    'alumínio', 'amônio', 'prata', 'cobre', 'manganês', 'selênio', 'cromo',
}
ANIONS_SIMPLES = {
    'cloreto', 'carbonato', 'bicarbonato', 'citrato', 'fosfato', 'sulfato',
    'gliconato', 'gluconato', 'lactato', 'acetato', 'óxido', 'hidróxido',
    'iodeto', 'fluoreto', 'nitrato', 'borato', 'tetraborato', 'silicato',
    'perborato', 'tiossulfato', 'glicerofosfato', 'picossulfato',
}
# Grafias diferentes do mesmo farmaco.
SINONIMOS = {
    'n-butilescopolamina': 'escopolamina',
    'butilescopolamina': 'escopolamina',
    'ácido acetilsalicilsalicílico': 'ácido acetilsalicílico',
}
# Siglas que ficam em maiusculas mesmo com vogal.
SIGLAS = {'aas'}
MINUSCULAS = {
    'de', 'da', 'do', 'das', 'dos', 'e', 'com', 'sem', 'em', 'para', 'a', 'o',
    'as', 'os', 'por', 'ao', 'na', 'no',
}


def sem_acento(texto):
    return ''.join(c for c in unicodedata.normalize('NFD', texto)
                   if unicodedata.category(c) != 'Mn')


def chave(texto):
    return re.sub(r'[^a-z0-9]+', ' ', sem_acento(texto.lower())).strip()


def limpar(texto):
    """Nome do produto: sem entidades HTML, sem o que esta entre parenteses
    ("(port. 344/98 - lista B1)"), sem o simbolo de marca registrada."""
    texto = html.unescape(texto).replace(' ', ' ')
    texto = re.sub(r'\([^)]*\)?', ' ', texto)
    texto = texto.replace('®', ' ').replace('™', ' ')
    texto = re.sub(r'\s*\+\s*', ' + ', texto)
    texto = re.sub(r'\s+', ' ', texto).strip()
    return texto.strip(' -.,;')


def substancia_base(texto):
    """'cloridrato de metformina' -> 'metformina'; 'dipirona monoidratada' ->
    'dipirona'. A alergia compara por este nome."""
    texto = html.unescape(texto).lower().replace(' ', ' ')
    texto = re.sub(r'\([^)]*\)?', ' ', texto)
    palavras = texto.split()
    if not palavras:
        return ''
    # Nome botanico com autor ("valeriana officinalis l."): genero e especie.
    if len(palavras) >= 3 and (
            any(p.endswith('.') for p in palavras[2:]) or palavras[2] == 'l'):
        palavras = palavras[:2]
    palavras = [p.strip(',;.') for p in palavras if p.strip(',;.')]
    if not palavras:
        return ''
    palavras = [p for p in palavras if not HIDRATO.match(p)] or palavras
    resto = [p for p in palavras if not CATION_ADJETIVO.match(p)]
    if resto:
        palavras = resto
    resto = [p for p in palavras if p not in SUFIXOS]
    if resto:
        palavras = resto
    # "montelucaste de sodio" -> "montelucaste"
    if (len(palavras) >= 3 and palavras[-2] == 'de'
            and palavras[-1] in CATIONS
            and ' '.join(palavras[:-2]) not in ANIONS_SIMPLES):
        palavras = palavras[:-2]
    # "besilato de anlodipino" -> "anlodipino"
    if (len(palavras) >= 3 and palavras[0] in SAIS and palavras[1] == 'de'
            and ' '.join(palavras[2:]) not in CATIONS):
        palavras = palavras[2:]
    base = ' '.join(palavras).strip(' -.,;')
    return SINONIMOS.get(base, base)


def palavra_em_caixa(palavra, primeira, titulo):
    if any(c.isdigit() for c in palavra):
        return palavra.upper()
    if len(palavra) == 1 and palavra.isalpha():
        return palavra.upper()
    minuscula = palavra.lower()
    if not primeira and minuscula in MINUSCULAS:
        return minuscula
    sem_vogal = not any(c in 'aeiouyáéíóúâêôãõà' for c in minuscula)
    if titulo and palavra.isalpha() and (sem_vogal or minuscula in SIGLAS):
        return palavra.upper()
    if titulo or primeira:
        return '-'.join(p[:1].upper() + p[1:] for p in minuscula.split('-'))
    return minuscula


def nome_de_exibicao(nome, generico):
    """Generico (o nome e o principio ativo) sai como frase: 'Losartana
    potassica + hidroclorotiazida'. Marca sai como titulo: 'Novalgina Flash',
    com siglas e numeros em maiusculas ('Glifage XR', 'Puran T4', 'AAS')."""
    palavras = nome.split(' ')
    return ' '.join(
        palavra_em_caixa(p, i == 0, not generico)
        for i, p in enumerate(palavras))


def acentos(texto):
    return sum(1 for c in texto if ord(c) > 127)


def gerar(caminho_csv):
    # O arquivo vem em Windows-1252 (o travessao e 0x96).
    texto = open(caminho_csv, 'rb').read().decode('cp1252', errors='replace')
    linhas = csv.DictReader(io.StringIO(texto), delimiter=';')

    grafias = collections.defaultdict(collections.Counter)
    genericos = collections.Counter()
    substancias = collections.defaultdict(collections.Counter)
    for linha in linhas:
        if linha['SITUACAO_REGISTRO'] != 'Ativo':
            continue
        if linha['TIPO_PRODUTO'] != 'MEDICAMENTO':
            continue
        categoria = linha['CATEGORIA_REGULATORIA'].replace('?', 'Á')
        if categoria not in CATEGORIAS:
            continue
        nome = limpar(linha['NOME_PRODUTO'])
        if (not nome or '?' in nome or '�' in nome
                or 'DECLARADO' in nome.upper()):
            continue
        k = chave(nome)
        # Registros de teste da propria Anvisa ("TESTE", "ASDFASDF").
        if not k or k.startswith('teste') or k.startswith('asdf'):
            continue
        grafias[k][nome] += 1
        if categoria == 'Genérico':
            genericos[k] += 1
        for parte in linha['PRINCIPIO_ATIVO'].split(','):
            base = substancia_base(parte)
            if base:
                substancias[k][base] += 1

    # Uma grafia so por substancia no catalogo todo: a com acento ("acido
    # acetilsalicilico" vira "acido acetilsalicilico" acentuado) e, entre as
    # iguais, a mais usada.
    grafias_substancia = collections.defaultdict(collections.Counter)
    for contagem in substancias.values():
        for base, vezes in contagem.items():
            grafias_substancia[chave(base)][base] += vezes
    melhor_substancia = {
        k: max(g.items(), key=lambda item: (acentos(item[0]), item[1]))[0]
        for k, g in grafias_substancia.items()
    }

    catalogo = []
    for k in sorted(grafias):
        # A grafia com acento ("POTASSICA" x "POTÁSSICA"), e entre as iguais a
        # mais usada.
        nome = max(grafias[k].items(), key=lambda g: (acentos(g[0]), g[1]))[0]
        exibir = nome_de_exibicao(nome, genericos[k] > 0)
        lista = []
        for base, _ in sorted(substancias[k].items(),
                              key=lambda s: (-s[1], s[0])):
            base = melhor_substancia[chave(base)]
            exibir_base = base[:1].upper() + base[1:]
            if exibir_base not in lista:
                lista.append(exibir_base)
        catalogo.append({'nome': exibir, 'substancias': lista})
    return catalogo


if __name__ == '__main__':
    entrada, saida = sys.argv[1], sys.argv[2]
    catalogo = gerar(entrada)
    with open(saida, 'w', encoding='utf-8') as arquivo:
        json.dump(catalogo, arquivo, ensure_ascii=False, separators=(',', ':'))
        arquivo.write('\n')
    print(f'{len(catalogo)} remedios em {saida}')
