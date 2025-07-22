
; Este código em Assembly implementa o estágio 3 do bootloader. O estágio 3 consiste no programa que
; carregaria o kernel do sistema operacional. Como não há sistema operacional, implementei o jogo da
; cobrinha, por ser um jogo de lógica extremamente simples e relativamente fácil de entender o 
; código-fonte. Usei como base o código-fonte disponível na página do GitHub disponível pelo endereço:
;
; https://gist.github.com/majkrzak/d75a5b90b3735edd53ac
;
; Uma versão em linguagem C do mesmo jogo se encontra no diretório do projeto, com o nome do arquivo
; denominado de snake.c.


[BITS 16]                     ; O programa do estágio 3 roda em modo real de 16 bits.
[ORG 0x8200]                  ; O programa será executado no endereço 0x8200.




; Constantes que são definidas com base nos 4 bits menos significativos do byte. Representam o tipo
; de célula no mapa do jogo.

%define EMPTY 0b00000000      ; Constante que representa um espaço vazio no mapa.
%define SNAKE 0b00000001      ; Constante que representa uma parte da cobrinha no mapa.
%define FRUIT 0b00000010      ; Constante que representa uma fruta no mapa.
%define EATEN 0b00000100      ; Constante que representa uma fruta comida no mapa.
%define WRECK 0b00001000      ; Constante que representa uma posição de colisão no mapa.

; Constantes que são definidas com base nos 4 bits mais significativos do byte. Representam a direção
; da cobrinha.

%define UP    0b00010000      ; Constante que representa direção para cima.
%define DOWN  0b00100000      ; Constante que representa direção para baixo.
%define LEFT  0b01000000      ; Constante que representa direção para esquerda.
%define RIGHT 0b10000000      ; Constante que representa direção para direita.

; Constantes que representam índices da paleta de cores do VGA, para a renderização do mapa do jogo
; na tela do computador. O esquema de cores original foi mantido, apenas alterando-se a tonalidade
; das cores, para obter um melhor contraste. Para ver a paleta completa de cores com seus respectivos
; índices, você pode acessar o site https://www.fountainware.com/EXPL/vga_color_palettes.htm.

%define EMPTY_COLOR 0x2F      ; Constante que define a cor para célula vazia.
%define SNAKE_COLOR 0x01      ; Constante que define a cor para a cobrinha.
%define FRUIT_COLOR 0x28      ; Constante que define a cor para a fruta.
%define EATEN_COLOR 0x26      ; Constante que define a cor para a fruta comida.
%define WRECK_COLOR 0x00      ; Constante que define a cor da cabeça da cobrinha na colisão.

; Variáveis definidas com base no endereço do segmento de dados extras apontado pelo registrador ES
; (0x8A00). Representam o mapa, ponteiros, contadores e outros elementos lógicos do jogo.

%define map(i) byte [es:i   ] ; Mapa do jogo, um arranjo com 1024 bytes (i = 0 ... 1023). 
%define hptr   word [es:1024] ; Ponteiro para o índice da célula atual da "cabeça" (head pointer).
%define tptr   word [es:1026] ; Ponteiro para o índice da célula atual da "cauda" (tail pointer).
%define fptr   word [es:1028] ; Ponteiro para o índice da célula atual da "fruta" (fruit pointer).
%define fctr   word [es:1030] ; Contador de tempo de vida da fruta (fruit counter).
%define temp   byte [es:1032] ; Variável que armazena valores temporários (temporary).
%define cctr   byte [es:1033] ; Contador de ciclos de relógio (cycles counter).
%define scor   word [es:1034] ; Pontuação do jogo (score).
%define rand   word [es:1036] ; Número gerado de modo pseudo-aleatório (random).
%define wcyc   byte [es:1038] ; Ciclo de espera (waiting cycle).
%define ftim   word [es:1039] ; Tempo de vida da fruta (fruit time).




; Salta para o ponto de entrada do programa.

jmp start




