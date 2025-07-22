
; Este código em Assembly implementa o estágio 1 do bootloader, que será gravado no setor MBR (Master
; Boot Record) do disco. O estágio 1 carregará na memória o estágio 2, que é o programa que exibe o
; menu do sistema operacional FAKENIX e carrega o estágio 3, que é o kernel fictício do jogo da cobrinha.
;
; Este é um projeto básico, que tem como objetivo única e exclusivamente demonstrar o processo em que o
; hardware e o software interagem para "dar vida" ao computador, desmistificando um pouco como um computador
; realmente funciona e instigando o estudante a buscar mais informações sobre o tema. Se você deseja se 
; aprofundar mais no tema de desenvolvimento de sistemas operacionais, sugiro que visite a página
; http://www.brokenthorn.com/Resources/OSDevIndex.html que contém um ótimo material para iniciantes, e
; também a página https://www.independent-software.com/operating-system-development.html, onde te instrui
; passo-a-passo como desenvolver um sistema operacional "do zero".
; 
; Se sua intenção é entender um sistema operacional real, depois de ter uma noção básica de como o bootloader
; funciona, recomendo que analise o código do MS DOS, disponibilizado pela Microsoft na página do github
; em https://github.com/microsoft/MS-DOS/tree/main, e o código-fonte do Minix, disponível no github em
; https://github.com/Stichting-MINIX-Research-Foundation/minix. 
;
; Se se interessou pelo tema assembly e aspectos da programação em baixo nível, recomendo ainda que analise
; um sistema operacional construído inteiramente nesta linguagem. Trata-se do MinuetOS, disponível na página 
; https://www.menuetos.net/.


[BITS 16]               ; O programa do estágio 1 roda em modo real de 16 bits.
[ORG 0x7C00]            ; O programa será executado no endereço padrão 0x7C00.




; Instrução de salto, para manter o alinhamento das instruções no MBR.  (offset: 0x0000 -> 3 bytes)
;
; Na sequência a estas instruções seriam declarados os campos do BPB/EPBP. Nesta imagem de disco NÃO
; devem ser declarados estes campos, pois é uma imagem RAW, sem estrutura de sistema de arquivos definida
; (FAT-12, FAT-16, FAT-32, etc). Declarar estes campos causaria a leitura incorreta da imagem e falha.
; Sem declará-los, o BIOs vai tratar a imagem de modo default, sem pressupor qualquer estrutura de
; sistema de arquivos.
;
; Para criar uma imagem de disco formatada como FAT-12, um formato de sistema de arquivos do DOS/Windows,
; veja o exemplo na página https://github.com/kalehmann/SiBoLo. No blog do autor, disponível em 
; https://blog.kalehmann.de/blog/2017/07/20/simple-boot-loader.html, ele comenta o passo-a-passo de
; como gerar a imagem formatada.
;
; Para criar uma imagem de disco formatada como Ext3, um formato de sistema de arquivos do Linux, veja
; o exemplo na página https://github.com/devekar/Bootloader/tree/master.

jmp short start
nop




; Ponto de entrada do programa.                                       (offset: 0x0003 -> 507 bytes)


