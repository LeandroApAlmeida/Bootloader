; ═════════════════════════════════════════════════════════════════════════════
;                        STAGE 1 - MULT-STAGE BOOTLOADER
; ═════════════════════════════════════════════════════════════════════════════
;
; Este código em Assembly implementa o Estágio 1 do bootloader, que será gravado
; no setor MBR (Master Boot Record) do disco. O Estágio 1 carregará na memória o
; Estágio 2, que é o programa que exibe o menu do sistema operacional FAKENIX e 
; que carrega o Estágio 3, que é o kernel fictício do jogo da cobrinha.
;
; Este é um projeto básico, que tem como objetivo única e exclusivamente demonstrar
; o processo em que o hardware e o software se comunica, para "dar vida" ao computador,
; desmistificando um pouco como um computador realmente funciona e instigando o
; interessado a buscar mais informações sobre o tema. Se você deseja se aprofundar
; mais no desenvolvimento de sistemas operacionais, sugiro que visite a página
; http://www.brokenthorn.com/Resources/OSDevIndex.html que contém um ótimo material
; para iniciantes, e também a página 
; https://www.independent-software.com/operating-system-development.html, onde te
; instrui passo a passo como desenvolver um sistema operacional "do zero".
; 
; Se sua intenção é entender um sistema operacional real, depois de ter uma noção
; básica de como o bootloader funciona, recomendo que analise o código do MS DOS,
; disponibilizado pela Microsoft na página do github em 
; https://github.com/microsoft/MS-DOS/tree/main, e o código-fonte do Minix, disponível
; no github em https://github.com/Stichting-MINIX-Research-Foundation/minix. 
;
; Se se interessou pelo tema assembly e aspectos da programação em baixo nível, 
; recomendo ainda que analise um sistema operacional construído inteiramente nesta
; linguagem. Trata-se do MinuetOS, disponível na página https://www.menuetos.net/.
;
; ═════════════════════════════════════════════════════════════════════════════


[BITS 16]                         ; O programa do Estágio 1 roda em modo real 
                                  ; de 16 bits.
								  
[ORG 0x7C00]                      ; O programa será executado no endereço padrão
                                  ; 0x7C00.




; =============================================================================
;
; ALINHAMENTO DAS INSTRUÇÕES
;
;
; Instrução de salto, para manter o alinhamento das instruções no MBR. Na sequência
; a estas instruções seriam declarados os campos do BPB/EPBP. Nesta imagem de disco
; NÃO devem ser declarados estes campos, pois é uma imagem RAW, sem estrutura de
; sistema de arquivos definida (FAT-12, FAT-16, FAT-32, etc). Declarar estes campos
; causaria a leitura incorreta da imagem e falha. Sem declará-los, o BIOs vai tratar
; a imagem de modo default.
;
; Para criar uma imagem de disco formatada como FAT-12, um formato de sistema de
; arquivos do DOS/Windows, veja o exemplo na página 
; https://github.com/kalehmann/SiBoLo. No blog do autor, disponível em 
; https://blog.kalehmann.de/blog/2017/07/20/simple-boot-loader.html, ele comenta
; o passo a passo de como gerar a imagem formatada.
;
; Para criar uma imagem de disco formatada como Ext3, um formato de sistema de
; arquivos do Linux, veja o exemplo na página 
; https://github.com/devekar/Bootloader/tree/master.
;
; =============================================================================


jmp short start
nop