; Esta função está registrada na tabela de vetores de interrupção (IVT) para ser executada sempre
; que uma interrupção de relógio é lançada (INT 0x08). Sua função é realizar a lógica do jogo e 
; atualizar o gráfico na tela.
;
; O estilo original de assembly do autor, por exemplo, usando "jz $+3", foi mantido, pois o código
; fica mais legível do que criando mais rótulos locais, apesar de demandar um recálculo toda vez que
; é inserida mais alguma instrução, haja vista que esta desalinha as instruções posteriores a ela.
;
; Ao ler os comentários para ententer a lógica do jogo, considere os seguintes termos:
;
;
; * Ciclo de relógio: A cada "toque" do relógio, que ocorre de 50 em 50 milissegundos (20 Hz), esta 
;   função é executada.
;
;
; * Nível de dificuldade: O jogo original foi alterado para que possa oferecer 4 níveis de dificuldade.
;   Nos níveis de dificuldade 1 e 2 a cobrinha se move mais rápido, oferecendo tempo menor para tomada
;   de decisão, e maior dificuldade de se posicionar para alcançar a fruta. Nos níveis 3 e 4 a cobrinha
;   se move mais lentamente, dando mais tempo para a tomada de decisão e tornando mais fácil posicionar
;   para alcançar a fruta. O controle da velocidade da cobrinha é feito alterando-se o valor do ciclo
;   de espera para mais ou menos ciclos de relógio.
;
;
; * Ciclo de espera: O ciclo de espera é o número de ciclos de relógio sem executar instruções e nem
;   atualizar o mapa na tela, regulando a velocidade da cobrinha. O mínimo de ciclos de relógio é 1,
;   e o máximo é 4, sendo 1 a velocidade mais rápida e 4 a velocidade mais lenta. O tempo de vida da 
;   fruta deve ser configurado para que, independentemente do ciclo de espera configurado, ela fique
;   sempre por 10 segundos na mesma posição no mapa.
;  
;
; * Ciclo de instruções: O ciclo de instruções ocorre ao final de um ciclo de espera. Por exemplo, 
;   considere um ciclo de espera, wcyc, de 2 ciclos de relógio. Isto significa que o primeiro tick
;   do relógio é ignorado, apenas adicionando 1 ao contador de ciclos cctr. No segundo tick, o valor
;   do contador passa a ser 2, que é igual ao valor de ciclo de espera wcyc. Neste caso, o contador 
;   é zerado para iniciar de novo o ciclo de espera, e as instruções do jogo e para a atualização da
;   tela são executadas. O momento em que isto acontece é o que eu denominei de ciclo de instruções,
;   que neste caso específico, acontece no segundo ciclo de relógio, ou seja, a cada 100 ms.
;
;
; * Mapa do jogo: O mapa do jogo, representado pela variável map, é um array de bytes com 1024 posições, 
;   representando um quadrado de 32x32 posições. O byte inicial está no offset 0x0 do segmento de
;   dados extras apontado pelo registrador ES, que está configurado para o endereço 0x8A00. O byte 
;   final está no offset 1023 do segmento.
;
;
;                                       ┌──────────────────┐ ┬
;                                       │                  │ │
;                                       │                  │ │
;                                       │                  │ │
;                                       │                  │ │  32
;                                       │                  │ │
;                                       │                  │ │
;                                       │                  │ │
;                                       └──────────────────┘ ┴
;                                       ├──────────────────┤
;                                                32
;
;
;   Cada célula no arranjo map vai ter escrito nela um destes 5 valores, que identificam o seu tipo: 
;
;   EMPTY: Representa célula vazia, que não é parte do corpo da cobrinha nem é fruta/fruta comida. Seu
;   valor é 0b00000000.
;   
;   SNAKE: Representa uma célula que contém uma parte do corpo da cobrinha. O byte de SNAKE terá duas
;   informações:
;   
;   > O bit de direção do movimento da cobrinha no momento em que a cabeça passou por aquela posição,
;     indicado por um dos 4 bits mais significativos ativado (valor = 1).
;
;   > O bit de SNAKE, ativado nos 4 bits menos significativos.
;
;   Exemplo:
;  
;   Considere que o byte na célula que está marcada como SNAKE têm os seguintes bits:
;
;                                     0  0  1  0  0  0  0  1
;
;   Para calcular a direção e extrair o bit de SNAKE, deve-se dividir o byte em duas partes. A primeira
;   parte, consistindo nos 4 primeiros bits (bits mais significativos), contém o bit de direção. A 
;   segunda parte, consistindo nos quatro últimos bits (bits menos significativos), contém o bit de
;   SNAKE. 
;
;
;                                     ├────────┤  ├────────┤
;                                     0  0  1  0  0  0  0  1 . . . . bit de
;                                     |     .              |         SNAKE
;                                    MSB    .             LSB
;                                           .
;                                           . 
;                                        Bit da
;                                        direção
;                                        (DOWN)
;
;
;   A direção (DOWN) é simbolizada pelo bit ativado mais próximo do MSB (Most Significant Bit - Dígito
;   Mais Significativo), e o bit ativado no LSB (Least Significant Bit - Bit Menos Significativo)
;   simboliza SNAKE.
;
;   Estes valores são obtidos da junção entre DOWN e SNAKE, aplicando uma operaçao OR bit a bit, desta
;   forma:
;
;
;                                          ┌─┐            ┌─┐
;                                     0  0 │1│ 0  0  0  0 │0│      <-- Constante DOWN
;                                     0  0 │0│ 0  0  0  0 │1│      <-- Constante SNAKE
;                                     -----│-│------------│-│ 
;                                     0  0 │1│ 0  0  0  0 │1│      <-- DOWN|SNAKE (OR bit a bit)
;                                          └─┘            └─┘
;
;
;   A direção nos bits mais significativos pode ser UP, DOWN, LEFT ou RIGHT (veja valores nas constantes
;   acima), fazendo uma célula com SNAKE ter o byte 00010001, 00100001, 01000001 ou 10000001.
;
;   Ter duas informações no mesmo byte é necessário para que a cauda faça o mesmo trajeto que a cabeça
;   fez, produzindo o efeito de rastejar da cobrinha na tela.
;
;   FRUIT: Representa uma célula que contém a fruta. Seu valor é 0b00000010.
;
;   EATEN: Representa uma célula que contém a fruta comida. Neste caso, ela vai se "mover" pelo corpo 
;   até chegar na cauda, quando então vai ser incorporada como a nova cauda, fazendo a cobrinha aumentar
;   de tamanho. O valor do byte na célula com EATEN também é formado pela junção entre direção e EATEN, 
;   da mesma forma que foi demonstrado no exemplo de SNAKE (Exemplo: 10000100).
;
;   WRECK: Representa uma célula em que houve a colisão da cabeça da cobrinha com uma parte de seu 
;   próprio corpo. Seu valor é 0b00001000.
;
; Algumas variáveis também são necessárias para que o estado do jogo seja controlado. As principais  
; destas variáveis são os ponteiros, que assim como ponteiros em linguagens de alto nível, como C/C++, 
; tem a função de apontar para endereços de memória. No caso deste programa, os endereços de memória 
; apontados são células do arranjo map, mais especificamente, offsets no segmento de dados extras
; apontado pelo registrador ES.
;
; Os ponteiros para map são:
;
;   hptr (head pointer): Ponteiro que aponta para a célula que é a cabeça da cobrinha em map.
;
;   tptr (tail pointer): Ponteiro que aponta para a célula que é a cauda da cobrinha em map.
;
;   fptr (fruit pointer): Ponteiro que aponta para a célula que contém a fruta em map.
;
; O espaço de memória reservado para estas variáveis são contíguos ao arranjo map, a partir do offset
; 1024 do segmento.
;
;
; EXECUÇÃO DAS INSTRUÇÕES DO JOGO
; 
;
; Quando o ciclo de instruções é executado após o final de um ciclo de espera, as seguintes etapas são 
; realizadas, nesta ordem:
;
;   > Move a cabeça da cobrinha uma célula na direção definida nos bits mais significativos de seu byte.
;
;   > Move a cauda da cobrinha uma célula na direção definida nos bits mais significativos de seu byte.
;
;   > Verifica se expirou o tempo de vida da fruta, e se sim, move a mesma para uma nova posição que
;     está vazia.
;
;   > Renderiza o mapa do jogo na tela.
;
;   Se a cabeça da cobrinha colidiu com alguma parte de seu próprio corpo, bloqueia o jogo. 
; 
;   Se a cobrinha devorou a fruta, incrementa o placar do jogo e aumenta o tamanho do seu corpo quando
;   a fruta comida chegar à cauda. 
;
; Para entender como isso funciona, considere a seguinte configuração inicial do mapa:
;
;
;                                       ┌──────────────────┐
;                                       │                  │
;                      Cabeça (hptr) . . . . ■ ■ ■         │
;                      byte: 01000001   |        ■         │
;                                       │        ■         │
;                                       │        ■         │
;                                       │        ■         │
;                                       │        .         │
;                                       └─────── . ────────┘
;                                                .
;                                                .
;                                              Cauda (tptr)
;                                              byte: 00010001
;
;
; Os quadrados representam partes do corpo da cobrinha. O ponteiro para a cabeça (hptr) aponta para
; uma célula que contém o byte 01000001. Sabemos que este valor representa direção para esquerda e 
; cobra (LEFT/SNAKE), pelos bits que estão ativados. Se o jogador teclar uma seta que indica para outra
; direção, esta nova direção será gravada nos bits mais significativos enquanto a cabeça ainda está
; nesta posição, pois é ela que guia o movimento do restante do corpo, que é controlado pelo jogador.
;
; Para mover a cabeça para a próxima célula durante o ciclo de instruções, primeiramente será lida a
; célula na posição atual desta e extraída a informação de direção chamando a função movement. A 
; função transforma o índice linear do ponteiro da cabeça hptr em coordenadas X, Y de uma matrix, e
; altera o valor de X ou de Y, de acordo com a direção lida, voltando a tranformar os índice X e Y em
; índice linear. A função movement garante também que se a cabeça da cobrinha ultrapassar a borda do
; mapa, ela realize um "teletransporte" para a borda oposta, na mesma linha ou coluna do sentido do 
; movimento.
;
;
;                                       ┌──────────────────┐
;                                       │                  │
;                       Nova posição . . . ░ ■ ■ ■         │
;                       da cabeça       |        ■         │
;                       calculada em    │        ■         │
;                       movement        │        ■         │
;                                       │        ■         │
;                                       │                  │
;                                       └──────────────────┘
;
;
; Determinada a nova posição para onde a cabeça vai se mover, se for uma célula vazia (EMPTY), grava
; nos bits mais significativos a direção atual da cabeça, e nos bits menos significativos SNAKE. Também
; atualiza o ponteiro hptr, de forma a indicar o índice da nova célula no mapa.
;
;
;                                       ┌──────────────────┐
;                                       │ ┌─┐              │
;                       A posição da . . .|■|■ ■ ■         │
;                       cabeça passa    | └─┘    ■         │
;                       a ser a nova    │        ■         │
;                       célula calcu-   │        ■         │
;                       lada por        │        ■         │
;                       movement        │                  │
;                                       └──────────────────┘
;
;
; Se a célula para onde a cabeça deve se mover não está vazia, duas situações podem ocorrer:
; 
; Colisão: A célula para onde a cabeça da cobrinha deve se mover contém uma parte do seu próprio corpo
; ou uma fruta devorada. Neste caso, a célula na posição atual da cabeça é marcada como WRECK, e o jogo
; pára.
;
;
;                                       ┌──────────────────┐
;                                       │                  │
;                                       │     ■ ■ ■ ■      │
;                                       │     ■  ┌─┐■      │
;                                       │     ■ ■│■│■      │
;                                       │       .└─┘■      │
;                                       │     .     ■      │
;                                       │   .              │
;                                       └ . ───────────────┘
;                                    	.
;                             A cabeça colidiu com o corpo. Quando
;                             isto acontece, marca a célula da cabeça
;                             como WRECK (byte: 0b00001000), o que
;                             pára o jogo.
;
;
; Pontuação: A célula para onde a cabeça da cobrinha vai se mover contém a fruta. Neste caso, incrementa
; a pontuação no placar e move o ponteiro hptr para a nova célula, marcando os bits menos significativos
; desta como fruta comida (EATEN).
;
; Na sequência ao movimento da cabeça da cobrinha, deve-se calcular a nova posição da cauda, que deve
; seguir o trajeto feito pela cabeça no percurso. O processo é semelhante ao que foi feito para mover
; a cabeça. Calcula-se as novas coordenadas da cauda com base na direção apontada pelos bits mais 
; significativos do byte desta, que no caso é UP, pois o byte da cauda é 00010001, e verifica se este 
; byte contém SNAKE nos bits menos significativos (no caso, sim).
;
;
;                                       ┌──────────────────┐
;                                       │                  │
;                                       │  ■ ■ ■ ■         │
;                                       │        ■         │
;                                       │        ■         │
;                                       │        ■ ¦----------- Nova posição da cauda
;                                       │        ■         |    calculada em movement
;                                       │                  │
;                                       └──────────────────┘
;
;                    
; Se a célula na posição atual da cauda contém SNAKE, marca a célula como EMPTY e atualiza o ponteiro
; tptr para a nova célula calculada em movement. Também aqui a cauda será teletransportada se a posição
; apontada utrapassar os limites da borda do mapa, seguindo o mesmo trajeto feito pela cabeça ao passar
; por aquela célula. Isso faz a cauda se mover, acompanhando o movimento da cabeça.
;
;
;                                       ┌──────────────────┐
;                                       │                  │
;                                       │  ■ ■ ■ ■         │
;                                       │        ■         │
;                                       │        ■         │
;                                       │        ■         │
;                                       │        ×         │
;                                       │        .         │
;                                       └─────── . ────────┘
;                                                .
;                                                .
;                                     A cauda atual é apagada
;                                     e tptr passa a apontar
;                                     para a célula calculada
;                                     em movement
;
;
; Se a célula apontada na posição atual da cauda é EATEN ou EMPTY, esta será transformada em SNAKE, e
; o ponteiro tptr não é alterado, pois a célula transformada passa a ser a nova cauda. Como se criou 
; uma nova parte da cobrinha a partir de uma célula vazia ou fruta comida, o tamanho do corpo desta
; é aumentado em uma unidade. O diagrama abaixo mostra como funciona este processo.
;
;
;                         ┌──────────────────┐     ┌──────────────────┐   
;       Fruta comida .    │                  │     │                  │   . O valor EATEN da
;       (EATEN)         . │        ■         │     │        ■         │.    fruta comida é 
;                          .       ■         │     │        ■       .       transformado em
;                         |   .    ■         │     │        ■    .    │     SNAKE
;                         │      . ■         │     │        ■ .       │
;                         │        ¤         │     │        ■         │
;                         │                  │     │                  │
;                         └──────────────────┘     └──────────────────┘
;                                 (a)                      (b)
;
;			(a) A fruta comida chegou na cauda, quando a cauda anterior foi apagada no  
;           ciclo de instruções antes deste e tptr passou a apontar para ela. (b) O valor
;           EATEN contido nos bits menos significativos da fruta comida é transformado
;           em SNAKE, passando então a ser a nova cauda. Com a conversão de EATEN em SNAKE, 
;           mantendo o ponteiro tptr inalterado, a cobrinha ficou maior em uma unidade.
;
;
; A última operação relacionada com a lógica do jogo no ciclo de instruções é a verificação se a posição
; da fruta deve ser mudada. Isso é feito quando a fruta foi comida (a fruta comida zera o tempo de vida),
; ou comparando o tempo que ela deve permanecer na mesma posição, gravado em ftim, com o contador de
; tempo de vida gravado em fctr. A cada ciclo de instruções, fctr é declementado em uma unidade.
;
; Quando o tempo de vida da fruta chegar a zero, é executada a função random, que sorteia uma nova
; posição pseudo-aleatória vazia para a mesma, e esta se move para a nova posição, reiniciando a contagem.
;
;
;                                       ┌──────────────────┐
;                                       │            © . . . . . Nova posição da
;                                       │                  |     fruta
;                                       │                  │
;                                       │                  │
;                                       │                  │
;                                       │  ×               │
;                                       │.                 │
;                                      . ──────────────────┘
;                                    .
;                   Posição anterior
;                   da fruta
;
;
; Por fim, a última etapa do ciclo de instruções consiste na renderização do mapa do jogo na tela do
; computador. 
;
; O mapa, representado pelo arranjo map, é uma estrutura lógica do jogo. É preciso exibir seu estado
; na tela após a atualização feita pela execução das etapas anteriores. Cada uma das células do mapa 
; será transformada em um pequeno quadrado de pixels colorido na tela. Como map representa uma matriz
; de 32x32 posições, ele será mostrado disposto em linhas e colunas de quadrados coloridos. Um quadrado 
; que representa uma posição vazia (EMPTY) recebe a cor verde. Se representa uma parte do corpo da cobrinha
; (SNAKE) recebe a cor azul. Se representa a fruta (FRUIT) recebe a cor vermelho. O que representa a 
; fruta comida (EATEN) recebe a cor rosa. O que representa um ponto de colisão recebe a cor preta.
;
; O vídeo foi configurado para o "modo VGA 13h" na função start, e todo cálculo realizado tem como base
; essa configuração. O "modo VGA 13h" define a resolução de tela como 320x200 pixels, cada pixel sendo
; representado por um único byte, permitindo a representação de 256 cores diferentes (2^8 = 256). Estas
; 256 cores são representadas por meio de índices para a paleta de cores do VGA.
;
; Em .redraw, o algoritmo percorre cada célula do arranjo map identificando se ela é vazia, uma parte
; da cobrinha ou fruta, e cria um quadrado de 5x5 pixels com a cor relativa na posição específica da 
; tela, correspondente à linha e coluna daquela célula no mapa. Esta posição é calculada baseando-se
; num deslocamento horizontal e vertical do mapa na tela, conforme esquematizado no diagrama abaixo, 
; de modo a centralizá-lo em ambas as coordenadas.
;
;
;                  ┌──────────────────────────────────────────────────────────────┐
;                  │ ┌──────────────────────────────────────────────────────────┐ │
;                  │ │                            ┬                             │ │
;                  │ │                            | 20px                        │ │
;                  │ │                            ┴                             │ │
;                  │ │                      ┌────────────┐                      │ │
;                  │ │                      │            │                      │ │
;                  │ │ ¦------------------¦ │            │ ¦------------------¦ │ │
;                  │ │         80px         │            │         80px         │ │
;                  │ │                      │            │                      │ │
;                  │ │                      └────────────┘                      │ │
;                  │ │                            ┬                             │ │
;                  │ │                            | 20px                        │ │
;                  │ │                            ┴                             │ │
;                  │ └──────────────────────────────────────────────────────────┘ │
;                  │                                                   ■ ■ ■ ■ ■  │
;                  └──────────────────────────────────────────────────────────────┘
;                                               │    │
;                                               │    │
;                             ──────────────────────────────────────────
;
;         O mapa do jogo vai ficar centralizado na tela do monitor, tanto na horizontal quanto 
;         na vertical. Para que isto aconteça, imagine que toda a área da tela estará mapeada
;         lógicamente como uma grade de quadrados de 5x5 pixels. 
;
;         Para a resolução de 320x200 pixels do modo VGA 13h, tem-se:
;
;         Horizontal: 320 / 5 = 64 quadrados.
;         Vertical:   200 / 5 = 40 quadrados.
;
;         Temos então uma grade com 64x40 quadrados de 5x5 pixels. Como a dimensão do mapa tem 
;         32x32 quadrados, para calcular o recuo das bordas para centralizar horizontalmente e
;         verticalmente, fazemos o seguinte:
;
;         1. Bordas direita e esquerda (recuo horizontal):
;
;            64 - 32 = 32 quadrados
;
;            Como são duas bordas, o recuo deve ser a metade deste valor de cada lado, ou seja
;            16 quadrados à direita e 16 quadrados à esquerda.
;                     
;            Convertendo em número de pixels: 16 x 5 = 80px.
;
;         2. Bordas superior e inferior (recuo vertical):
;
;            40 - 32 = 8 quadrados -> 
;            8 / 2  = 4 quadrados de cada lado
;
;            Temos então 4 quadrados acima e 4 quadrados abaixo. 
;
;            Convertendo em número de pixels: 4 x 5 = 20px.
;
;
; Um quadrado colorido na tela, representando uma célula do mapa, será desenhado usando 5 linhas e
; 5 colunas de pixels, requerendo 25 pixels no total, desta forma:
;
;
;                                 Pixel (*)
;                                     .
;                                    .
;                                   .
;                                  .
;                                 .
;                                .
;                           ┬ *  *  *  *  *   .  linha 1
;                           │ *  *  *  *  *   .  .  .  linha 2
;                       5px │ *  *  *  *  *   .  .  .  .  .  linha 3
;                           │ *  *  *  *  *   .  .  .  .  .  .  .  linha 4
;                           ┴ *  *  *  *  *   .  .  .  .  .  .  .  .  .  linha 5
;                             ├───────────┤
;                                  5px     
;                             .  .  .  .  .
;                      coluna 1  .  .  .  .
;                                .  .  .  .
;                         coluna 2  .  .  .
;                                   .  .  .
;                            coluna 3  .  .
;                                      .  .
;                               coluna 4  .
;                                         .                        
;                                  coluna 5
;                         
;                      Cada célula do mapa será desenhada como um quadrado 
;                      de 5x5 pixels na tela, ocupando 5 linhas e 5 colunas
;                      de pixels.
;
;
; No código original eram quadrados de 4x4 pixels, porém eu ampliei um pouco a escala do mapa na tela. Os
; quadrados estarão alinhados lado a lado, até formar o mapa completo, com 32x32 células, centralizado na
; horizontal e na vertical na tela, desta forma:
;
;
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;                ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■
;
;                Representação do mapa na tela como um arranjo de 32x32 células,
;                cada célula representada por um quadrado colorido de 5x5 pixels.
;
;
; Essa estrutura deve ser exibida. Para que isso aconteça, é preciso gravar a área da memória em modo
; real que será periódicamente scaneada pelo controlador do vídeo para a exibição (50 a 70 vezes por segundo). 
;
; No modo real, a memória de vídeo inicia no endereço 0xA0000, ocupando 128 KB. Os bytes do modo gráfico
; VGA 13h ocupam os primeiros 64 KB a partir do endereço 0xA0000, sendo os demais bytes destinados para 
; a exibição em modo texto. Cada byte da memória do VGA representa um pixel de uma cor específica, obtido
; de uma paleta de cores.
;
;
;                                │                      │
;                                │                      │
;                                │──────────────────────│ 0xBFFFF   ┬
;                                │──────────────────────│ 0xBFFFE   │
;                                │──────────────────────│ 0xBFFFD   │
;                                │──────────────────────│           │
;                                │──────────────────────│           │
;                                │──────────────────────│           │
;                                │──────────────────────│ .         │                  ┬
;                                │──────────────────────│ .         │ Memória de       │
;                                │──────────────────────│ .         │ Vídeo (128 KB)   │
;                                │──────────────────────│           │                  │
;                                │──────────────────────│           │                  │ Memória para
;                                │──────────────────────│           │                  │ modo VGA 13h
;                                │──────────────────────│ 0xA0003   │                  │ (64 KB)
;                                │──────────────────────│ 0xA0002   │                  │
;                                │──────────────────────│ 0xA0001   │                  │
;                          GS -> │──────────────────────│ 0xA0000   ┴                  ┴
;                       .        │                      │
;      Ponteiro para  .          │                      │
;      o segmento da                       
;      memória de vídeo
;            
;                A memória de vídeo em modo real inicia no endereço 0xA0000. Os bytes para
;                o modo gráfico VGA 13h, configurado com a instrução assembly:
;
;                  mov ax, 0x0013   ; Modo gráfico VGA 13h (320 x 200 pixels x 256 cores).
;                  int 0x10         ; Interrupção de vídeo da BIOS para aplicar o VGA 13h.
;
;                ocupam os primeiros 64 KB após este endereço. Os demais bytes da memória
;                de vídeo são alocados para o modo texto.
;
;
; Na função start, fizemos o registrador de segmento GS apontar para a base do endereço de memória de
; vídeo (0xA0000). Agora, para gravar os pixels da imagem do mapa, basta calcular o offset de cada linha.
;
; Na memória de vídeo, a imagem é representada linha por linha, sequêncialmente, cada linha tendo 320
; pixels. Logo, para calcular o offset do pixel na linha temos de considerar que o primeiro pixel da 
; primeira linha estará no endereço 0xA0000, o primeiro pixel da segunda linha estará em 0xA0140, e assim
; sucessivamente, de acordo com a equação:
;
;                                          offset = (y * 320) + x
;
; Como visto, há um deslocamento do mapa de modo que ocupe a posição central, na vertical e na
; horizontal da tela, logo, o primeiro pixel do mapa em cada linha deverá estar deslocado em 80 pixels,  
; conforme calculamos acima quando dimensionamos a área do monitor usando o truque da malha. Além disso, 
; a primeira linha do mapa deve estar deslocada 20 pixels do topo do monitor. Dessa forma, vamos preenchendo 
; cada linha para a reprodução da imagem do mapa, com cada célula do mapa ocupando 5 linhas e 5 colunas de 
; pixels, até completar o arranjo de 32*32 células.
;
;
;                             ├──────────────────────────────────  Memória de vídeo ──────────────────────────────────┤       
;
;                                   8 bytes           8 bytes           8 bytes           8 bytes           8 bytes
;                             ├───────────────┤ ├───────────────┤ ├───────────────┤ ├───────────────┤ ├───────────────┤
;               8              ■ ■ ■ ■ ■ ■ ■ ■   ■ ■ ■ ■ ■ ■ ■ ■   ■ ■ ■ ■ ■ ■ ■ ■   ■ ■ ■ ■ ■ ■ ■ ■   ■ ■ ■ ■ ■ ■ ■ ■          
;       ├───────────────┤               
;     ┬  ■ ■ ■ ■ ■ ■ ■ ■  ─ ─ ┤    Linha 1
;     │  ■ ■ ■ ■ ■ ■ ■ ■  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤    Linha 2
;   5 │  ■ ■ ■ ■ ■ ■ ■ ■  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤    Linha 3
;     │  ■ ■ ■ ■ ■ ■ ■ ■  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤    Linha 4
;     ┴  ■ ■ ■ ■ ■ ■ ■ ■  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤    Linha 5
;
;        Esquema de gravação dos pixels na memória de vídeo. Cada linha no diagrama têm 8 pixels, 
;        no total de 5 linhas. De um arranjo de 8 x 5 pixels, deve ser feita a conversão para uma
;        representação linear na memória de vídeo, num total de 40 bytes (8 x 5 = 40), pois cada
;        pixel é representado por um byte. Cada linha, de cima para baixo, ocupa uma posição
;        sequêncial na  memória, conforme representado no diagrama.
;
;        Este esquema é uma representação reduzida do modo VGA 13h. Naquele modo, como vimos, tem-se
;        uma resolução de 320 x 200 pixels, cada pixel sendo representado por um byte. O esquema é
;        o mesmo, mudando apenas a escala.
;
;        Periódicamente, o controlador VGA lê o que está presente na memória de vídeo e mostra no
;        monitor os pixels representados.
;
;
; Para entender melhor este processo, analise detalhadamente o código da subfunção .redraw. Nesta é feito 
; o processamento célula por célula do mapa.