; Ao executar esta função, será configurada a pilha do bootloader e realizados alguns ajustes de hardware.
; Para entender como a pilha será configurada, primeiramente analise o diagrama de como a memória RAM
; do computador está organizada no momento em que este bootloader é carregado.
;
;
;                                       Memory (RAM)
;                            │                                  │
;                            │                                  │
;                            │ Free                             │
;                            │----------------------------------│ 0x100000
;                            │                                  │
;                            │ BIOS (256 kB)                    │
;                            │                                  │
;                            │----------------------------------│ 0xC0000
;                            │                                  │
;                            │ Video memory (128 kB)            │
;                            │                                  │
;                            │----------------------------------│ 0xA0000
;                            │                                  │
;                            │                                  │
;                            │ Extended BIOS Data Area (639 kB) │
;                            │                                  │
;                            │                                  │
;                            │----------------------------------│ 0x9FC00
;                            │                                  │
;                            │                                  │
;                            │ Free (638 kB)                    │
;                            │                                  │
;                            │                                  │
;                            │----------------------------------│ 0x7E00
;                            │ Loaded boot sector (512 bytes)   │          <-- This stage!
;                            │----------------------------------│ 0x7C00
;                            │                                  │
;                            │                                  │
;                            │----------------------------------│ 0x500
;                            │ BIOS data area (256 bytes)       │
;                            │----------------------------------│ 0x400
;                            │ Interrupt vector table (1 kB)    │
;                            ==================================== 0x0
;
;
; A memória baixa (memória abaixo de 1 megabyte) estará dividida em diversas seções, iniciando pela
; Interrupt Vector Table (IVT), no endereço 0x00. Quando finalizar o POST (Power-On Self Test), o BIOS
; está programado para buscar por um disco de inicialização e carregar os 512 bytes que estão gravados
; no setor MBR (Master Boot Record) deste disco para o endereço 0x7C00 da memória. Na sequência, o BIOS
; entrega o controle do computador para este programa.
;
; O programa lido pelo BIOS no setor MBR do disco e carregado no endereço 0x7C00 da memória será este
; primeiro estágio do bootloader. As primeiras instruções executadas quando o controle do computador
; for entregue para ele serão as desta função, que como vimos, configura a pilha do bootloader e o 
; hardware.
;
; O endereço de memória do segmento de pilha, apontado pelo registrador de segmento SS, será o 0x9000.
; Este endereço não foi escolhido ao acaso. Ele foi calculado para a pilha ocupar o espaço contíguo de
; memória logo adiante do segmento de dados extras usado pelo estágio 3, que contém o mapa do jogo da
; cobrinha e outras variáveis de controle. Uma única pilha será compatilhada pelos três estágios.
;
; Para entender como o endereço da pilha foi calculado, veja no diagrama abaixo como a memória será
; alocada pelo bootloader quando os três estágios estiverem carregados:
;
;
;            Memory (RAM)                                                
; │                                  │                                      
; │                                  │                          Bootloader (69 kB)
; │ Free                             │                 │                                  │
; │----------------------------------│ 0x100000        │                                  │  
; │                                  │                 │ Free                             │                       
; │ BIOS (256 kB)                    │                 │----------------------------------│ 0x18FFF ┬ 
; │                                  │                 │                                  │         │
; │----------------------------------│ 0xC0000         │ Stack (65.536 bytes)             │         │
; │                                  │                 │ (Addr.: 0x9000->0x18FFF)         │         │
; │ Video memory (128 kB)            │                 │                                  │         │
; │                                  │                 │----------------------------------│ 0x9000  │
; │----------------------------------│ 0xA0000         │                                  │         │
; │                                  │                 │ Map (1.536 bytes)                │         │
; │                                  │                 │ (Addr.: 0x8A00->0x8FFF)          │         │
; │ Extended BIOS Data Area (639 kB) │                 │                                  │         │
; │                                  │                 │----------------------------------│ 0x8A00  │
; │                                  │                 │                                  │         │
; │----------------------------------│ 0x9FC00         │ Stage 3 (2.048 bytes)            │         │
; │                                  │                 │ (Addr.: 0x8200->0x89FF)          │         │
; │--                              --│-0x18FFF ┬       │                                  │         │
; │ Free (638 kB)                    │         │       │----------------------------------│ 0x8200  │
; │                                  │         │       │                                  │         │
; │                                  │         │       │ Stage 2 (1.024 bytes)            │         │
; │----------------------------------│ 0x7E00  ┼       │ (Addr.: 0x7E00->0x81FF)          │         │
; │ Loaded boot sector (512 bytes)   │         │       │                                  │         │
; │----------------------------------│-0x7C00  ┴       │----------------------------------│ 0x7E00  ┼
; │                                  │                 │                                  │         │
; │                                  │                 │ Stage 1 (512 bytes)              │         │
; │----------------------------------│ 0x500           │ (Addr.: 0x7C00->0x7DFF)          │         │
; │ BIOS data area (256 bytes)       │                 │                                  │         │
; │----------------------------------│ 0x400           |----------------------------------│ 0x7C00  ┴
; │ Interrupt vector table (1 kB)    │                 │                                  │                            
; ==================================== 0x0             │                                  │                                         
;
;                 (a)                                                  (b)
;
;         (a) Área de memória do bootloader (endereços de 0x7C00 a 0x18FFF). (b) Organização
;         do bootloader na memória. 
;
;         A memória alocada para o bootloader estará dividida nas seguintes seções:
;     
;         Stage 1 (Estágio 1)
;
;         O estágio 1, com 512 bytes, lido pelo BIOS do setor MBR do disco (setor de boot),
;         ocupa os endereços de memória de 0x7C00 até 0x7DFF. É função do estágio 1 configurar
;         o hardware e carregar na memória o estágio 2.
;
;         Stage 2 (Estágio 2)
;
;         O estágio 2, com 1024 bytes, ocupa os endereços de memória de 0x7E00 até 0x81FF.
;         Ele corresponde ao menu do sistema operacional Fakenix. Sua função é carregar o 
;         estágio 3, que num sistema prático, carregaria o Kernel do sistema operacional na 
;         memória.
;
;         Stage 3 (Estágio 3)
;
;         O estágio 3, com 2048 bytes, ocupa os endereços de 0x8200 até 0x89FF. Este estágio,
;         num sistema prático, seria o programa que carregaria o kernel do sistema operacional
;         na memória. Como não existe um sistema operacional, será carregado o jogo da cobrinha,
;         em modo real.
;
;         Map (Mapa do jogo da cobrinha)
;
;         O estágio 3 alocará ainda os endereços de 0x8A00 até 0x8FFF, o que equivale a 1536
;         bytes, para o mapa do jogo da cobrinha e variáveis de controle. 
;
;         Stack (Pilha do bootloader)
;
;         A pilha será posicionada  logo adiante do mapa do jogo da  cobrinha, iniciando no
;         endereço 0x9000 e ocupando 65536 bytes. 
;
;
; Os registradores SS (Stack Segment) e SP (Stack Pointer) são utilizados para delimitar o segmento de
; memória da pilha. SS aponta para o endereço inicial da pilha, que como já vimos, será o endereço físico
; 0x9000, e SP aponta para o endereço do topo da pilha.
;
; Até este ponto, tudo foi calculado com base no endereço físico de memória de cada estágio do bootloader.
; Mas para calcular os valores de SS e SP, o esquema de endereçamento de segmentos na arquitetura x86
; em modo real é tratado pelo processador da seguinte forma:
;
;                     Endereço Físico = (Base do Segmento * 0x10) + Deslocamento
;
; Isso significa que para posicionar o início da pilha no endereço físico 0x9000, o registrador de
; segmento SS (Base do Segmento) deve receber o valor 0x900 (0x9000 / 0x10 = 0x900). O valor de SP será
; o deslocamento (offset) dentro do segmento de pilha, que inicia em 0x0. Como a arquitetura x86 usa
; registradores de 16 bits, o valor máximo de deslocamento em SP será 0xFFFF.
;
; Para calcular o endereço físico apontado por SP = 0xFFFF, que é o limite superior da pilha, fazemos:
;
;                     (0x900 * 0x10) + 0xFFFF -> 0x9000 + 0xFFFF -> 0x18FFF
;
; Inicialmente, o offset do segmento de pilha deve iniciar em 0xFFFF, com SP apontando para o endereço
; físico 0x18FFF, pois o modo de alocação de memória do segmento de pilha é diferente do dos demais 
; segmentos. Enquanto naqueles a memória é gravada do endereço de menor valor para o de maior, na pilha,
; o sentido é o inverso. Ela é gravada do endereço de maior valor para o de menor.
;
;
;                                  │                        │
;                                  │                        │
;                               ┬  │------------------------│ 0x18FFF <- SP (offset 0xFFFF)
;                               │  │                        │ 0x18FFE
;                               │  │                        │ 0x18FFD
;                               │  │                        │ 0x18FFC
;                               │  │                        │
;                               .  ..........................
;                         Pilha .  ..........................        
;                               .  ..........................
;                               |  |                        |
;                               │  │                        │ 0x9003
;                               │  │                        │ 0x9002
;                               │  │                        │ 0x9001
;                               ┴  │------------------------│ 0x9000 <- SS (Base do segmento de pilha) 
;                                  │                        │
;                                  │                        │
;
;
; Ao realizar uma operação push (empilhar), por exemplo, "push ax", o valor do registrador AX, que têm
; dois bytes, é gravado na pilha, e o ponteiro SP é declementado em duas unidades, passando a apontar
; para o endereço físico 0x18FFD, passando este endereço a ser o novo topo da pilha.
;
;
;                                  │                        |
;                                  │                        │
;                                  │------------------------│ 0x18FFF   ↓
;                                  │ 0  1  0  0  1  1  1  0 │ 0x18FFE   ↓
;                                  │ 1  1  1  0  1  0  1  1 │ 0x18FFD <- SP
;                                  │                        │ 0x18FFC
;                                  │                        │
;                                  ..........................
;                                  ..........................            
;                                  ..........................
;                                  |                        |
;                                  │                        │ 0x9003
;                                  │                        │ 0x9002
;                                  │                        │ 0x9001
;                                  │------------------------│ 0x9000 <- SS
;                                  │                        │
;                                  │                        │
;
;
; Ao realizar a operação inversa, "pop ax" (desempilhar), o valor do ponteiro SP volta para o endereço
; 0x18FFF:
;
;
;                                  │                        │
;                                  │                        │
;                                  │------------------------│ 0x18FFF <- SP
;                                  │ 0  1  0  0  1  1  1  0 │ 0x18FFE   ↑
;                                  │ 1  1  1  0  1  0  1  1 │ 0x18FFD   ↑
;                                  │                        │ 0x18FFC
;                                  │                        │
;                                  ..........................
;                                  ..........................            
;                                  ..........................
;                                  |                        |
;                                  │                        │ 0x9003
;                                  │                        │ 0x9002
;                                  │                        │ 0x9001
;                                  │------------------------│ 0x9000 <- SS
;                                  │                        │
;                                  │                        │
;
;
; Os bytes copiados do registrador AX para os endereços 0x18FFE e 0x18FFD permanecem na memória quando
; desempilha, e serão sobrescritos na próxima operação push.
;
; ┌────────────────────────────────────────────────────────────────────────────────────────────────────┐
; │ Obs.: Para testar o comportamento da pilha, execute o código do arquivo "test-stack.asm", na pasta │
; │ do projeto. Este programa empilha valores quando se tecla ENTER e desempilha quando se tecla       │
; │ BACKSPACE. Na sequência imprime o valor em SS e SP, no formato hexadecimal. A pilha está sendo     │
; │ posicionada em 0x9000 e o offset inicial é 0xFFFF, como neste programa.                            │
; └────────────────────────────────────────────────────────────────────────────────────────────────────┘
;
; Na sequência da definição da pilha, serão aplicadas as configurações de hardware. Primeiramente 
; Configura o PIT (Programmable Interval Timer), que é um chip de temporização usado para gerar interrupções
; periódicas, que na configuração default emite um tick a cada cerca de 55 ms, para emitir um tick a
; cada 50 ms. Outra configuração, que é default, mas que será definida explicitamente, será o modo de
; vídeo, que aqui é configurado para o modo VGA 80 caracteres e 25 linhas. A configuração de vídeo será
; trocada no estágio 3, para "modo VGA 13h", para exibir pixels na tela quando for renderizar o jogo da
; cobrinha.