; =============================================================================
;
; PONTO DE ENTRADA DO PROGRAMA
;
;
; Ao executar esta rotina, será configurada a pilha do bootloader e realizados
; alguns ajustes de hardware. Para entender como a pilha será configurada, 
; primeiramente analise o diagrama de como a memória RAM do computador está 
; organizada no momento em que este bootloader é carregado.
;
;
;                               Memory (RAM)
;                    │                                  │
;                    │                                  │
;                    │ Free                             │
;                    │----------------------------------│ 0x100000
;                    │                                  │
;                    │ BIOS                             │
;                    │                                  │
;                    │----------------------------------│ 0xC0000
;                    │                                  │
;                    │ Video Memory (VGA)               │
;                    │                                  │
;                    │----------------------------------│ 0xA0000
;                    │                                  │
;                    │ Extended BIOS Data Area (EBDA)   │
;                    │                                  │
;                    │----------------------------------│ 0x9FC00
;                    │                                  │
;                    │ Free                             │
;                    │                                  │
;                  ┬ │----------------------------------│ 0x7E00
;                  │ │                                  │
;          Stage 1 │ │ Loaded Boot Sector ############# │
;                  │ │                                  │
;                  ┴ │----------------------------------│ 0x7C00
;                    │                                  │
;                    │ Free                             │
;                    │                                  │
;                    │----------------------------------│ 0x500
;                    │                                  │
;                    │ BIOS Data Area (BDA)             │
;                    │                                  │
;                    │----------------------------------│ 0x400
;                    │                                  │
;                    │ Interrupt Vector Table (IVT)     │
;                    │                                  │
;                    ==================================== 0x0
;         
;
; A memória baixa (memória abaixo de 1 megabyte) estará dividida em diversas seções,
; iniciando pela Interrupt Vector Table (IVT), no endereço 0x0. Quando finalizar
; o POST (Power-On Self Test), o BIOS está programado para buscar por um disco
; de inicialização e carregar os 512 bytes que estão gravados no setor MBR (Master
; Boot Record) deste disco para o endereço 0x7C00 da memória. Na sequência, o BIOS
; entrega o controle do computador para este programa.
;
; O programa lido pelo BIOS no setor MBR do disco e carregado no endereço 0x7C00
; da memória será este primeiro estágio do bootloader. As primeiras instruções
; executadas quando o controle do computador for entregue para ele serão as desta
; rotina, que como vimos, configura a pilha do bootloader e o hardware.
;
; O endereço de memória do segmento de pilha, apontado pelo registrador de segmento
; SS, será o 0x9000. Este endereço não foi escolhido ao acaso. Ele foi calculado
; para a pilha ocupar o espaço contíguo de memória logo adiante do segmento de dados
; extras usado pelo Estágio 3, que contém o mapa do jogo da cobrinha e outras 
; variáveis de controle. Uma única pilha será compatilhada pelos três estágios,
; mas não será acessada concorrentemente. Cada estágio a acessa em seu turno.
;
; Para entender como o endereço da pilha foi calculado, veja no diagrama abaixo
; como a memória será alocada pelo bootloader quando os três estágios estiverem
; carregados:
;
;
;         Memory (RAM)                             Bootloader                                                                          
;                                            
; │ Free                     │             │                        │
; │--------------------------│ 0x100000    │                        │  
; │                          │             │ Free                   │                       
; │ BIOS                     │             │------------------------│ 0x18FFF ┬ 
; │                          │             │                        │         │
; │--------------------------│ 0xC0000     │ Stack (65.536 bytes)   │         │
; │                          │             │ 0x9000->0x18FFF        │         │
; │ Video memory             │             │                        │         │
; │                          │             │------------------------│ 0x9000  │
; │--------------------------│ 0xA0000     │                        │         │
; │                          │             │ Map (1.536 bytes)      │         │
; │                          │             │ 0x8A00->0x8FFF         │         │
; │ Extended BIOS Data Area  │             │                        │         │
; │                          │             │------------------------│ 0x8A00  │
; │                          │             │                        │         │
; │--------------------------│ 0x9FC00     │ Stage 3 (2.048 bytes)  │         │
; │                          │             │ 0x8200->0x89FF         │         │
; │--                      --│-0x18FFF ┬   │                        │         │
; │ Free                     │         │   │------------------------│ 0x8200  │
; │                          │         │   │                        │         │
; │                          │         │   │ Stage 2 (1.024 bytes)  │         │
; ├──────────────────────────┤ 0x7E00  ┼   │ 0x7E00->0x81FF         │         │
; │ Loaded Boot Sector       │         │   │                        │         │
; ├──────────────────────────┤-0x7C00  ┴   ├────────────────────────┤ 0x7E00  ┼
; │ Free                     │             │                        │         │
; │                          │             │ Stage 1 (512 bytes)    │         │
; │--------------------------│ 0x500       │ 0x7C00->0x7DFF         │         │
; │ BIOS Data Area           │             │                        │         │
; │--------------------------│ 0x400       ├────────────────────────┤ 0x7C00  ┴
; │ Interrupt Vector Table   │             │ Free                   │                            
; ============================ 0x0         │                        │                                         
;
;             (a)                                     (b)
;
;   (a) Área de memória do bootloader (endereços de 0x7C00 a 0x18FFF). (b) Organização
;   do bootloader na memória. 
;
;   A memória alocada para o bootloader estará dividida nas seguintes seções:
;     
;   Stage 1 (Estágio 1)
;
;   O Estágio 1, com 512 bytes, lido pelo BIOS do setor MBR do disco (setor de
;   boot), ocupa os endereços de memória de 0x7C00 até 0x7DFF. É função do estágio
;   1 configurar o hardware e carregar na memória o Estágio 2.
;
;   Stage 2 (Estágio 2)
;
;   O Estágio 2, com 1024 bytes, ocupa os endereços de memória de 0x7E00 até 0x81FF.
;   Ele corresponde ao menu do sistema operacional Fakenix. Sua função é carregar
;   o Estágio 3, que num sistema prático, carregaria o Kernel do sistema operacional
;   na memória.
;
;   Stage 3 (Estágio 3)
;
;   O Estágio 3, com 2048 bytes, ocupa os endereços de 0x8200 até 0x89FF. Este
;   estágio, num sistema prático, seria o programa que carregaria o kernel do
;   sistema operacional na memória. Como não existe um sistema operacional, será
;   carregado o jogo da cobrinha, em modo real.
;
;   Map (Mapa do jogo da cobrinha)
;
;   O Estágio 3 alocará ainda os endereços de 0x8A00 até 0x8FFF, o que equivale
;   a 1536 bytes, para o mapa do jogo da cobrinha e variáveis de controle. 
;
;   Stack (Pilha do bootloader)
;
;   A pilha será posicionada logo adiante do mapa do jogo da  cobrinha, iniciando
;   no endereço 0x9000 e ocupando 65536 bytes. 
;
;
; Os registradores SS (Stack Segment) e SP (Stack Pointer) são utilizados para
; delimitar o segmento de memória da pilha. SS aponta para o endereço inicial da
; pilha (base da pilha), que como já vimos, será o endereço físico 0x9000, e SP
; aponta para o endereço do topo da pilha.
;
; Até este ponto, tudo foi calculado com base no endereço físico de memória de
; cada estágio do bootloader. Mas para calcular os valores de SS e SP, o esquema
; de endereçamento de segmentos na arquitetura x86 em modo real é tratado pelo
; processador da seguinte forma:
;
;
;   Endereço Físico = (Base do Segmento * 0x10) + Deslocamento
;
;
; Isso significa que para posicionar o início da pilha no endereço físico 0x9000,
; o registrador de segmento SS (Base do Segmento) deve receber o valor 0x900 
; (0x9000 / 0x10 = 0x900). O valor de SP será o deslocamento (offset) dentro do
; segmento de pilha, que inicia em 0x0. Como a arquitetura x86 usa registradores
; de 16 bits, o valor máximo de deslocamento em SP será 0xFFFF.
;
; Para calcular o endereço físico apontado por SP = 0xFFFF, que é o limite superior
; da pilha, fazemos:
;
;
;   (0x900 * 0x10) + 0xFFFF → 0x9000 + 0xFFFF → 0x18FFF
;
;
; Inicialmente, o offset do segmento de pilha deve iniciar em 0xFFFF, com SP
; apontando para o endereço físico 0x18FFF, pois o modo de alocação de memória do
; segmento de pilha é diferente do dos demais segmentos. Enquanto naqueles a memória
; é gravada do endereço de menor valor para o de maior, na pilha, o sentido é o
; inverso. Ela é gravada do endereço de maior valor para o de menor.
;
;
; 
;          │                        │
;          │                        │
;       ┬  │------------------------│ 0x18FFF ← SP (offset 0xFFFF)
;       │  │                        │ 0x18FFE
;       │  │                        │ 0x18FFD
;       │  │                        │ 0x18FFC
;       │  │                        │
;       .  ..........................
; Pilha .  ..........................        
;       .  ..........................
;       |  |                        |
;       │  │                        │ 0x9003
;       │  │                        │ 0x9002
;       │  │                        │ 0x9001
;       ┴  │------------------------│ 0x9000 ← SS (Base do segmento de pilha) 
;          │                        │
;          │                        │
; 
; 
; Ao realizar uma operação push (empilhar), por exemplo, "push ax", o valor do
; registrador AX, que têm dois bytes, é gravado na pilha, e o ponteiro SP é
; declementado em duas unidades, passando a apontar para o endereço físico 0x18FFD,
; passando este endereço a ser o novo topo da pilha.
;
;  
;          │                        |
;          │                        │
;          │------------------------│ 0x18FFF   ⇣
;          │ 0  1  0  0  1  1  1  0 │ 0x18FFE   ⇣
;          │ 1  1  1  0  1  0  1  1 │ 0x18FFD ← SP
;          │                        │ 0x18FFC
;          │                        │
;          ..........................
;          ..........................            
;          ..........................
;          |                        |
;          │                        │ 0x9003
;          │                        │ 0x9002
;          │                        │ 0x9001
;          │------------------------│ 0x9000 ← SS
;          │                        │
;          │                        │
;  
;
; Ao realizar a operação inversa, "pop ax" (desempilhar), o valor do ponteiro SP
; volta para o endereço 0x18FFF:
;
;
;          │                        │
;          │                        │
;          │------------------------│ 0x18FFF ← SP
;          │ 0  1  0  0  1  1  1  0 │ 0x18FFE   ⇡
;          │ 1  1  1  0  1  0  1  1 │ 0x18FFD   ⇡
;          │                        │ 0x18FFC
;          │                        │
;          ..........................
;          ..........................            
;          ..........................
;          |                        |
;          │                        │ 0x9003
;          │                        │ 0x9002
;          │                        │ 0x9001
;          │------------------------│ 0x9000 ← SS
;          │                        │
;          │                        │
;  
;
; Os bytes copiados do registrador AX para os endereços 0x18FFE e 0x18FFD permanecem
; na memória quando desempilha, e serão sobrescritos na próxima operação push.
;
; Na sequência serão aplicadas as configurações de hardware. Primeiramente configura
; o PIT (Programmable Interval Timer), que é um chip de temporização usado para 
; gerar interrupções periódicas, que na configuração default emite um tick a cada
; cerca de 55 ms, para emitir um tick a cada 50 ms. Outra configuração, que é 
; default, mas que será definida explicitamente, será o modo de vídeo, que aqui 
; é configurado para o modo VGA 3h (80 caracteres x 25 linhas). A configuração 
; de vídeo será trocada no Estágio 3 para "VGA 13h", para exibir pixels na tela 
; quando for renderizar o jogo da cobrinha.
;
; =============================================================================