timer_handler:
	
.waiting_cycle:

	; Controla para que o ciclo de instruções seja executado ao final do ciclo de espera.
	;
	; No código original não há regulação da velocidade, e a cobrinha só tem uma velocidade. Logo, eu
	; introduzi esta lógica de "pular" alguns ciclos de relógio sem fazer nada, apenas inclementando
	; o contador de ciclos, para que quando este completar o ciclo de espera configurado, volte a zero,
	; para iniciar um novo ciclo de espera, e execute as instruções do jogo.
	
	int 0x70            ; Dispara uma interrupção de tempo para continuar "ouvindo" o ciclo de relógio.
	
	mov cl, cctr        ; Copia o valor atual do contador de ciclos do relógio para CL.
	
	inc cl              ; Incrementa o valor do contador de ciclos do relógio em CL.
	
	mov cctr, cl        ; Atualiza o valor do contador de ciclos do relógio na memória.
    
	cmp cl, wcyc        ; Compara se o valor em CL (cctr) é igual ao de wcyc (número de ciclos em espera).
	
	je $+3              ; Se atingiu a contagem de ciclos de espera, salta para "mov cctr, 0".
	
	iret                ; Retorna da interrupção, não executando as instruções do jogo.

    mov cctr, 0         ; Zera o contador de ciclos de relógio.
	