start:

	cli                 ; Interrompe as interrupções mascaráveis para configurar o programa.

	; Configura a pilha do bootloader no endereço 0x9000 (todos estágios utilizarão a mesma pilha).

	xor ax, ax          ; Executa uma operação lógica XOR do registrador AX com ele mesmo, zerando-o.
	mov ds, ax          ; Faz o registrador de segmento DS apontar para 0x0.
	mov es, ax          ; Faz o registrador de segmento ES apontar para 0x0.
	mov ax, 0x0900      ; Copia o valor 0x900 para AX.
	mov ss, ax          ; Define a base da pilha SS (Stack Segment) em 0x9000 (0x0900 x 0x10). 
	mov sp, 0xFFFF      ; Move o ponteiro SP (Stack Pointer) para o topo da pilha.
	
	; Faz o reset do disco, preparando-o para a leitura do segundo estágio.
	
	mov dl, 0x80        ; Código do drive de boot (0x80 é disco rígido).
	xor ax, ax          ; Define a função 0 da interrupção de disco (reset do disco).
	int 0x13            ; Chama a interrupção de disco do BIOS para resetar os controladores de disco.
	jc disk_error       ; Se a flag de carry (CF) estiver definida como 1, salta para o tratador de erro.

	; Configura o PIT, fazendo com que cada ciclo do relógio tenha exatos 50 ms (20 Hz).
	
    mov al, 0x8B        ; Desativa as interrupções periódicas do RTC.
    out 0x70, al        ; Envia o comando para a porta de controle do RTC.
    in al, 0x71         ; Lê o valor atual do registro.
    and al, 0xF0        ; Desativa apenas as interrupções periódicas.
    out 0x71, al        ; Escreve o valor de volta no RTC.
	
	mov al, 0x36        ; Configura o PIT no modo 3 (Square Wave Generator - gerador de onda quadrada).
	out 43h, al         ; Envia o comando de configuração para a porta 43h.
	mov ax, 59659       ; Define o divisor para obter exatos 50 ms (1.193.180 pulsos segundo / 59.659 = 20 Hz).
	out 40h, al         ; Envia o byte menos significativo.
	mov al, ah          ; Copia AL em AH.
	out 40h, al         ; Envia o byte mais significativo.

	; Configura o modo de vídeo para modo texto 80x25 (80 colunas/25 linhas).

	mov ah, 0x00        ; Define a função 0 da interrupção de vídeo.
    mov al, 0x03        ; Define o modo de vídeo como modo texto 80x25.
    int 0x10            ; Chama a interrupção que configura o modo de vídeo.

	sti                 ; Retoma as interrupções mascaráveis.
	
	
	
	
