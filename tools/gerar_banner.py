#!/usr/bin/env python3
"""Gera o banner da notificação "Jogo da Noite" (Desafio 2).

Mesmo desenho do CabecalhoConfronto do app (lib/widgets/cabecalho_confronto.dart):
gradiente da cor do mandante (esquerda) para a do visitante (direita), logo em
círculo branco, sigla e nome de cada time, "x" no centro e o horário embaixo.
As logos são opcionais: sem elas, o banner fica só com texto e cor.

Exemplo:
    python3 tools/gerar_banner.py --mandante "Boston Celtics" \\
        --visitante "Los Angeles Lakers" --quando "Hoje, 21h30" \\
        --cor-mandante "#007A33" --cor-visitante "#552583" \\
        --sigla-mandante BOS --sigla-visitante LAL \\
        --logo-mandante https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/bos.png \\
        --logo-visitante https://a.espncdn.com/i/teamlogos/nba/500/scoreboard/lal.png \\
        --saida assets/banners/jogo_da_noite.png

Requer Pillow (pip install pillow).
"""

import argparse
import io
import os
import re
import sys
import urllib.request

from PIL import Image, ImageDraw, ImageFont

LARGURA, ALTURA = 1024, 512  # 2:1, bom para a notificação expandida no Android
LIMITE_BYTES = 1024 * 1024  # limite do FCM para imagens de notificação

# Cores oficiais da NBA (as mesmas de lib/tema.dart). Sem as cores dos times,
# o banner usa o azul e o vermelho da NBA, como o CabecalhoConfronto.
NBA_AZUL = "#1D428A"
NBA_VERMELHO = "#C8102E"

BRANCO = (255, 255, 255)
SOMBRA = (0, 0, 0, 90)

DIAMETRO_LOGO = 176  # círculo branco; a logo ocupa a parte interna
MARGEM_LOGO = 20

FONTES_NEGRITO = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",  # macOS
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",  # Linux
    "C:/Windows/Fonts/arialbd.ttf",  # Windows
]
FONTES_REGULAR = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "C:/Windows/Fonts/arial.ttf",
]


def fonte(tamanho, negrito=False):
    for caminho in FONTES_NEGRITO if negrito else FONTES_REGULAR:
        if os.path.exists(caminho):
            return ImageFont.truetype(caminho, tamanho)
    # Fonte embutida do Pillow (>= 10.1), para não depender do sistema.
    return ImageFont.load_default(size=tamanho)


def cor_rgb(hexa, padrao):
    valor = (hexa or padrao).lstrip("#")
    if not re.fullmatch(r"[0-9a-fA-F]{6}", valor):
        raise argparse.ArgumentTypeError(f"cor inválida: {hexa!r} (use #RRGGBB)")
    return tuple(int(valor[i : i + 2], 16) for i in (0, 2, 4))


def gradiente(cor_esquerda, cor_direita):
    imagem = Image.new("RGB", (LARGURA, ALTURA))
    desenho = ImageDraw.Draw(imagem)
    for x in range(LARGURA):
        t = x / (LARGURA - 1)
        cor = tuple(round(a + (b - a) * t) for a, b in zip(cor_esquerda, cor_direita))
        desenho.line([(x, 0), (x, ALTURA)], fill=cor)
    return imagem


def largura_texto(desenho, texto, fonte_):
    esquerda, _, direita, _ = desenho.textbbox((0, 0), texto, font=fonte_)
    return direita - esquerda


def quebrar(desenho, texto, largura_max, tamanho_inicial, tamanho_min=28):
    """Quebra o nome em até 2 linhas, diminuindo a fonte até caber."""
    for tamanho in range(tamanho_inicial, tamanho_min - 1, -2):
        f = fonte(tamanho)
        if largura_texto(desenho, texto, f) <= largura_max:
            return [texto], f
        palavras = texto.split()
        for corte in range(len(palavras) - 1, 0, -1):
            linhas = [" ".join(palavras[:corte]), " ".join(palavras[corte:])]
            if all(largura_texto(desenho, l, f) <= largura_max for l in linhas):
                return linhas, f
    return [texto], fonte(tamanho_min)


def escrever(desenho, xy, texto, fonte_, ancora):
    """Texto branco com uma sombra leve, legível sobre cores claras."""
    x, y = xy
    desenho.text((x + 2, y + 3), texto, font=fonte_, fill=SOMBRA, anchor=ancora)
    desenho.text((x, y), texto, font=fonte_, fill=BRANCO, anchor=ancora)


def carregar_logo(origem):
    """Abre a logo de uma URL https ou de um arquivo local."""
    try:
        if origem.startswith("https://"):
            pedido = urllib.request.Request(
                origem, headers={"User-Agent": "gerar_banner"}
            )
            with urllib.request.urlopen(pedido, timeout=15) as resposta:
                dados = io.BytesIO(resposta.read())
            return Image.open(dados).convert("RGBA")
        return Image.open(origem).convert("RGBA")
    except (OSError, ValueError) as erro:
        sys.exit(f"ERRO: não foi possível abrir a logo {origem!r}: {erro}")