start:

	mov [drive_number], dl        ; Obtém o número do drive de boot, que
	                              ; inicialmente está gravado em DL.

	cli                           ; Interrompe as interrupções mascaráveis para
                                  ; configurar a pilha e o hardware.

    ; -------------------------------------------------------------------------
	; Configura a pilha do bootloader no endereço 0x9000.
	; -------------------------------------------------------------------------

	xor ax, ax                    ; Executa uma operação lógica XOR do registrador
	                              ; AX com ele mesmo, zerando-o.
								  
	mov ds, ax                    ; Faz o registrador de segmento DS apontar para
	                              ; 0x0.
								  
	mov es, ax                    ; Faz o registrador de segmento ES apontar para
	                              ; 0x0.
								  
	mov ax, 0x0900                ; Copia o valor 0x900 para AX.
	
	mov ss, ax                    ; Define a base da pilha SS (Stack Segment) em
	                              ; 0x9000 (0x0900 x 0x10).
								  
	mov sp, 0xFFFF                ; Move o ponteiro SP (Stack Pointer) para o topo
	                              ; da pilha (offset 0xFFFF).
	
	; -------------------------------------------------------------------------
	; Faz o reset do disco, preparando-o para a leitura do segundo estágio.
	; -------------------------------------------------------------------------
	
	mov dl, [drive_number]        ; Copia o código do drive do boot em DL.
	
	xor ax, ax                    ; Define a função 0 da interrupção de disco 
	                              ; (reset do disco).
								  
	int 0x13                      ; Chama a interrupção de disco do BIOS para 
	                              ; reset dos controladores de disco.
								  
	jc disk_error                 ; Se a flag de carry (CF) estiver definida 
	                              ; como 1, salta para o tratador de erro.

	; -------------------------------------------------------------------------
	; Configura o PIT via PMIO (Port-Mapped I/O), fazendo com que cada ciclo do 
	; relógio tenha exatos 50 ms (20 Hz).
	; -------------------------------------------------------------------------
	
	mov al, 0x36                  ; Configura o PIT no modo 3 (Square Wave Generator
	                              ; - gerador de onda quadrada).
								  
	out 0x43, al                  ; Envia o comando de configuração para a porta
	                              ; 43h.
								  
	mov ax, 59659                 ; Define o divisor para obter exatos 50 ms 
	                              ; (1.193.180 pulsos segundo / 59.659 = 20 Hz).
								  
	out 0x40, al                  ; Envia o byte menos significativo em AL.
	
	mov al, ah                    ; Copia AH em AL.
	
	out 0x40, al                  ; Envia o byte mais significativo em AH.

	; -------------------------------------------------------------------------
	; Configura o modo de vídeo para modo texto 80x25 (80 colunasx25 linhas).
	; -------------------------------------------------------------------------

	mov ah, 0x00                  ; Define a função 0 da interrupção de vídeo.
	
    mov al, 0x03                  ; Define o modo de vídeo como modo texto 80x25
	                              ; (modo 3h).
	
    int 0x10                      ; Chama a interrupção do BIOS que configura o 
	                              ; modo de vídeo.

	sti                           ; Retoma as interrupções mascaráveis.
	
	
	
	