; Esta função carrega o estágio 2 na memória RAM, que implementa o menu do sistema operacional. O estágio
; 2 tem 1024 bytes, ocupando o segundo e terceiro setores do disco, logo adiante do estágio 1, que está
; no MBR.
;
; Para carregar o estágio 2, será executada a interrupção de disco 0x13 do BIOS, que precisa de alguns
; parâmetros definidos:
;
;   * AH: O valor de AH define qual operação de disco será realizada. O valor 0x02 corresponde a leitura
;     do disco.
;
;   * AL: O valor de AL define quantos setores do disco devem ser carregados para a memória. Como o
;     segundo setor tem 1024 bytes, e o tamanho do setor é de 512 bytes, o valor de AL deve ser 2.
;
;   * CH: O valor de CH define o cilindo do disco (no caso, será o cilindro 0).
;
;   * CL: O valor de CL define o setor do disco a partir do qual se inicia a leitura. No caso, o setor
;     será o 2, já que o setor 1 é o código deste primeiro estágio no MBR.
;
;   * DH: O valor de DH define a cabeça de leitura do disco (no caso, será a cabeça 0).
;
;   * DL: O valor de DL define o código do drive de boot.
;
;   * BX: O valor de BX define o endereço da memória em que será carregado o estágio 2. No caso, o 
;     segundo estágio será carregado no endereço 0x07E00.
;
; Definidos os valores de execução da interrupção 0x13, esta é chamada, causando o carregamento do segundo
; estágio na memória pelo BIOS
;
; Pode ocorrer falhas antes de uma leitura correta do disco. Mas para simplificar o código ao máximo, se
; ocorrer uma falha na primeira tentativa, aborta a execução. Num sistema prático, seria necessário fazer
; um loop, para realizar diversas tentativas em caso de falha na tentativa inicial.