.move_head:

	; Move a cabeça da cobrinha uma célula para cima, para baixo, para a direita ou para a esquerda,
	; dependendo da direção do movimento que é lida da célula na posição atual da cabeça em map (map(si)),
	; que é atualizada sempre que uma tecla de seta é pressionada (ver função keyboard_handler).
	;
	; Ao obter a posição para onde a cabeça da cobrinha vai se mover, faz as seguintes verificações:
	;
	;   1.  A posição atual da cabeça está marcada com a constante WRECK (colisão). Se sim, indica
	;       que o jogo está bloqueado por causa de uma colisão da cobrinha consigo mesma que ocorreu 
	;       anteriormente. Neste caso, apenas retorna da interrupção.	
	;
	;   2.  Verifica se na célula da nova posição da cabeça da cobrinha contém nos bits menos significativos
	; 	    os bits de SNAKE (parte do corpo da cobrinha) ou EATEN (fruta comida pela cobrinha). Se
	;       sim, marca a posição atual da cabeça da cobrinha como WRECK (colisão), indicando que houve
	;       uma colisão da cabeça com um parte de seu corpo. Feito isso, retorna da interrupção.
	;
	;   3.  Verifica se na célula que a cabeça vai se mover contém a fruta. Se sim, primeiramente incrementa
	;       e imprime a pontuação do placar. Depois grava em BL a constante EATEN (fruta comida).
	;
	;   4.  Se a posição para onde a cabeça da cobrinha vai se mover não for SNAKE (parte do corpo)
	;       ou EATEN (fruta comida), indicando colisão, nem FRUIT (fruta), ou seja, está vazia, grava
	;       em BL a constante SNAKE (parte do corpo).
	;
	; Nos casos 3 e 4, após alterar os valores nos bits menos significativos de BL, armazena seu valor
	; na célula do mapa aonde a cabeça se moveu, e atualiza o ponteiro hptr para apontar para ela. 

	mov si, hptr        ; Obtém a posição atual da cabeça da cobrinha em SI, copiando o valor do
	                    ; ponteiro "hptr".
	
	call movement       ; Calcula as novas coordenadas, de acordo com a direção definida em map(si),
	                    ; que representa a cabeça da cobrinha.
	
	mov ah, map(di)     ; Armazena o conteúdo da posição calculada da cabeça obtido de map(di) em AH.
	
	mov al, map(si)     ; Armazena o conteúdo da posição atual da cabeça obtido de map(si) em AL. 
	
	test al, WRECK      ; Testa se na posição atual da cabeça no mapa indica uma colisão.
	
	jz $+3              ; Se não houve colisão, salta para "test ah, SNAKE|EATEN".
	
	iret                ; Se houve colisão, retorna. (neste caso, fica parado até reiniciar o jogo).
	
	test ah, SNAKE|EATEN; Verifica se AH contém nos bits menos significativos um bit correspondente a 
	                    ; SNAKE ou a EATEN, detectando assim se há uma colisão da cobrinha consigo mesma.
	
	jz $+8              ; Se a cobrinha não está colidindo consigo mesma, salta para "test ah, FRUIT"
	
	mov map(si), WRECK  ; Se a cobrinha colidiu com seu próprio corpo, marca a posição da cabeça no mapa 
	                    ; como WRECK (isso pára o jogo).
	
	jnz .redraw         ; Se houve colisão consigo mesmo, desenha o ponto de colisão da cabeça.
	
	test ah, FRUIT      ; Verifica se na posição calculada da cabeça da cobrinha contém uma fruta.
	
	jz $+28             ; Se não for uma fruta, salta para "mov bl, SNAKE".
	
	inc scor            ; Inclementa a pontuação no placar.
	
	call print_score    ; Imprime o resultado do placar.
	
	mov fctr, 0         ; Zera o tempo de existência da fruta (fctr).
	
	mov fptr, -1        ; Define a posição da fruta (fptr) como -1.
	
	mov bl, EATEN       ; Define BL como EATEN (fruta comida).
	
	jmp $+4             ; Pula para a próxima instrução, para executar "and al, 0xF0".
	
	mov bl, SNAKE       ; Define BL como SNAKE (parte do corpo da cobrinha).
	
	and al, 0xF0        ; Mantém apenas os bits mais significativos de AL, que representam a direção, 
	                    ; zerando os bits menos significativos (parte da cobrinha).
	
	or bl, al           ; Combina SNAKE ou EATEN que está em BL com os bits de direção armazenados
	                    ; em AL, garantindo que a nova célula da cabeça da cobrinha no mapa contenha  
						; sua orientação nos bits mais significativos, e da parte do corpo nos menos  
						; significativos.
	
	mov map(di), bl     ; Atualiza o valor na célula do mapa na posição DI, que é onde a cabeça da 
	                    ; cobrinha se moveu neste ciclo.
	
	mov hptr, di        ; Atualiza o ponteiro hptr para registrar a nova posição da cabeça da cobrinha.
	
.move_tail:

	; Move a cauda da cobrinha para cima, para baixo, para a direita ou para a esquerda, dependendo
	; da direção do movimento que é lida da célula na posição atual da cauda em map (map(si)). Se a
	; cauda atual tiver o valor EATEN (fruta comida) ou EMPTY, marca como SNAKE, e não altera o valor
	; de tptr, passando ela, portanto, a ser a nova cauda, e aumentado com isso o tamanho da cobrinha.
	;
	; Isso é feito nos seguintes passos:
	;
	;   1.  Verifica se na célula na posição atual da cauda da cobrinha contém nos bits menos significativos
	; 	    o bit de SNAKE (parte do corpo da cobrinha).
	;
	;   2.  Se contém o bit de SNAKE, indica que a cauda da cobrinha deve ser apagada, (marcada como
	;       EMPTY) e o ponteiro tptr deve ser movido para a próxima célula calculada em movement, mantendo
	;       o tamanho da cobrinha inalterado.
	;
	;   3.  Se a célula não contém o bit de SNAKE, ela só pode conter EATEN (fruta comida) ou EMPTY.
	;       Neste caso, a célula será transformada em SNAKE, alterando os bits menos significativos,
	;       mantendo o bit de direção nos bits mais significativos, e não alterando tptr, pois o que 
	;       era EATEN ou EMPTY antes, agora se torna na nova cauda (SNAKE).
	;
	; Basicamente, completa-se o movimento iniciado em .move_head. Enquanto lá a cabeça da cobrinha
	; avança, aqui a cauda acompanha o avanço.

	mov si, tptr        ; Obtém a posição atual da cauda da cobrinha em SI, copiando o valor do
	                    ; ponteiro "tptr".
	
	call movement       ; Calcula as novas coordenadas, de acordo com a direção definida em map(si),
	                    ; que representa a cauda da cobrinha.
	
	mov al, map(si)     ; Armazena o valor na posição atual da cauda obtido de map(si) em AL. 
	
	test al, SNAKE      ; Verifica se AL contém SNAKE, ou seja, é parte da cobrinha. Se não for, AL
	                    ; estará com o valor de EATING (fruta comida) ou EMPTY (vazio).
	
	jz $+11             ; Se AL não for parte da cobrinha, salta para a instrução "jnz $+9".
	
	mov map(si), EMPTY  ; Se AL for SNAKE (parte da cobrinha), a posição atual da cauda é apagada 
	                    ; (marcando como EMPTY).
	
	mov tptr, di        ; Atualiza o índice da cauda para a nova posição calculada em movement.
	
	jnz $+9             ; Se AL for SNAKE, salta para o rótulo .move_fruit após a cauda ser movida para a 
	                    ; nova posição.
	
	and al, 0xF0        ; AL não é SNAKE. Neste caso, mantém apenas os bits mais significativos de AL,
	                    ; que representam a direção, zerando os bits menos significativos para ativar
						; o bit de SNAKE no lugar de EATEN ou EMPTY. 
	
	or al, SNAKE        ; Combina o valor SNAKE com a direção, garantindo que a cauda continue seguindo
	                    ; o movimento correto da cobrinha.
	
	mov map(si), al     ; Atualiza a posição atual da cauda no mapa, para SNAKE, sobrescrevendo EATEN
	                    ; ou EMPTY.
	
.move_fruit:

	; Controla a movimentação da fruta no jogo. Basicamente, verifica o tempo de vida da mesma em fctr.
	; Caso ainda seja maior do que zero, apenas decrementa o valor de fctr. Do contrário, deve-se mover
	; a fruta para uma posição vazia aleatória no mapa, apagando-a da posição atual, e reiniciar fctr
	; ao valor do tempo de vida para o nível de dificuldade selecionado.

	cmp fctr, 0         ; Compara fctr (tempo da fruta) com 0 (tempo de vida expirado). 
	
	jne $+43            ; Se não for 0, pula para "dec fctr", decrementando o tempo de vida da fruta.
	
	mov bx, fptr        ; Se fctr é zero, obtém a posição atual da fruta em BX, copiando o valor do
	                    ; ponteiro fptr.
	
	mov map(bx), EMPTY  ; Apaga sua célula no mapa, marcando-a como vazia (EMPTY).
	
	call random         ; Chama a função random, para gerar um novo número aleatório em AX, usando
	                    ; o valor atual como semente no processo.
	
	mov bx, ax          ; O resultado aleatório em AX é armazenado em BX.
	
	and bx, 1023        ; O resultado em BX é limitado a 1023, garantindo que a nova posição da fruta
                        ; esteja dentro da área do mapa (1024 células).
	
	cmp map(bx), EMPTY  ; Verifica se a célula na posição gerada em BX está vazia (EMPTY).
	
	jne $-13            ; Se ela não estiver vazia, retorna a "call random" para gerar outra posição
                        ; aleatória, repetindo este laço até encontrar uma célula vazia no mapa.
	
	mov map(bx), FRUIT  ; Define a fruta na nova posição vazia do mapa.
	
	mov fptr, bx        ; Atualiza fptr para o índice da nova posição da fruta no mapa.
	
	mov ax, ftim        ; Copia o valor de ftim (tempo de vida) em AX.
	
	mov fctr, ax        ; Copia AX em fctr, indicando que a fruta ficará ativa por ftim ciclos de 
                        ; instrução antes de ser substituída novamente. Um ciclo de instruções ocorre
						; a cada wcycl de relógio.
	
	dec fctr            ; Diminui o tempo de vida da fruta a cada ciclo de instruções.