; =============================================================================
;
; CARREGAMENTO DO ESTÁGIO 2 (MENU DO SISTEMA OPERACIONAL)
;
;
; Esta rotina carrega o Estágio 2 na memória RAM, que implementa o menu do sistema
; operacional. O Estágio 2 tem 1024 bytes, ocupando o segundo e terceiro setores
; do disco, logo adiante do Estágio 1, que está no MBR.
;
; Para carregar o Estágio 2 via CHS (Cylinder-Head-Sector), será executada a
; interrupção de disco 0x13 do BIOS, que precisa de alguns parâmetros definidos:
;
;   * AH: O valor de AH define qual operação de disco será realizada. O valor 0x02
;     corresponde a leitura do disco.
;
;   * AL: O valor de AL define quantos setores do disco devem ser carregados para
;     a memória. Como o segundo estágio tem 1024 bytes, e o tamanho default do setor 
;     é de 512 bytes, o valor de AL deve ser 2.
;
;   * CH: O valor de CH define o cilindo do disco (no caso, será o cilindro 0).
;
;   * CL: O valor de CL define o setor do disco a partir do qual se inicia a leitura.
;     No caso, o setor será o 2, já que o setor 1 é o código deste primeiro estágio
;     no MBR.
;
;   * DH: O valor de DH define a cabeça de leitura do disco (no caso, será a cabeça
;     0).
;
;   * DL: O valor de DL define o código do drive de boot.
;
;   * BX: O valor de BX define o endereço da memória em que será carregado o estágio
;     2. No caso, o segundo estágio será carregado no endereço 0x7E00.
;
; Definidos os valores de execução da interrupção 0x13, esta é chamada, causando
; o carregamento do segundo estágio na memória pelo BIOS.
;
; Pode ocorrer falhas antes de uma leitura correta do disco. Mas para simplificar
; o código ao máximo, se ocorrer uma falha na primeira tentativa, aborta a execução.
; Num sistema prático, seria necessário fazer um loop, para realizar diversas
; tentativas em caso de falha na tentativa inicial.
;
; =============================================================================