load_stage2:

	mov ah, 0x02        ; Define a função 2 da interrupção de disco (ler setores do disco).
	mov al, 2           ; Define que 2 setores devem ser carregados para a memória RAM.
	mov ch, 0           ; O cilindro do disco é definido como 0 (padrão).
	mov cl, 2           ; Define o setor do disco aonde inicia a leitura, que é o 2.
	mov dh, 0           ; A cabeça de leitura do disco é 0 (padrão).
    mov dl, 0x80        ; Código do drive de boot (disco rígido).
	mov bx, 0x7E00      ; Endereço na memória RAM aonde o estágio 2 será carregado e executado.				
    int 0x13            ; Chama a interrupção de disco, para ler os setores e carregar na memória RAM.
    jc disk_error       ; Se a flag de carry (CF) estiver definida como 1, salta para o tratador de erro.
    jmp 0x0000:0x7E00   ; Se a leitura do disco foi bem-sucedida, entrega o controle para o estágio 2 (far jump). 




; Este bloco é executado se acontecer algum erro na leitura do estágio 2 no disco. Neste caso,
; exibe uma mensagem informando que houve erro, e também solicitando ao usuário para teclar ENTER 
; para encerrar a execução e desligar o computador. No rótulo .wait_enter, fica esperando até que o
; usuário tecle ENTER, quando então o computador é desligado.