.redraw:

	; Renderiza o mapa do jogo (map) no monitor de vídeo. Para cada posição em map, realiza os seguintes
	; passos:
	;
	;   1.  Calcula as Coordenadas de Tela da célula do mapa
	;
	;       Cada célula do mapa será representada como um quadrado de 5x5 pixels colorido. A tela 
	;       está dividida lógicamente em uma grade de 64x40 quadrados. O mapa deverá estar centralizado
	;       tanto na horizontal quanto na vertical na tela. Logo, a primeira célula do mapa (0, 0) 
	;       deve estar a 17 quadrados da borda esquerda, e a 5 quadrados da borda superior. A última
	;       célula do mapa (31, 31) deve estar a 48 quadrados da borda esquerda e a 36 quadrados da
	;       borda superior. Cada célula, a leitura sendo feita linha por linha, da esquerda para a 
	;       direita, deve ser posicionada no seu respectivo quadrado na grade, iniciando em (0,0), (0,1),
	;       (0,2)... (31, 30), (31,31). O que se faz então é calcular o índice de X e de Y (em pixels)
	;       da respectiva célula, considerando os recuos tanto na horizontal quanto na vertical. Encontrado
	;       estes índices, passa para o próximo passo.
	;
	;   2.  Determina a Cor do quadrado: 
	;
	;       Identifica o tipo de célula (EMPTY, SNAKE, FRUIT, EATEN) na posição correspondente de map
	;       e com base nesse tipo, seleciona uma cor predefinida para os pixels do quadrado (representada
	;       por um índice na paleta de cores do VGA).
	;
	;   3.  Desenha o quadrado na Memória de Vídeo:
	;
	;       Usando a cor identificada, desenha um quadrado de 5x5 pixels na tela, gravando na memória de
	;       vídeo, no offset calculado com base no deslocamento horizontal e vertical do mapa na tela,
	;       os bytes do quadrado. Faz isso escrevendo o valor da cor em 5 linhas consecutivas da memória
	;       de vídeo, cada uma com um offset de 320 pixels, para posicionar os 5 pixels de uma linha logo
	;       abaixo dos 5 pixels da outra, para alinhar o quadrado.
	;
	;   4.  Loop e Retorno: 
	;
	;       O mesmo processo é repetido para todas as 1024 posições de map. Uma vez que todas as posições 
	;       foram processadas, retorna da interrupção.
	;
	; No programa original, o autor usava o registrador EBX, de 32 bits, para obter a cor e gravar a
	; memória de vídeo 4 bytes por vez. Eu alterei para a cor ser copiada em temp, que é uma variável
	; na memória RAM, e gravo apenas um byte por vêz. Esta mudança não afetou de modo perceptível a
	; velocidade de removação dos quadros.

	mov cx, 0           ; Inicializa o registrador CX com 0. CX será usado como um índice para iterar
	                    ; pelas 1024 posições do array map.						
	
	mov ax, cx          ; Copia o valor de CX para AX. AX será usado em cálculos para determinar a
	                    ; coordenada Y na tela.
	
	mov dl, 32          ; Carrega o valor 32 em DL. Este valor será usado como divisor para calcular
	                    ; as coordenadas de linha (Y) e coluna (X) a partir de um índice linear.
	
	div dl              ; Divide o valor em AX por DL. O quociente (resultado da divisão inteira) é 
	                    ; armazenado em AL (parte baixa de AX), e o resto da divisão é armazenado em AH
						; (parte alta de AX). Se AX contém o índice linear (0 a 1023), AL terá a coordenada
						; Y (linha) e AH terá a coordenada X (coluna) em uma matriz de 32x32.
	
	mov bx, ax          ; Copia o conteúdo de AX (que agora contém X em AH e Y em AL) para BX. Isso é
	                    ; feito para preservar as coordenadas, pois AX será usado em outros cálculos.
	
	movzx ax, bl        ; Move o byte menos significativo de BX (BL, que contém a coordenada Y) para AX
	                    ; e zera a parte alta de AX. Isso garante que AX tenha apenas o valor da coordenada
						; Y e esteja pronto para cálculos.
	
	add ax, 5           ; Adiciona 5 a AX. Isto significa pular 25 pixels da borda superior.
	
	mov dx, 320         ; Carrega o valor 320 em DX. Este é o número de pixels por linha na memória
	                    ; de vídeo no modo VGA 13h (320x200 pixels). Será usado para calcular o offset
						; de linha.
	
	mul dx              ; Multiplica o valor em AX (coordenada Y ajustada) por DX (320). O resultado é 
	                    ; armazenado em DX:AX. Isso calcula o offset inicial para a linha correta na
						; memória de vídeo.
	
	movzx dx, bh        ; Move o byte mais significativo de BX (BH, que contém a coordenada X) para DX
	                    ; e zera a parte alta de DX. Isso garante que DX tenha apenas o valor da coordenada
						; X para os próximos cálculos.
	
	add ax, dx          ; Adiciona o valor de DX (coordenada X) a AX. Agora AX contém o offset inicial
	                    ; para a posição exata (pixel) na memória de vídeo para o canto superior esquerdo
						; do quadrado a ser desenhado.
	
	add ax, 16          ; Adiciona 16 a AX. Este é um offset horizontal, semelhante ao offset vertical, 
	                    ; para ajustar o posicionamento do desenho na tela.
	
	mov dx, 5           ; Carrega o valor 5 em DX. Este valor será usado para multiplicar o offset 
	                    ; calculado por 5, pois cada quadrado terá 5x5 pixels.
	
	mul dx              ; Multiplica o valor em AX pelo valor em DX. O resultado em ax agora representa
	                    ; o offset final na memória de vídeo, considerando que cada quadrado na matriz
						; map corresponde a 5 pixels.
	
	mov di, cx          ; Copia o valor de CX (o índice atual do array map) para DI. DI é usado como um 
	                    ; ponteiro para acessar o array map.
	
	mov dl, map(di)     ; Carrega o byte na posição DI do array map para DL. Este byte contém informações
	                    ; sobre o tipo de célula (EMPTY, SNAKE, FRUIT, EATEN) naquela posição do mapa.
	
	and dl, 0x0F        ; Realiza uma operação AND bit a bit com 0x0F (binário 00001111). Isso mantém 
	                    ; apenas os 4 bits menos significativos de DL, que contêm o tipo de célula, zerando
						; os bits mais significativos.

	cmp dl, EMPTY       ; Compara o valor em DL com a constante EMPTY (célula vazia).
	
	jne $+8             ; Se o valor não for EMPTY, salta para "cmp dl, SNAKE".
	
	mov temp, EMPTY_COLOR ; Se o valor for EMPTY, Atribui a cor do quadrado como EMPTY_COLOR.
	
	cmp dl, SNAKE       ; Compara o valor em DL com a constante SNAKE (parte da cobrinha).
	
	jne $+8             ; Se não for SNAKE, salta para "cmp dl, FRUIT".
	
	mov temp, SNAKE_COLOR ; Se o valor for SNAKE, Atribui a cor do quadrado como SNAKE_COLOR.
	
	cmp dl, FRUIT       ; Compara o valor em DL com a constante FRUIT (fruta).
	
	jne $+8             ; Se não for FRUIT, salta para "cmp dl, EATEN".
	
	mov temp, FRUIT_COLOR ; Se o valor for FRUIT, Atribui a cor do quadrado como FRUIT_COLOR.
	
	cmp dl, EATEN       ; Compara o valor em DL com a constante EATEN (fruta comida).
	
	jne $+8             ; Se não for EATEN, salta para "cmp dl, WRECK".
	
	mov temp, EATEN_COLOR ; Se o valor for EATEN, Atribui a cor do quadrado como EATEN_COLOR.

	cmp dl, WRECK       ; Compara o valor em DL com a constante WRECK (colisão).
	
	jne $+8             ; Se não for WRECK, salta para "mov di, ax".
	
	mov temp, WRECK_COLOR ; Se o valor for WRECK, Atribui a cor do quadrado como WRECK_COLOR.

	mov di, ax          ; Copia o offset final calculado em AX (que aponta para o pixel superior esquerdo
	                    ; do quadrado na memória de vídeo) para DI. DI será usado como o ponteiro de destino
						; para a memória de vídeo.
	mov bl, temp

	mov [gs:di  ], bl   ; Copia para a memória o primeiro byte da primeira linha apontada por DI.
	mov [gs:di+1], bl   ; Copia para a memória o segundo byte da primeira linha apontada por DI.
	mov [gs:di+2], bl   ; Copia para a memória o terceiro byte da primeira linha apontada por DI.
	mov [gs:di+3], bl   ; Copia para a memória o quarto byte da primeira linha apontada por DI.
	mov [gs:di+4], bl   ; Copia para a memória o quinto byte da primeira linha apontada por DI.

	add di, 320         ; Salta para a próxima linha para preencher mais cinco pixels com a cor calculada.

	mov [gs:di  ], bl   ; Copia para a memória o primeiro byte da segunda linha apontada por DI.
	mov [gs:di+1], bl   ; Copia para a memória o segundo byte da segunda linha apontada por DI.
	mov [gs:di+2], bl   ; Copia para a memória o terceiro byte da segunda linha apontada por DI.
	mov [gs:di+3], bl   ; Copia para a memória o quarto byte da segunda linha apontada por DI.
	mov [gs:di+4], bl   ; Copia para a memória o quinto byte da segunda linha apontada por DI.
	
	add di, 320         ; Salta para a próxima linha para preencher mais cinco pixels com a cor calculada.

	mov [gs:di  ], bl   ; Copia para a memória o primeiro byte da terceira linha apontada por DI.
	mov [gs:di+1], bl   ; Copia para a memória o segundo byte da terceira linha apontada por DI.
	mov [gs:di+2], bl   ; Copia para a memória o terceiro byte da terceira linha apontada por DI.
	mov [gs:di+3], bl   ; Copia para a memória o quarto byte da terceira linha apontada por DI.
	mov [gs:di+4], bl   ; Copia para a memória o quinto byte da terceira linha apontada por DI.
	
	add di, 320         ; Salta para a próxima linha para preencher mais cinco pixels com a cor calculada.

	mov [gs:di  ], bl   ; Copia para a memória o primeiro byte da quarta linha apontada por DI.
	mov [gs:di+1], bl   ; Copia para a memória o segundo byte da quarta linha apontada por DI.
	mov [gs:di+2], bl   ; Copia para a memória o terceiro byte da quarta linha apontada por DI.
	mov [gs:di+3], bl   ; Copia para a memória o quarto byte da quarta linha apontada por DI.
	mov [gs:di+4], bl   ; Copia para a memória o quinto byte da quarta linha apontada por DI.
	
	add di, 320         ; Salta para a próxima linha para preencher mais cinco pixels com a cor calculada.

	mov [gs:di  ], bl   ; Copia para a memória o primeiro byte da quinta linha apontada por DI.
	mov [gs:di+1], bl   ; Copia para a memória o segundo byte da quinta linha apontada por DI.
	mov [gs:di+2], bl   ; Copia para a memória o terceiro byte da quinta linha apontada por DI.
	mov [gs:di+3], bl   ; Copia para a memória o quarto byte da quinta linha apontada por DI.
	mov [gs:di+4], bl   ; Copia para a memória o quinto byte da quinta linha apontada por DI.
	
	inc cx              ; Incrementa o contador CX em 1. Ele passa para a próxima posição em map.
	
	cmp cx, 1024        ; Compara CX com 1024. O offset de map vai de 0 a 1023. Se for 1024, já
	                    ; enviou os quadrados de todas as células de map para a memória.
	
	jne .redraw + 3     ; Se CX não for igual a 1024, salta de volta para a instrução mov ax, cx no início 
	                    ; do loop. Isso continua o processo de redesenho para a próxima posição do mapa.
	
	iret                ; Retorna da interrupção quando o mapa foi completamente redesenhado.




; Ao executar esta função, realiza as seguintes ações para calcular a nova posição da cabeça/cauda
; da cobrinha no mapa:
; 
;   1. Copia o byte da célula da cabeça/cauda da cobrinha para CL.
;
;   2. Converte o valor do ponteiro para a célula da cabeça/cauda que está em SI de índice linear para
;      coordenadas X e Y, sendo o valor de X armazenado em AH e o de Y em AL.
;
;   3. Verifica a direção do movimento nos bits mais significativos do byte em CL e ajusta o valor de X 
;      ou de Y, conforme as equações:
;
;      Direção UP:    Y = Y - 1     (dec al)
;      Direção DOWN:  Y = Y + 1     (inc al)
;      Direção LEFT:  X = X - 1     (dec ah)
;      Direção RIGHT: X = X + 1     (inc ah)
;
;   4. Ajusta para que a cobrinha fique dentro dos limites do mapa (32 x 32). Isto faz com que, se a
;      cobrinha "sair" de uma linha ou coluna por uma das bordas, ela se "teletransporte" para a mesma
;      linha ou coluna na borda oposta. Isto é feito aplicando-se as seguintes operações lógicas:
;
;      1. Ajuste do valor de Y: 
;
;         and al, 31   (Y and 31)
;
;	   2. Ajuste do valor de X:
;
;         and ah, 31   (X and 31)
;
;      Para entender como estes ajustes funcionam, suponha que a cabeça/cauda esteja em (0,0) (x = 0, 
;      y = 0). A cabeça/cauda agora vai se mover para a direita (RIGHT), que como vimos acima, é calculado 
;      como X = X + 1. Aplicando-se o ajuste para a nova posição calculada (1, 0), temos:
;
;
;      X = 1  ->  0  0  0  0  0  0  0  1  |  Y = 0  ->  0  0  0  0  0  0  0  0  
;      31     ->  0  0  0  1  1  1  1  1  |  31     ->  0  0  0  1  1  1  1  1
;                 ----------------------  |             ----------------------
;      X & 31 ->  0  0  0  0  0  0  0  1  |  Y & 31 ->  0  0  0  0  0  0  0  0
;
;
;      Note que os bits de X e de Y são preservados após realizar o AND bit a bit em X & 31 e Y & 31. 
;      Logo, a cabeça/cauda se moverá para a célula (1,0), conforme calculado para a direção RIGHT,
;      sem extrapolar os limites do mapa.
;
;      Agora, supondo que a cobrinha continuou se movendo para a direita sem sofrer mudança de direção.
;      Ela então avança para as células (2,0), (3,0), (4,0), ..., (31,0). Ao atingir a célula (31,0), 
;      a cabeça/cauda chegou na última célula da primeira linha. Calculando o ajuste para esta célula,
;      temos:
;
;
;      X = 31 ->  0  0  0  1  1  1  1  1  |  Y = 0  ->  0  0  0  0  0  0  0  0  
;      31     ->  0  0  0  1  1  1  1  1  |  31     ->  0  0  0  1  1  1  1  1
;                 ----------------------  |             ----------------------
;      X & 31 ->  0  0  0  1  1  1  1  1  |  Y & 31 ->  0  0  0  0  0  0  0  0
;
;
;      Continuando com o cálculo, a próxima célula depois de (31, 0) será (32, 0). Porém a posição
;      X = 32 extrapola os limites do mapa, que vai de X = 0 a X = 31. Aqui acontece o "teletransporte"
;      da cabeça/cauda da cobrinha para a borda oposta.
;
;      Aplicando o AND bit a bit de X = 32 e 31, temos:
;
;
;      X = 32 ->  0  0  1  0  0  0  0  0  |  Y = 0  ->  0  0  0  0  0  0  0  0  
;      31     ->  0  0  0  1  1  1  1  1  |  31     ->  0  0  0  1  1  1  1  1
;                 ----------------------  |             ----------------------
;      X & 31 ->  0  0  0  0  0  0  0  0  |  Y & 31 ->  0  0  0  0  0  0  0  0
;
;
;      O AND bit a bit de X = 32 e 31, faz X voltar a ser 0, de acordo com o sentido do movimento 
;      RIGHT. Desta forma, a cabeça/cauda se "teletransporta" da célula (31,0) para a célula (0,0)
;      enquanto a cobrinha continua se movendo para a direita.
;
;      Agora, analizemos a situação inversa. Suponha que a cabeça/cauda esteja na célula (31,0) e a
;      direção do movimento seja para a esquerda (LEFT). Para calcular a nova posição para LEFT, 
;      como vimos, usa-se a equação X = X - 1. Então, se o sentido da direção não for alterado, a
;      cabeça/cauda vai passar pelas células (30,0), (29,0), (28,0), ..., (0,0).
;
;      Quando chegar a (0,0), a próxima posição calculada será (-1,0). Porém, esta posição extrapola
;      os limites do mapa, que vai de X = 0 a X = 31. De novo, acontece o teletransporte da cabeça/cauda
;      para a borda oposta, aplicando-se o AND bit a bit de -1 (que na representação em complemento
;      de dois é representado por 11111111) com 31.
;
;
;      X = -1 ->  1  1  1  1  1  1  1  1  |  Y = 0  ->  0  0  0  0  0  0  0  0  
;      31     ->  0  0  0  1  1  1  1  1  |  31     ->  0  0  0  1  1  1  1  1
;                 ----------------------  |             ----------------------
;      X & 31 ->  0  0  0  1  1  1  1  1  |  Y & 31 ->  0  0  0  0  0  0  0  0
;
;
;      O valor calculado agora é 00011111, que em decimal é 31. Logo, quando a cabeça/cauda alcança a
;      célula (0,0) na direção LEFT, ela é teletransportada para a última célula na mesma linha do
;      mapa.
;
;      O ajuste do eixo X independe do valor de Y, o que significa que não importa a linha, se sair
;      dos limites do mapa, a cabeça/cauda se teletransporta para a borda oposta na mesma linha, 
;      seguindo o sentido do movimento.
;
;      Para calcular os ajustes no eixo Y é da mesma forma como foi feito para X, agora a cabeça/cauda
;      se teletransportando dentro da mesma coluna do mapa.
;
;   5. Recalcula o índice linear da cabeça/cauda da cobrinha no mapa a partir das coordenadas X e Y que 
;      foram atualizadas.
;
;   6. Copia a nova posição calculada da cabeça/cauda da cobrinha para o registrador DI.
;
; Com isso, a cobrinha se move corretamente se mantendo dentro da área do jogo.