load_stage2:

	mov ah, 0x02                  ; Define a função 2 da interrupção de disco (ler
	                              ; setores do disco).
						
	mov al, 2                     ; Define que 2 setores devem ser carregados 
	                              ; para a memória RAM.
	
	mov ch, 0                     ; O cilindro do disco é definido como 0 (padrão).
	
	mov cl, 2                     ; Define o setor do disco aonde inicia a leitura,
	                              ; que é o 2.
	
	mov dh, 0                     ; A cabeça de leitura do disco é 0 (padrão).
	
    mov dl, [drive_number]        ; Código do drive de boot.
	
	mov bx, 0x7E00                ; Endereço na memória RAM aonde o Estágio 2 será
	                              ; carregado e executado.
								  
    int 0x13                      ; Chama a interrupção de disco, para ler os setores
	                              ; do Estágio 2 e carregar na memória RAM.
								  
    jc disk_error                 ; Se a flag de carry (CF) estiver definida como
	                              ; 1, salta para o tratador de erro de disco.
	
	mov dl, [drive_number]        ; O código do drive de boot está salvo em 
	                              ; [drive_number]. Copia para DL, para ser usado
								  ; pelo Estágio 2.
								  
    jmp 0x0000:0x7E00             ; Entrega o controle do programa para o 
	                              ; Estágio 2 (far jump). 