disk_error:

	mov si, error_str   ; Copia o endereço de memória da string error_str para SI.
    call print_string   ; Imprime a string error_str.
	
.wait_enter:

	mov ah, 0x00        ; Define a função 0 da interrupção de teclado (leitura de tecla).
    int 0x16            ; Chama a interrupção para ler a tecla pressionada.
	cmp al, 0x0D        ; Compara o valor em AL, que armazena o valor da tecla, com 0x0D (Enter).
    jne .wait_enter     ; Se a tecla pressionada não for Enter, volta a ler o teclado novamente.

.power_off:

	cli                 ; Interrompe as interrupções mascaráveis para configurar o programa.

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




; Seção de dados do programa:


error_str: db 0x0D, 0x0A, 'Erro na leitura do disco.', 0x0D, 0x0A, 0x0D, 0x0A, 'Tecle ENTER para sair.', 0

apm_not_found_str: db 'APM BIOS not found!', 0xD, 0xA, 0

apm_conn_fail_str: db 'APM connection failed!', 0xD, 0xA, 0

shutdown_fail_str: db 'Shutdown failed via APM!', 0xD, 0xA, 0




; Completa o restante dos bytes do arquivo, que não são instruções ou dados, com zeros, até o byte 
; 510.

times 510 - ($ - $$) db 0




; Assinatura do setor de boot (Magic Number = 0x55AA)                   (offset: 0x01FE -> 2 bytes)


; O byte no offset 0x01FE recebe o valor 0x55 e o byte no offset 0x01FF recebe o valor 0xAA. Isto 
; constitui uma assinatura informando que é um disco inicializável para o firmware BIOS. Sem esta 
; assinatura, mesmo o programa estando correto, o BIOS saltaria para o próximo disco configurado, 
; buscando por um MBR assinado com estes dois bytes.

dw 0xAA55               ; Como a arquitetura x86 é little-endian, os bytes devem ser escritos invertidos.