movement:

	mov cl, map(si)     ; Copia o byte da célula da cabeça/cauda em map(SI) para CL.
	mov ax, si          ; Copia o ponteiro da célula em SI para AX.
	mov dl, 32          ; Define o divisor como 32 (largura do mapa).
	div dl              ; Divide AX por DL para obter coordenadas X (resto da divisão em AH) e Y (AL).

.test_up:               ; Testa a direção UP.

	test cl, UP         ; Verifica se a direção do movimento é para cima.
	jz .test_down       ; Se não for UP, salta para .test_down.
	dec al              ; Decrementa o valor de Y em AL ( Y = Y - 1 ).
	jmp .convert        ; Salta para .convert, pois a nova coordenada já foi definida.

.test_down:             ; Testa a direção DOWN.

	test cl, DOWN       ; Verifica se a direção do movimento é para baixo.
	jz .test_left       ; Se não for DOWN, salta para .test_left.
	inc al              ; Incrementa o valor de Y em AL ( Y = Y + 1 ).
	jmp .convert        ; Salta para .convert, pois a nova coordenada já foi definida.
	
.test_left:             ; Testa a direção LEFT.

	test cl, LEFT       ; Verifica se a direção do movimento é para a esquerda.
	jz .test_right      ; Se não for LEFT, salta para .test_right.
	dec ah              ; Decrementa o valor de X em AH ( X = X - 1 ).
	jmp .convert        ; Salta para .convert, pois a nova coordenada já foi definida.	
	
.test_right:            ; Testa a direção RIGHT.
	
	inc ah              ; Incrementa o valor de X em AH ( X = X + 1 ).	
	
.convert:

	; Se ultrapassar as bordas, "teletransporta" a parte para a mesma linha/coluna na borda oposta.

	and al, 31          ; Garante que Y esteja dentro dos limites da área (0-31).
	and ah, 31          ; Garante que X esteja dentro dos limites da área (0-31).

	movzx di, al        ; Copia o valor de Y em AL para DI.
	rol di, 5           ; Multiplica DI por 32 (equivalente a Y * 32)
	
	movzx cx, ah        ; Copia o valor de X em AH para CX.
	add di, cx          ; Soma X à posição Y * 32 para obter índice linear final.
	
	ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, gera um número pseudo-aleatório baseado na técnica matemática de Gerador
; Congruencial Linear (GCL), e armazena o novo valor gerado na variável rand.
;
; O Gerador Congruencial Linear é definido como:
;
;                                   Xn+1 = (aXn + c) mod m
;
; Onde:
;
;   Xn: Valor atual da sequência (a "semente" inicial ou o número aleatório gerado anteriormente).
;
;   Xn+1: Próximo número na sequência (o novo número aleatório gerado).
;
;   a: Multiplicador.
;
;   c: Incremento.
;
;   m: Módulo.

random:

	mov ax, rand        ; Carrega o valor atual da variável "rand" (semente do número aleatório).
	mov dx, 7993        ; Define um multiplicador fixo.
	mov cx, 9781        ; Define um incremento fixo.
	mul dx              ; Multiplica AX por DX (AX = AX * DX).
	add ax, cx          ; Adiciona CX ao resultado (AX = AX + CX).  O módulo é 2^16 (palavra de 16 bits).
	mov rand, ax        ; Atualiza a variável "rand" com o novo valor gerado.

	ret                 ; Retorna da função.	




; Esta função está registrada na tabela de vetores de interrupção (IVT) para ser executada sempre
; que uma interrupção de teclado é lançada. A sua função é identificar qual foi a tecla pressionada
; pelo jogador, e, de acordo com a tecla, executar uma das seguintes ações:
;
;   * Tecla ESC: Desligar o computador.
;
;   * Tecla ESPAÇO: Reiniciar o jogo.
;
;   * Tecla 1: Definir o nível de dificuldade como 1 e reiniciar o jogo.
;
;   * Tecla 2: Definir o nível de dificuldade como 2 e reiniciar o jogo.
;
;   * Tecla 3: Definir o nível de dificuldade como 3 e reiniciar o jogo.
;
;   * Tecla 4: Definir o nível de dificuldade como 4 e reiniciar o jogo.
;
;   * Tecla SETA PARA CIMA: Mudar a direção do movimento para cima (UP) se a direção atual não for DOWN.
;
;   * Tecla SETA PARA BAIXO: Mudar a direção do movimento para baixo (DOWN) se a direção atual não for UP.
;
;   * Tecla SETA PARA A ESQUEDA: Mudar a direção do movimento para a esquerda (LEFT) se a direção atual 
;     não for RIGHT.
; 
;   * Tecla SETA PARA A DIREITA: Mudar a direção do movimento para a direita (RIGHT) se a direção atual 
;     não for LEFT.

keyboard_handler:

	in al, 0x60         ; Lê um byte do teclado (porta 0x60) e copia para AL.
	mov bx, hptr        ; Obtém a posição da "cabeça" da cobrinha, copiando o ponteiro "hptr" para BX.
	mov ah, map(bx)     ; Copia o byte nesta posição para AH.
	mov temp, ah        ; Copia o byte em AH para a variável temp, para obter a direção atual.	
	
.test_esc_key:          ; Testa a tecla ESC.

	cmp al, 0x01        ; Verifica se a tecla pressionada é ESC.
	je power_off        ; Se a tecla for ESC, salta para a função power_off, desligando o computador.

.test_space_key:        ; Testa a tecla ESPAÇO.

	cmp al, 0x39        ; Verifica se a tecla pressionada é ESPAÇO.
	jne .test_key_1     ; Se a tecla não for ESPAÇO, salta para .test_key_1.
	call restart_game   ; Reinicia o jogo.
	jmp .notify         ; Salta para .notify.
    
.test_key_1:            ; Testa a tecla 1.

	cmp al, 0x02        ; Verifica se a tecla pressionada é '1'.
    jne .test_key_2     ; Se a tecla não for '1', salta para .test_key_2.
	mov temp, 1         ; Define o nível de dificuldade como 1 (velocidade rápida).
	call set_level      ; Aplica a dificuldade.
	jmp .notify         ; Salta para .notify.

.test_key_2:            ; Testa a tecla 2.

    cmp al, 0x03        ; Verifica se a tecla pressionada é '2'.
    jne .test_key_3     ; Se a tecla não for '2', salta para .test_key_3.
	mov temp, 2         ; Define o nível de dificuldade como 2 (velocidade normal).
	call set_level      ; Aplica a dificuldade.
	jmp .notify         ; Salta para .notify.

.test_key_3:            ; Testa a tecla 3.

    cmp al, 0x04        ; Verifica se a tecla pressionada é '3'.
    jne .test_key_4     ; Se a tecla não for '3', salta para .test_key_4.
	mov temp, 3         ; Define o nível de dificuldade como 3 (velocidade lenta).
	call set_level      ; Aplica a dificuldade.
	jmp .notify         ; Salta para .notify.
	
.test_key_4:            ; Testa a tecla 4.

    cmp al, 0x05        ; Verifica se a tecla pressionada é '4'.
    jne .test_up_key    ; Se a tecla não for '4', pula para .test_up_key.
	mov temp, 4         ; Define o nível de dificuldade como 4 (velocidade mais lenta).
	call set_level      ; Aplica a dificuldade.
	jmp .notify         ; Salta para .notify.
	
.test_up_key:           ; Testa a tecla SETA PARA CIMA.

	and ah, 0x0F        ; Zera os bits mais significativos em AH, não alterando os menos significativos.
	cmp al, 0x48        ; Verifica se a tecla pressionada é SETA PARA CIMA.
	jne .test_down_key  ; Se a tecla não for SETA PARA CIMA, salta para .test_down_key.
	test temp, DOWN     ; Testa se a direção atual é DOWN.
	jnz .notify         ; Se a direção atual for DOWN, não muda para UP, pois este é um movimento inválido.
	or ah, UP           ; Define AH como UP, realizando um OR bit a bit para ativação do bit respectivo.
	jmp .check_change   ; Salta para .check_change, para não fazer mais verificações de teclas.
	
.test_down_key:	        ; Testa a tecla SETA PARA BAIXO.

	cmp al, 0x50        ; Verifica se a tecla pressionada é SETA PARA BAIXO.
	jne .test_left_key  ; Se a tecla não for SETA PARA BAIXO, salta para .test_left_key.
	test temp, UP       ; Testa se a direção atual é UP.
	jnz .notify         ; Se a direção atual for UP, não muda para DOWN, pois este é um movimento inválido.
	or ah, DOWN         ; Define AH como DOWN, realizando um OR bit a bit para ativação do bit respectivo.
	jmp .check_change   ; Salta para .check_change, para não fazer mais verificações de teclas.
	