def selo_logo(logo):
    """Logo centralizada num círculo branco, como no cabeçalho do app."""
    # Desenha maior e reduz, para a borda do círculo não ficar serrilhada.
    escala = 4
    grande = DIAMETRO_LOGO * escala
    selo = Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
    ImageDraw.Draw(selo).ellipse((0, 0, grande - 1, grande - 1), fill=BRANCO)
    selo = selo.resize((DIAMETRO_LOGO, DIAMETRO_LOGO), Image.LANCZOS)

    # Sem as margens transparentes, todas as logos ficam do mesmo tamanho.
    recorte = logo.crop(logo.getbbox())
    interno = DIAMETRO_LOGO - 2 * MARGEM_LOGO
    fator = interno / max(recorte.size)
    tamanho = tuple(max(1, round(lado * fator)) for lado in recorte.size)
    recorte = recorte.resize(tamanho, Image.LANCZOS)
    posicao = tuple((DIAMETRO_LOGO - lado) // 2 for lado in tamanho)
    selo.alpha_composite(recorte, posicao)
    return selo


def desenhar_time(
    camada, desenho, nome, sigla, logo, x, alinhamento, topo, largura_max
):
    # "l" alinha à esquerda (mandante); "r", à direita (visitante).
    y = topo
    if logo:
        selo = selo_logo(carregar_logo(logo))
        esquerda = x if alinhamento == "l" else x - DIAMETRO_LOGO
        camada.alpha_composite(selo, (esquerda, y))
        y += DIAMETRO_LOGO + 12
    if sigla:
        f_sigla = fonte(72 if logo else 112, negrito=True)
        escrever(desenho, (x, y), sigla.upper(), f_sigla, alinhamento + "t")
        y += 84 if logo else 128
    tamanho_nome = 36 if logo else 48 if sigla else 64
    linhas, f_nome = quebrar(desenho, nome, largura_max, tamanho_nome, 26)
    altura_linha = f_nome.size + 8
    for linha in linhas:
        escrever(desenho, (x, y), linha, f_nome, alinhamento + "t")
        y += altura_linha
    return y


def gerar(args):
    imagem = gradiente(
        cor_rgb(args.cor_mandante, NBA_AZUL),
        cor_rgb(args.cor_visitante, NBA_VERMELHO),
    ).convert("RGBA")
    camada = Image.new("RGBA", imagem.size, (0, 0, 0, 0))
    desenho = ImageDraw.Draw(camada)

    margem = 64
    meio = LARGURA // 2
    largura_time = meio - margem - 70  # deixa espaço para o "x"
    if args.logo_mandante or args.logo_visitante:
        topo = 32
    elif args.sigla_mandante or args.sigla_visitante:
        topo = 110
    else:
        topo = 150

    fim_mandante = desenhar_time(
        camada, desenho, args.mandante, args.sigla_mandante, args.logo_mandante,
        margem, "l", topo, largura_time,
    )
    fim_visitante = desenhar_time(
        camada, desenho, args.visitante, args.sigla_visitante, args.logo_visitante,
        LARGURA - margem, "r", topo, largura_time,
    )

    altura_bloco = max(fim_mandante, fim_visitante) - topo
    escrever(desenho, (meio, topo + altura_bloco / 2), "x", fonte(80), "mm")

    if args.quando:
        y_quando = ALTURA - (48 if args.logo_mandante or args.logo_visitante else 70)
        escrever(desenho, (meio, y_quando), args.quando, fonte(44, True), "mm")

    Image.alpha_composite(imagem, camada).convert("RGB").save(
        args.saida, "PNG", optimize=True
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--mandante", required=True, help='ex.: "Boston Celtics"')
    parser.add_argument("--visitante", required=True, help='ex.: "Los Angeles Lakers"')
    parser.add_argument("--quando", default="", help='ex.: "Hoje, 21h30"')
    parser.add_argument("--cor-mandante", help="#RRGGBB; azul da NBA se omitida")
    parser.add_argument(
        "--cor-visitante", help="#RRGGBB; vermelho da NBA se omitida"
    )
    parser.add_argument("--sigla-mandante", help="ex.: BOS (opcional)")
    parser.add_argument("--sigla-visitante", help="ex.: LAL (opcional)")
    parser.add_argument("--logo-mandante", help="URL https ou arquivo (opcional)")
    parser.add_argument("--logo-visitante", help="URL https ou arquivo (opcional)")
    parser.add_argument("--saida", required=True, help="caminho do PNG gerado")
    args = parser.parse_args()

    for cor in (args.cor_mandante, args.cor_visitante):
        if cor is not None:
            try:
                cor_rgb(cor, None)
            except argparse.ArgumentTypeError as erro:
                parser.error(str(erro))

    pasta = os.path.dirname(args.saida)
    if pasta:
        os.makedirs(pasta, exist_ok=True)
    gerar(args)

    tamanho = os.path.getsize(args.saida)
    if tamanho > LIMITE_BYTES:
        os.remove(args.saida)
        sys.exit(
            f"ERRO: o banner ficou com {tamanho / 1024:.0f} KB, acima do limite "
            f"de 1 MB do FCM. Arquivo removido."
        )
    print(f"Banner gerado: {args.saida} ({LARGURA}x{ALTURA}, {tamanho / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