; =============================================================================
;
; TRATAMENTO DE ERRO NA LEITURA DO DISCO
;
;
; Esta rotina é executada se acontecer algum erro na leitura do Estágio 2 no 
; disco e carregamento para a memória. Neste caso, exibe uma mensagem informando
; que houve erro, e também solicitando para teclar ENTER para encerrar a execução
; e desligar o computador. 
;
; =============================================================================


disk_error:

	mov si, disk_error_str        ; Copia o endereço de memória da string error_str
	                              ; para SI.
								  
	call print_string             ; Imprime a string de erro.
	
	call wait_enter               ; Aguarda teclar ENTER para continuar.
								  
	call shutdown                 ; Chama a função para desligar o computador via
	                              ; APM.




; =============================================================================
;
; IMPORTAÇÃO DE CÓDIGO COMPARTILHADO
;
;
; Importa rotinas compartilhadas pelos 3 estágios do bootloader do arquivo de 
; código-fonte "shared.asm".
;
; =============================================================================


imports:

	%include "shared.asm"




; =============================================================================
; SEÇÃO DE DADOS DO PROGRAMA
; =============================================================================


drive_number:                     ; Número do drive de boot.

	db 0x00
	
	
disk_error_str:                   ; String de erro na leitura do disco.
 
	db 0x0D, 0x0A
	db 'Erro na leitura do disco.'
	db 0x0D, 0x0A, 0x0D, 0x0A
	db 'Tecle ENTER para sair.', 0x00




; =============================================================================
; ASSINATURA DO SETOR DE BOOT
;
;
; O Setor de Boot deve ter os dois últimos bytes 0x55AA. O byte no offset 0x01FE 
; recebe o valor 0x55 e o byte no offset 0x01FF recebe o valor 0xAA. Isto constitui
; uma assinatura informando que é um disco inicializável para o firmware BIOS.
; Sem esta assinatura, mesmo o programa estando correto, o BIOS saltaria para o 
; próximo disco na lista de boot, buscando por um MBR assinado com estes dois 
; bytes.
; =============================================================================


times 510 - ($ - $$) db 0x00      ; Completa o restante dos bytes do arquivo, que
                                  ; não são instruções ou dados, com zeros, até 
								  ; o offset 510.

dw 0xAA55                         ; Como a arquitetura x86 é little-endian, os 
                                  ; bytes da assiantura devem ser escritos invertidos.