.test_left_key:         ; Testa a tecla SETA PARA ESQUERDA.

	cmp al, 0x4b        ; Verifica se a tecla pressionada é SETA PARA ESQUERDA.
	jne .test_right_key ; Se a tecla não for SETA PARA ESQUERDA, salta para .test_right_key.
	test temp, RIGHT    ; Testa se a direção atual é RIGHT.
	jnz .notify         ; Se a direção atual for RIGHT, não muda para LEFT, pois este é um movimento inválido.
	or ah, LEFT         ; Define AH como LEFT, realizando um OR bit a bit para ativação do bit respectivo.
	jmp .check_change   ; Salta para .check_change, para não fazer mais verificações de teclas.
	
.test_right_key:        ; Testa a tecla SETA PARA DIREITA.

	cmp al, 0x4d        ; Verifica se a tecla pressionada é SETA PARA DIREITA.
	jne .check_change   ; Se a tecla não for SETA PARA DIREITA, salta para .check_change.
	test temp, LEFT     ; Testa se a direção atual é LEFT.
	jnz .notify         ; Se a direção atual for LEFT, não muda para RIGHT, pois este é um movimento inválido.
	or ah, RIGHT        ; Define AH como RIGHT, realizando um OR bit a bit para ativação do bit respectivo.
	
.check_change:          ; Testa se houve alteração na direção do movimento da cobrinha.

	test ah, 0xF0       ; Testa se o valor em AH tem os bits mais significativos zerados.
	jz .notify          ; Se estiverem zerados, não houve mudança de direção. Desta forma, salta para .notify.
	mov map(bx), ah     ; Se houve mudança na direção, grava o byte com o novo valor na cabeça da cobrinha.
	
.notify:                ; Notifica ao controlador de teclado que a interrupção foi tratada.

	mov al, 0x61        ; Carrega o valor 0x61 no registrador AL.
	out 0x20, al        ; Envia o valor de AL para a porta 0x20, informando que a interrupção foi tratada.
	
	iret                ; Retorna da interrupção, restaurando o contexto de execução anterior.




; Ao executar esta função, define o nível de dificuldade do jogo. Para definir o nível de dificuldade,
; é necessário mudar o valor do ciclo de espera (wcyc), e o tempo da fruta (ftim) precisa ser recalculado,
; para que se mantenha constante em exatos 10 segundos. Valores menores, definem diculdade maior, pois
; a cobrinha se move em maior velocidade.
;
; Como temos quatro valores para wcyc, de acordo com o nível de dificuldade, os valores relativos de
; ftim são:
;
;
;    Valor de wcyc | Valor de ftim | Tempo de espera  | Tempo de vida (seg.)
;    ------------------------------------------------------------------------
;    1             | 200           | 50 ms  (0,05 s)  | 200 x 0,05 = 10 s
;    2             | 100           | 100 ms (0,10 s)  | 100 x 0,10 = 10 s
;    3             | 67            | 150 ms (0,15 s)  | 67 x 0,15 = 10,05 s
;    4             | 50            | 200 ms (0,20 s)  | 50 x 0,20 = 10 s
;
;
; Como o PIT foi configurado para um "tick" a cada exatos 50 ms, o valor de tempo permanecerá constante,
; exceto na velocidade 3, que tem uma ligeira diferença, mas nada importante.

set_level:

.test_level_1:          ; Testa se o nível de dificuldade é 1.

	cmp temp, 1         ; Verifica se o nível de dificuldade é 1.
    jne .test_level_2   ; Se a nível de dificuldade não for 1, salta para .test_level_2.
	mov wcyc, 1         ; Define o número de ciclos em espera como 1 (velocidade rápida).
	mov ax, 200         ; Copia o valor 200 para o registrador AX.
	mov ftim, ax       	; Define o tempo de vida da fruta em 200 ciclos de instruções.
	jmp .done           ; Salta para .done.

.test_level_2:          ; Testa se o nível de dificuldade é 2.

    cmp temp, 2         ; Verifica se o nível de dificuldade é 2.
    jne .test_level_3   ; Se a nível de dificuldade não for 2, salta para .test_level_3.
	mov wcyc, 2         ; Define o número de ciclos em espera como 2 (velocidade normal).
	mov ax, 100         ; Copia o valor 100 para o registrador AX.
	mov ftim, ax        ; Define o tempo de vida da fruta em 100 ciclos de instruções.
	jmp .done           ; Salta para .notify.

.test_level_3:          ; Testa se o nível de dificuldade é 3.

    cmp temp, 3         ; Verifica se o nível de dificuldade é 3.
    jne .test_level_4   ; Se a nível de dificuldade não for 3, salta para .test_level_4.
	mov wcyc, 3         ; Define o número de ciclos em espera como 3 (velocidade lenta).
	mov ax, 67          ; Copia o valor 67 para o registrador AX.
	mov ftim, ax        ; Define o tempo de vida da fruta em 67 ciclos de instruções.
	jmp .done           ; Salta para .notify.
	
.test_level_4:          ; Testa se o nível de dificuldade é 4.

	mov wcyc, 4         ; Define o número de ciclos em espera como 4 (velocidade muito lenta).	
	mov ax, 50          ; Copia o valor 50 para o registrador AX.
	mov ftim, ax        ; Define o tempo de vida da fruta em 50 ciclos de instruções.

.done:

	call restart_game   ; Reinicia o jogo.

	ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, reinicia o jogo. Isto fará com que todas as células do arranjo map recebam
; EMPTY. Também zera todas as variáveis, exceto rand (valor aleatório gerado), wcyc (ciclo de espera) 
; e ftim (tempo de vida da fruta na tela). Tais valores devem ser preservados para manter o status de 
; temporização e a semente para a geração de números pseudo-aleatórios.

restart_game:

	mov cx, 1036        ; Define o número de bytes a serem regravados na memória, com base no segmento.
	mov al, EMPTY       ; Define o valor a ser gravado nos bytes de memória como EMPTY (zeros binários).
	mov di, 0           ; Define DI inicialmente como zero (DI apontará para a base do segmento de dados).
	rep stosb           ; Grava o valor de AL, a partir do offset apontado por DI, por CX vezes (1036).
	
	call print_score    ; Imprime o placar do jogo zerado.
	
	mov bx, hptr        ; Obtém a posição da "cabeça" da cobrinha, copiando o valor do ponteiro "hptr".
	mov ah, map(bx)     ; Copia o valor da célula na posição da cabeça para AH (será EMPTY).
	or ah, RIGHT        ; Combina a direção RIGHT com AH (vai iniciar movendo para direita).
	mov map(bx), ah     ; Copia AH para célula da cabeça da cobrinha.

	ret

	


; Ao executar esta função, imprime o placar do jogo nas linhas acima do gráfico do mapa no formato:
;
;                                  Nivel: [n]  Pontos: [p]
;
; Onde
;
;   [n]: Nível de dificuldade configurado pelo jogador.
;
;   [p]: Pontos do jogador (número de frutas devoradas).
;
; A impressão do texto usa interrupções que acessam a parte da memória de vídeo que armazena caracteres,
; e não interfere com a renderização do mapa, exceto se o mapa for posicionado em cima das letras,
; ou se as letras forem posicionadas em uma linha que fica sob o mapa, mas nesta função é cuidado
; para que isto não aconteça.

print_score:
    
	pusha               ; Salva todos os registradores na pilha para não interferir na execução do bloco 
	                    ; chamador, pois múltiplos registradores são alocados neste processo.
	
	mov ah, 0x06        ; Define a função 6 da interrupção de vídeo (rolagem de tela).
    mov al, 0           ; Rola toda a tela (valor 0 significa limpar).
    mov bh, 0x00        ; Define o atributo do fundo (cor de texto e cor de fundo).
    mov cx, 0x0100      ; Define a posição inicial (linha=2, coluna=0).
    mov dh, 1           ; Define a linha final da área a ser limpa.
    mov dl, 79          ; Define a última coluna da área a ser limpa.
    int 0x10            ; Chama a interrupção para executar a limpeza do terminal.
    
	mov ah, 0x02        ; Define a função 0x02 da interrupção de vídeo (posicionamento do cursor).
    mov bh, 0x00        ; Seleciona a página de vídeo (padrão, página 0).
    mov dh, 0x01        ; Define a linha do cursor (linha 3).
    mov dl, 0x0A        ; Define a coluna do cursor (coluna 11).
	int 0x10            ; Chama a interrupção para mover o cursor para (3,11).

.print_level:           ; Imprime o texto "Nível: ".

	mov si, level_str   ; Move o endereço de memória da string level_str para o registrador SI.
	call print_string   ; Imprime a string level_str.
	mov ah, wcyc        ; Copia o número do ciclo de espera para AH.

.test_level_1:          ; Testa se o nível de dificuldade é 1.

	cmp ah, 1           ; Testa se o ciclo de espera é 1.
	jne .test_level_2   ; Se ciclo de espera não for 1, salta para .test_level_2.
	mov al, '1'         ; Copia o caractere '1' para AL.
	jmp .print_level_num; Imprime o caractere '1'.

.test_level_2:          ; Testa se o nível de dificuldade é 2.

	cmp ah, 2           ; Testa se o ciclo de espera é 2.
	jne .test_level_3   ; Se ciclo de espera não for 2, salta para .test_level_3.
	mov al, '2'         ; Copia o caractere '2' para AL.
	jmp .print_level_num; Imprime o caractere '2'.

.test_level_3:          ; Testa se o nível de dificuldade é 3.

	cmp ah, 3           ; Testa se o ciclo de espera é 3.
	jne .test_level_4   ; Se ciclo de espera não for 3, salta para .test_level_4.
	mov al, '3'         ; Copia o caractere '3' para AL.
	jmp .print_level_num; Imprime o caractere '3'.

.test_level_4:          ; Testa se o nível de dificuldade é 4.

	mov al, '4'         ; Copia o caractere '4' para AL.

.print_level_num:       ; Imoprime o caractere numérico relativo ao nível de dificuldade.

	mov ah, 0x0E        ; Define a função 0x0E da interrupção de vídeo (exibir caractere).
	mov bl, 0x07        ; Define a cor de texto e cor de fundo.
	int 0x10            ; Chama a interrupção para imprimir o caractere armazenado em AL no terminal.
    
.print_score:	        ; Imprime o texto "Pontos: ".

	mov si, score_str   ; Move o endereço de memória da string score_str para o registrador SI.
	call print_string   ; Imprime a string score_str.
	
.print_score_num:       ; Vai converter o valor numérico da pontuação em string, e imprimir a mesma.
	
	mov ax, scor        ; Copia o valor da pontuação para o registrador AX.
	mov cx, 0           ; Zera o registrador CX, que controla quantos dígitos serão lidos da pilha.
	mov bx, 10          ; Valor 10 representa a base decimal, usado na conversão de biário para decimal.

.convert:               ; Converte o valor de pontuação em caracteres ASCII correspondentes.

	mov dx, 0           ; Zera o valor de DX, que recebe o dígito de sobra da divisão.
	div bx              ; Divide AX por 10. O resto da divisão é armazenado em DX.
	add dl, '0'         ; Converte o dígito numérico para caractere ASCII.
	push dx             ; Armazena o caractere gerado na pilha.
	inc cx              ; Incrementa CX, que funciona como contador de dígitos.
	
	test ax, ax         ; Verifica se AX ainda tem valor maior que zero após a divisão.	
	jnz .convert        ; Se AX ainda for maior que zero, retorna para .convert.

	mov ah, 0x0E        ; Define a função 0x0E da interrupção de vídeo (exibir caractere).
	mov bl, 0x07        ; Define a cor de texto e cor de fundo.

.print_digits:          ; Imprime os dígitos da pontuação.

	pop dx              ; Recupera um dígito da pilha.

	mov al, dl          ; Copia o caractere recuperado da pilha para AL.
    
	int 0x10            ; Chama a interrupção para imprimir o caractere armazenado em AL no terminal.
    
	loop .print_digits  ; Retorna ao início do laço .print_digits, para processar o próximo caractere.

	popa                ; Restaura todos os registradores para continuar a execução do bloco chamador.

	ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, imprime o texto de ajuda com as instruções do jogo.

