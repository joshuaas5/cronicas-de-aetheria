# Crônicas de Aetheria

RPG de ação medieval com magia, feito em Godot 4.7. Cenários com assets escaneados e texturas PBR do Poly Haven, personagens 3D estilizados da KayKit, música e efeitos sintetizados pelo próprio projeto.

## Como jogar

- **Executável:** `build/Aetheria.exe` (Windows, 64 bits).
- **Pelo editor:** abra a pasta no Godot 4.7 e aperte F5, ou rode `abrir_no_godot.bat`.

| Ação | Teclado | Controle |
| --- | --- | --- |
| Mover | WASD / setas | Analógico esquerdo / direcional |
| Espada (combo de 3 golpes) | J | X |
| Magia | K | Y |
| Esquiva (invencível durante o rolamento) | L / Shift | B |
| Trocar magia | Q / E | LB / RB |
| Poção | R | Back |
| Falar / confirmar | Espaço / Enter | A |
| Árvore de Mana | T | L3 |
| Pausa | Esc | Start |
| Som liga/desliga | M | — |

## Progressão

- **Árvore de Mana (T):** cada nível dá 1 Essência, e chefes dão mais. Três galhos (Espada, Magia, Vida), com 15 habilidades: críticos, giro, investida, quarto golpe, Chama Voraz, Nevasca, a magia Relâmpago, Eco Arcano, regeneração, espinhos e Renascer.
- **Vocações:** Cavaleiro, Ladina, Bárbaro e Mago, liberadas pela história e trocadas no Altar das Vocações, na praça da vila.
- **Forja:** depois que o bosque é plantado, o ferreiro Ferro chega à vila e forja cinco níveis de arma.

## A história

A Árvore de Mana está murchando. Fale com o Ancião Bram na Vila Lumen, plante a Semente Verdejante no mapa do mundo, atravesse o Bosque Sussurrante, derrote o Carvalho Ancião Corrompido e leve a Lágrima da Lua até o Santuário de Mana.

## Qualidade gráfica

O padrão é **Ultra**, pensado para placas como a RX 9600 XT: iluminação global SDFGI, SSIL, sombras suaves, névoa volumétrica e grama densa. No título ou na pausa dá para alternar entre **Baixa**, **Alta** e **Ultra**. A mudança vale a partir da próxima área carregada e fica salva.

## Estrutura

- `scripts/` — jogo: `main.gd` (fluxo), `player.gd`, `enemy.gd`, `boss.gd`, `ui.gd`, `story.gd` (todas as falas), `env.gd` (terreno, grama, árvores, céu), `build.gd` (arquitetura), `levels/` (vila, taverna, bosque, clareira, santuário, mapa).
- `shaders/` — terreno com mistura de 4 texturas, grama com vento que reage ao jogador, folhas fotográficas recortadas.
- `tools/` — scripts que regeneram os assets:
  - `node tools/fetch_assets.js` baixa os modelos, texturas e céus do Poly Haven.
  - `python tools/make_foliage.py` monta as texturas de folhas e flores a partir das folhas escaneadas.
  - `node tools/make_audio.js` sintetiza músicas, ambiências e efeitos.
  - `godot --path . -- --level=forest1 --shot=saida.png` renderiza uma captura de qualquer área (veja o topo de `scripts/main.gd` para todos os parâmetros de teste).

## Versão web 2D

`web/aetheria-2d.html` é o protótipo original em pixel art, que roda direto no navegador.

## Créditos e licenças

- **Modelos, texturas e HDRIs:** [Poly Haven](https://polyhaven.com), CC0.
- **Personagens e esqueletos:** KayKit Adventurers e Skeletons, de Kay Lousberg ([kaylousberg.com](https://www.kaylousberg.com)), CC0.
- **Fontes:** Uncial Antiqua e Alegreya, SIL Open Font License (arquivos em `assets/fonts/`).
- **Música, efeitos, código e texturas geradas:** criados para este projeto.