print_help:
    
	mov si, help_str    ; Move o endereço de memória da string menu_str para o registrador SI.
    call print_string   ; Imprime a string menu_str.

.wait_enter:            ; Aguarda até o jogador digitar ENTER para começar o jogo.
    
	mov ah, 0           ; Define a função 0 da interrupção de teclado (leitura de tecla).
    int 0x16            ; Chama a interrupção para ler a tecla pressionada e copiar para AL.
    cmp al, 0x0D        ; Compara o valor em AL, que armazena o valor da tecla, com 0x0D (Enter).
    jne .wait_enter     ; Se a tecla pressionada não for Enter, volta a ler o teclado novamente.
	
	ret                 ; Retorna o controle para o ponto de chamada.
	



; Ao executar esta função, imprime uma string no terminal, caractere por caractere, até encontrar 
; o byte nulo 0x00, que denota o final da string.
	
print_string:

    mov ah, 0x0E        ; Define a função 0x0E da interrupção de vídeo (exibir caractere).
	mov bl, 0x07        ; Define as cores de fonte e fundo (fundo preto, texto branco).

.next_char:

    lodsb               ; Carrega o próximo byte da string apontada por SI para AL, e inclementa SI.
    or al, al           ; Faz uma operação OR de AL com ele mesmo. Se AL for 0, o resultado será 0.
    jz .done            ; Se AL for 0 (alcançou o fim da string), salta para .done.
    int 0x10            ; Chama a interrupção para imprimir o caractere armazenado em AL no terminal.
    jmp .next_char      ; Retorna ao início do laço .next_char, para processar o próximo caractere.

.done:

    ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, apaga todas as linhas a partir da terminal.

clear_screen:

	mov ah, 0x06        ; Define a função 6 da interrupção de vídeo (rolagem de tela).
    mov al, 0           ; Rola toda a tela (valor 0 significa limpar).
    mov bh, 0x07        ; Define o atributo do fundo (cor de texto e cor de fundo).
    mov cx, 0000h       ; Define a posição inicial (linha 4, coluna 0).
    mov dh, 24          ; Define a linha final da área a ser limpa.
    mov dl, 79          ; Define a última coluna da área a ser limpa.
    int 0x10            ; Chama a interrupção para executar a limpeza do terminal.
    
.reset_cursor:	

	mov ah, 0x02        ; Define a função 2 da interrupção de vídeo (mover cursor).
    mov bh, 0x00        ; Seleciona a página de vídeo (padrão, página 0).
    mov dh, 0x01        ; Define a linha do cursor (linha 5).
    mov dl, 0x00        ; Define a coluna do cursor (coluna 0).
    int 0x10            ; Chama a interrupção para mover o cursor para (5,0).

	ret




; Ao executar esta função, usa interrupções de APM para tentar desligar o computador. Nos testes
; funcionou com o Qemu, porém no computador real (ACER E1-422-3419) não.

power_off:

	cli

	; Configura o modo de vídeo para modo texto 80x25 (80 colunas/25 linhas).

	mov ah, 0x00        ; Define a função 0 da interrupção de vídeo.
    mov al, 0x03        ; Define o modo de vídeo como modo texto 80x25.
    int 0x10            ; Chama a interrupção que configura o modo de vídeo.

	call clear_screen   ; Limpa a tela.

    ; 1. Verifica se APM está presente.

    mov ax, 0x5300      ; Define a função 0x5300, que é usada para detectar a presença do APM.
    xor bx, bx          ; Zera o valor de BX.
    int 0x15            ; Chama a interrupção 0x15, para testar se a APM está presente.
    jc .apm_not_present ; Se a APM não está presente no sistema, salta para .apm_not_present.

    ; 2. Conecta-se à interface APM.

    mov ax, 0x5301      ; Define a função 0x5301, que é usada para conectar-se ao APM.
    xor bx, bx          ; Zera o valor de BX.
    int 0x15            ; Chama a interrupção 0x15, para realizar a conexão ao APM.
    jc .apm_connection_failed ; Se não se conectou com a APM, salta para .apm_connection_failed.

    ; 3. Desliga o computador.

    mov ax, 0x5307      ; Define a função APM_SET_POWER_STATE, que altera o estado de energia do dispositivo.
    mov bx, 0x0001      ; Define o dispositivo-alvo. O valor 0x0001 significa todos os dispositivos.
    mov cx, 0x0003      ; Define o estado de energia do dispositivo. O valor 0x0003 indica Power Off.
    int 0x15            ; Chama a interrupção 0x15, para executar o comando de desligar o computador.

    jmp .failed_shutdown ; Se o desligamento não foi bem-sucedido, salta para .failed_shutdown.

.apm_not_present:

    mov si, apm_not_found_str ; Copia o endereço de memória da string apm_not_found_str para SI.
    call print_string   ; Imprime a string apm_not_found_str.
    jmp .hang           ; Salta para .hang.

.apm_connection_failed:

    mov si, apm_conn_fail_str ; Copia o endereço de memória da string apm_conn_fail_str para SI.
    call print_string   ; Imprime a string apm_conn_fail_str.
    jmp .hang           ; Salta para .hang.

.failed_shutdown:

    mov si, shutdown_fail_str ; Copia o endereço de memória da string shutdown_fail_str para SI.
    call print_string   ; Imprime a string shutdown_fail_str.
    jmp .hang           ; Salta para .hang.

.hang:
    
	; Loop infinito para evitar reinicialização ou comportamento indesejado.
    
	hlt                 ; Entra em modo de baixa energia até a próxima interrupção ("congela")
    jmp .hang
	



; Ponto de entrada do programa.

start:

	cli                 ; Interrompe as interrupções mascaráveis para configurar o programa.

	; Configura os registradores de segmentos que vão ser usados pelo programa.

	mov sp, 0xFFFF      ; Move o ponteiro para o topo da pilha.
	
	mov ax, 0x08A0      ; Copia o valor 0x08A0 para o registrador AX (endereço do segmento de dados extras).
	mov es, ax          ; Define a base do segmento de dados extras em ES no endereço 0x8A00 (0x08A0 x 0x10).
	
	mov ax, 0xA000      ; Copia o valor 0x0A000 para o registrador AX (endereço do segmento de memória de vídeo).
	mov gs, ax          ; Obtém a base do segmento gráfico em GS, no modo "VGA 13h", que por padrão é 0xA0000.
	
	mov ax, 0x0000      ; Copia o valor 0x0000 para o registrador AX (endereço da Interrupt Vector Table - IVT).
	mov fs, ax          ; Obtém a base do segmento da IVT em FS, que por padrão é 0x0.
	
	; Zera as variáveis no segmento de dados extras apontado pelo registrador ES. Estas variáveis são
	; o mapa do jogo (map) e demais variáveis utilizadas pelo programa (hptr, tptr, fptr, fctr, etc).

	mov cx, 1041        ; Define o número de bytes a serem zerados na memória (map + hptr + ... + ftim).
	mov al, EMPTY       ; Define o valor a ser gravado nos bytes de memória como EMPTY (zeros binários).
	mov di, 0           ; Define DI inicialmente como zero (DI apontará para a base do segmento de dados).
	rep stosb           ; Grava o valor de AL, a partir do offset apontado por DI, por CX vezes (1041).

	; Define o nível de dificuldade como nível 2.

	mov temp, 2         ; Define o nível de dificuldade como 4 (velocidade mais lenta).
	call set_level      ; Aplica a dificuldade.

	; Obtém a semente inicial para a geração de números pseudo-aleatórios. No caso, recupera informações
	; da data e hora atuais do sistema para isso.

	mov ah, 0x00        ; Define a função 0 da interrupção de relógio (lê o tempo atual do sistema).
	int 0x1A            ; Chama a interrupção que retorna o tempo atual nos registradores CX e DX.
	mov rand, dx        ; Copia o valor de DX em rand para semente do processo de geração de aleatórios.

	; Exibe as instruções e configura o vídeo para o modo VGA 320x200 (Modo 13h).

	call clear_screen   ; Limpa a tela.
	call print_help     ; Imprime as instruções do jogo. Neste ponto o vídeo ainda está no modo de texto.

	mov ah, 0x00        ; Define a função 0 da interrupção de vídeo.
	mov al, 0x13        ; Define o modo gráfico como 320x200 pixels e 256 cores (modo 13h).
	int 0x10            ; Chama a interrupção que configura o modo de vídeo.

	call print_score    ; Imprime o placar zerado.
	
	; Sobrescreve a rotina de tratamento de interrupção (ISR) do relógio na IVT (INT 0x08) para apontar
	; para a função timer_handler.

	mov [fs:0x08*4], word timer_handler
	mov [fs:0x08*4+2], ds

	; Sobrescreve a rotina de tratamento de interrupção (ISR) do teclado na IVT (INT 0x09) para apontar
	; para a função keyboard_handler.

	mov [fs:0x09*4], word keyboard_handler
	mov [fs:0x09*4+2], ds
	
	sti                 ; Retoma as interrupções mascaráveis após as configurações.




; Entra num loop infinito, "ouvindo" os eventos que são gerados com as interrupções monitoradas na tabela
; de vetores de interrupção (IVT).

main:

	hlt                 ; Aguarda evento de interrupção.

	jmp main            ; Loop infinito, escutando os eventos de relógio e de teclado.




; Seção de dados do programa. Alguns caracteres nas strings devem ser escritos com seus valores
; hexadecimais da tabela "Code page 437".


help_str:

db ' Neste  est', 0xA0, 'gio, o kernel do sistema operacional seria  carregado  na  mem', 0xA2,'ria, '
db ' assumindo a responsabilidade por carregar os demais programas necess', 0xA0,'rios para '
db ' o funcionamento do mesmo.  Como n', 0x84, 'o h', 0xA0,' um sistema operacional, vou utilizar os '
db ' recursos da sua m', 0xA0, 'quina para fazer uma ', 0xA3, 'nica coisa: Rodar o jogo da cobrinha!'
db 0x0D, 0x0A, 0x0D, 0x0A, ' Instru', 0x87, 0x94, 'es do jogo:'
db 0x0D, 0x0A, 0x0D, 0x0A, ' * Tecle as setas de dire', 0x87, 0x84, 'o para controlar a cobrinha.', 0x0D, 0x0A
db 0x0D, 0x0A, ' * Tecle ESPA', 0x80, 'O para reiniciar o jogo.', 0x0D, 0x0A
db 0x0D, 0x0A, ' * Tecle 1 para mudar para o n', 0xA1, 'vel 1 de dificuldade.', 0x0D, 0x0A
db 0x0D, 0x0A, ' * Tecle 2 para mudar para o n', 0xA1, 'vel 2 de dificuldade (default).', 0x0D, 0x0A
db 0x0D, 0x0A, ' * Tecle 3 para mudar para o n', 0xA1, 'vel 3 de dificuldade.', 0x0D, 0x0A
db 0x0D, 0x0A, ' * Tecle 4 para mudar para o n', 0xA1, 'vel 4 de dificuldade.', 0x0D, 0x0A
db 0x0D, 0x0A, ' * Tecle ESC para sair.'
db 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, ' Pressione ENTER para jogar', 0

level_str: db 'N', 0xA1, 'vel: ', 0

score_str: db '  Pontos: ', 0

apm_not_found_str: db 'APM BIOS not found!', 0xD, 0xA, 0

apm_conn_fail_str: db 'APM connection failed!', 0xD, 0xA, 0

shutdown_fail_str: db 'Shutdown failed via APM!', 0xD, 0xA, 0




; Completa o restante dos bytes do arquivo, que não são instruções ou dados, com zeros, até o byte 2048.

times 2048-($-$$) db 0  ; Preenche com zeros até completar o 4º setor do programa.