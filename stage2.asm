; ═════════════════════════════════════════════════════════════════════════════
;                        STAGE 2 - MULT-STAGE BOOTLOADER
; ═════════════════════════════════════════════════════════════════════════════
;
; Este código em Assembly implementa o Estágio 2 do bootloader. O Estágio 2 
; implementa o menu do sistema operacional, com as opções de testar, instalar ou 
; configurar o boot. As opções são apenas fictícias, pois elas sempre executarão
; o jogo da cobrinha.
;
; ═════════════════════════════════════════════════════════════════════════════


[BITS 16]                         ; O programa do Estágio 2 roda em modo real de
                                  ; 16 bits.
								  
[ORG 0x7E00]                      ; O programa será carregado no endereço 0x07E00.

	
	

; =============================================================================
;	
; PONTO DE ENTRADA DO PROGRAMA
;
;
; A execução deste estágio inicia nesta rotina. A rotina faz o reset da pilha,
; no mesmo endereço configurado pelo Estágio 1, e imprime o cabeçalho.
;
; =============================================================================


start:

	mov [drive_number], dl        ; Obtém o número do drive de boot salvo pelo
	                              ; Estágio 1 em DL.

	cli                           ; Interrompe as interrupções mascaráveis para
	                              ; configurar o programa.

	; -------------------------------------------------------------------------
	; Faz o reset da pilha do bootloader, que está localizada no endereço 0x9000.
	; -------------------------------------------------------------------------
	
	mov sp, 0xFFFF                ; Move o ponteiro SP (Stack Pointer) para o 
	                              ; topo da pilha (offset 0xFFFF).
	
	; -------------------------------------------------------------------------
	; Limpa o terminal completamente e coloca o cursor em (0,0).
	; -------------------------------------------------------------------------
	
	mov ah, 0x06                  ; Define a função 6 da interrupção de vídeo 
	                              ; do BIOS (rolagem de tela).
								  
    mov al, 0x00                  ; Rola toda a tela (valor 0 significa limpar).
	
    mov bh, 0x07                  ; Define o atributo do fundo (cor de texto e
	                              ; cor de fundo).
								  
    mov cx, 0x0000                ; Define a posição inicial (linha 0, coluna 0).
	
    mov dh, 24                    ; Define a linha final da área a ser limpa.
	
    mov dl, 79                    ; Define a última coluna da área a ser limpa.
	
    int 0x10                      ; Chama a interrupção para executar a limpeza
	                              ; do terminal.
	
	mov ah, 0x02                  ; Define a função 2 da interrupção de vídeo 
	                              ; do BIOS (mover cursor).
								  
    mov bh, 0x00                  ; Seleciona a página de vídeo (padrão, página 0).
	
    mov dh, 0x00                  ; Define a linha do cursor (linha 0).
	
    mov dl, 0x00                  ; Define a coluna do cursor (coluna 0).
	
    int 0x10                      ; Chama a interrupção para mover o cursor para
                                  ; a coordenada (0,0).
	
	; -------------------------------------------------------------------------
	; Imprime o cabeçalho do bootloader.
	; -------------------------------------------------------------------------
	
	mov si, header_str            ; Copia o endereço de memória da string header_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string header_str.
	
	mov si, linebr_str            ; Copia o endereço de memória da string linebr_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string linebr_str.

	; -------------------------------------------------------------------------
	; Imprime a borda do cabeçalho.
	; -------------------------------------------------------------------------

	mov ah, 0x0E                  ; Define a função 0x0E da interrupção de vídeo
	                              ; (exibir caractere).

	mov al, ' '                   ; Carrega o caractere ' ' em AL.
	
	int 0x10                      ; Chama a interrupção para imprimir o caractere
	                              ; armazenado em AL no terminal.
    
	mov al, '='                   ; Carrega o caractere '=' em AL.
	
    mov cx, 78                    ; Define o valor 78 em CX, usado como contador
	                              ; de caracteres.

.border_loop:
    
	int 0x10                      ; Chama a interrupção para imprimir o caractere
	                              ; armazenado em AL no terminal.
								  
	loop .border_loop             ; Decrementa o valor de CX e repete o loop (78
	                              ; vezes), enquanto CX for maior ou igual a 0.
	
	mov si, linebr_str            ; Copia o endereço de memória da string linebr_str
	                              ; para SI.
								  
	call print_string             ; Imprime a string linebr_str.
	
	sti                           ; Retoma as interrupções mascaráveis.




; =============================================================================
;
; EXIBIR O MENU
;
;
; Ao executar esta rotina, exibe o menu do sistema operacional e espera a interação
; do usuário, que deve digitar o número do item de menu escolhido.
;
; =============================================================================


show_menu:

	mov [opt], byte 0x00          ; Copia 0x00 para [opt], indicando nenhuma opção
	                              ; de menu selecionada.
	
	call clear_screen             ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu               ; Exibe o menu do sistema operacional.

.wait_key:

    mov ah, 0x00                  ; Define a função 0 da interrupção de teclado 
	                              ; do BIOS (leitura de tecla).
								  
    int 0x16                      ; Chama a interrupção para ler a tecla pressionada,
	                              ; que é armazenada em AL.
	
	                              ; -------------------------------------------
								  ; Opção de menu 1 - Carrega o Estágio 3
	                              ; -------------------------------------------

	cmp al, '1'                   ; Compara o valor em AL com '1'.
	
	je run_os                     ; Se o valor em AL for '1', carrega o estágio 3.
	
	                              ; -------------------------------------------
	                              ; Opção de menu 2 - Carrega o Estágio 3
	                              ; -------------------------------------------
	
	cmp al, '2'                   ; Compara o valor em AL com '2'.
    
	je install_os                 ; Se o valor em AL for '2', carrega o estágio 3.

	                              ; -------------------------------------------
	                              ; Opção de menu 3 - Exibe o menu de opções
	                              ; -------------------------------------------

	cmp al, '3'                   ; Compara o valor em AL com '3'.
	
    je show_option                ; Se o valor em AL for '3', exibe o menu opções.
	
	                              ; -------------------------------------------
	                              ; Opção de menu 4 - Aborta a execução
	                              ; -------------------------------------------
	
	cmp al, '4'                   ; Compara o valor em AL com '4'.
    
	je power_off                  ; Se o valor em AL for '4', aborta a execução.

	                              ; -------------------------------------------
	                              ; Volta a ler o teclado
	                              ; -------------------------------------------

	jmp .wait_key                 ; Se o valor em AL não for '1', '2', '3' ou '4',
	                              ; volta a ler o teclado novamente.




; =============================================================================
;
; EXECUTAR O SISTEMA OPERACIONAL
;
;
; Ao executar esta rotina, simula o carregamento do Sistema Operacional na memória.
; Como não há um sistema operacional real, será carregado o jogo da cobrinha. 
;
; =============================================================================


run_os:
	
	mov [opt], al                 ; Copia AL, que tem armazenado o valor da tecla
	                              ; pressionada, para [opt].
	
	call clear_screen             ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu               ; Imprime o menu, agora obtendo o caractere em
	                              ; [opt] para a resposta.
	
	call skip_a_line              ; Pula uma linha.
	
	mov si, run_str               ; Copia o endereço de memória da string run_str
	                              ; para SI.
								  
	call print_string             ; Imprime a string run_str.
    
	call load_stage3              ; Carrega o estágio 3.




; =============================================================================
;
; INSTALAR O SISTEMA OPERACIONAL
;
;
; Ao executar esta rotina, simula a instalação do Sistema Operacional. Como não
; há um sistema operacional, será carregado o jogo da cobrinha.
;
; =============================================================================


install_os:
	
	mov [opt], al                 ; Copia AL, que tem armazenado o valor da tecla
	                              ; pressionada, para [opt].
	
	call clear_screen             ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu               ; Imprime o menu, agora obtendo o caractere em
	                              ; [opt] para a resposta.
	
	call skip_a_line              ; Pula uma linha.
	
	mov si, install_str           ; Copia o endereço de memória da string run_str
	                              ; para SI.
								  
	call print_string             ; Imprime a string run_str.
	
	call load_stage3              ; Carrega o estágio 3.
	
	
	

; =============================================================================
;
; MOSTRAR OPÇÕES
;
;
; Ao executar esta rotina, exibe o menu de configurações. Como não existe um
; sistema operacional, espera apenas que se tecle ENTER para voltar ao menu
; principal.
;
; =============================================================================


show_option:
	
	mov [opt], al                 ; Copia o valor de AL, que tem armazenado o valor
	                              ; da tecla pressionada, para [opt].
	
	call clear_screen             ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu               ; Imprime o menu, agora obtendo o caractere em
	                              ; BL para a resposta.
	
	call skip_a_line              ; Pula uma linha.
    
	mov si, option_str            ; Copia o endereço de memória da string option_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string option_str.

	call wait_enter               ; Aguarda o usuário teclar ENTER.

.show_menu:
	
	jmp show_menu                 ; Salta para o bloco de exibição do menu.
	
	
	
	
; =============================================================================
;
; DESLIGAR
;
;
; Ao executar esta rotina, usa interrupções de APM para tentar desligar o 
; computador.
;
; =============================================================================

	
power_off:

	mov [opt], al                 ; Copia AL, que tem armazenado o valor da tecla
	                              ; pressionada, para [opt].
	
	call clear_screen             ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu               ; Imprime o menu, agora obtendo o caractere em
	                              ; opt para a resposta.
	
	call skip_a_line              ; Pula uma linha.
	
	call shutdown                 ; Chama a rotina para abortar a execução.


	

; =============================================================================
;
; CARREGAR O ESTÁGIO 3
;
;
; Ao executar esta rotina, carrega o terceiro estágio do bootloader, responsável
; por carregar o kernel do sistema operacional na memória. Como não existe um 
; sistema operacional, carregará o jogo da cobrinha.
;
; Para carregar o Estágio 3 via CHS (Cylinder-Head-Sector), será executada a
; interrupção de disco 0x13 do BIOS, que precisa de alguns parâmetros definidos:
;
;   * AH: O valor de AH define qual operação de disco será realizada. O valor 0x02
;     corresponde a leitura do disco.
;
;   * AL: O valor de AL define quantos setores do disco devem ser carregados para
;     a memória. Como o terceiro estágio tem 2048 bytes, e o tamanho default do setor 
;     é de 512 bytes, o valor de AL deve ser 4.
;
;   * CH: O valor de CH define o cilindo do disco (no caso, será o cilindro 0).
;
;   * CL: O valor de CL define o setor do disco a partir do qual se inicia a leitura.
;     No caso, o setor será o 4, já que o setor 1 é o código do primeiro estágio
;     no MBR e os setores 2 e 3 o código do segundo estágio.
;
;   * DH: O valor de DH define a cabeça de leitura do disco (no caso, será a cabeça
;     0).
;
;   * DL: O valor de DL define o código do drive de boot.
;
;   * BX: O valor de BX define o endereço da memória em que será carregado o 
;     Estágio 3. No caso, o terceiro estágio será carregado no endereço 0x8200.
;
; Definidos os valores de execução da interrupção 0x13, esta é chamada, causando
; o carregamento do terceiro estágio na memória pelo BIOS. Não há loop se houver
; erro no carregamento, e caso ocorra, volta ao menu principal.
;
; =============================================================================

	
load_stage3:
	
	mov dl, [drive_number]        ; Copia o código do drive de boot em DL.
	
	xor ax, ax                    ; Define a função 0 da interrupção de disco 
	                              ; do BIOS (reset do disco).
								  
	int 0x13                      ; Chama a interrupção de disco do BIOS para 
	                              ; reset dos controladores.
								  
	jc disk_error                 ; Se a flag de carry (CF) estiver definida 
	                              ; como 1, salta para o tratador de erro.
	
	call delay                    ; Simula um tempo de processamento para o 
	call delay                    ; carregamento do Estágio 3.
	call delay                    ; ...
	call delay                    ; ...
	call delay                    ; ...
    
	call clear_screen             ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	mov ah, 0x02                  ; Define a função 2 da interrupção de disco (ler
	                              ; setores do disco).
								  
	mov al, 4                     ; Define que 4 setores devem ser carregados para
	                              ; a memória RAM.
								  
	mov ch, 0                     ; O cilindro do disco é definido como 0 (padrão).
	
	mov cl, 4                     ; Define o setor do disco aonde inicia a leitura,
	                              ; que é o 4.
								  
	mov dh, 0                     ; A cabeça de leitura do disco é 0 (padrão).
	
	mov dl, [drive_number]        ; O código do drive de boot está salvo em 
	                              ; [drive_number].
	
	mov bx, 0x8200                ; Endereço na memória RAM aonde o terceiro estágio
	                              ; será carregado.
								  
	int 0x13                      ; Chama a interrupção de disco do BIOS, para 
	                              ; ler os setores e carregar na memória RAM.
								  
	jc disk_error                 ; Se a flag de carry (CF) estiver definida como
	                              ; 1, salta para o tratador de erro de disco.
								  
	jmp 0x0000:0x8200             ; Entrega o controle do programa para o 
	                              ; Estágio 3 (far jump).
	
	
	
	
; =============================================================================
;
; IMPRIMIR MENU
;
;
; Ao executar esta rotina, imprime o menu do bootloader. Ao imprimir o menu, 
; verifica se o valor em [opt] é zero. Esta variável tem salvo nela a tecla que
; foi pressionada no teclado.
; 
; Se [opt] é zero (0x00), significa que não foi pressionada qualquer tecla de 
; menu. Neste caso, imprime apenas as opções do menu. Se [opt] é diferente de 
; zero, significa que foi pressionada a tecla 1, 2, 3 ou 4, correspondendo a uma
; das opções do menu. Neste caso, imprime o número da tecla pressionada que está
; em [opt] na frente do texto "Escolha uma opção: ".
;
; =============================================================================


print_menu:
    
	mov si, menu_str              ; Copia o endereço de memória da string menu_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string menu_str.
	
	cmp byte [opt], 0x00          ; Compara o valor em [opt] com 0x00.
	
	je .done                      ; Se o valor em [opt] for 0x00, não há a opção 
	                              ; digitada pelo usuário e salta para .done.
								  
	mov ah, 0x0E                  ; Define a função 0x0E da interrupção de vídeo 
	                              ; do BIOS (exibir caractere).
								  
    mov al, byte [opt]            ; Copia o caractere salvo em [opt] para AL.
	
	int 0x10                      ; Chama a interrupção para imprimir o caractere
	                              ; armazenado em AL no terminal.

.done:
	
	ret                           ; Retorna o controle para o ponto de chamada.




; =============================================================================
;
; PULAR UMA LINHA
;
;
; Ao executar esta rotina, salta uma linha no terminal (equivalente a usar "\n\n" 
; em linguagens de programação de alto nível).
;
; =============================================================================


skip_a_line:

	mov si, line_str              ; Copia o endereço de memória da string line_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string line_str.

	ret                           ; Retorna o controle para o ponto de chamada.




; =============================================================================
;
; LIMPAR A TELA
;
;
; Ao executar esta rotina, apaga todas as linhas a partir da linha número 4. As
; linhas de 0 a 3 não são apagadas porque fazem parte do cabeçalho do bootloader,
; que é preservado a cada atualização de tela.
;
; =============================================================================


clear_screen:
    
	mov ah, 0x06                  ; Define a função 6 da interrupção de vídeo 
	                              ; do BIOS (rolagem de tela).
								  
    mov al, 0x00                  ; Rola toda a tela (valor 0 significa limpar).
	
    mov bh, 0x07                  ; Define o atributo do fundo (cor de texto e cor 
	                              ; de fundo).
								  
    mov cx, 0x0400                ; Define a posição inicial (linha 4, coluna 0).
	
    mov dh, 24                    ; Define a linha final da área a ser limpa.
	
    mov dl, 79                    ; Define a coluna final da área a ser limpa.
	
    int 0x10                      ; Chama a interrupção para executar a limpeza
	                              ; do terminal.

.reset_cursor:

    mov ah, 0x02                  ; Define a função 2 da interrupção de vídeo
	                              ; do BIOS (mover cursor).
								  
    mov bh, 0x00                  ; Seleciona a página de vídeo (padrão, página
	                              ; 0).
								  
    mov dh, 0x04                  ; Define a linha do cursor (linha 4).
	
    mov dl, 0x00                  ; Define a coluna do cursor (coluna 0).
	
    int 0x10                      ; Chama a interrupção para mover o cursor para
	                              ; a coordenada (4,0).
    
	ret                           ; Retorna o controle para o ponto de chamada.
	
	
	
	
; =============================================================================
;
; ATRASO
;
;
; Ao executar esta rotina, bloqueia o programa pelo tempo de 1 segundo. Funciona
; verificando se o tempo passado desde a entrada na rotina equivale ao número de
; 20 ticks do PIT, configurado para emitir um tick a cada 50 ms (20 x 50 = 1000 ms)
; na rotina start do Estágio 1.
;
; =============================================================================


delay:

	cli                           ; Interrompe as interrupções mascaráveis.
    
	mov ah, 0x00                  ; Define a função 0 da interrupção de relógio 
	                              ; do BIOS (lê o tempo atual do sistema).
								  
	int 0x1A                      ; Chama a interrupção que retorna o tempo atual
	                              ; nos registradores CX e DX.
								  
	mov bx, dx                    ; Copia o valor de DX em BX, para comparação
	                              ; posterior.

.wait_loop:

	mov ah, 0x00                  ; Define a função 0 da interrupção de relógio
	                              ; do BIOS (lê o tempo atual do sistema).
								  
	int 0x1A                      ; Chama a interrupção que retorna o tempo atual
	                              ; nos registradores CX e DX.
								  
	sub dx, bx                    ; Subtrai o valor armazenado no registrador BX
	                              ; do valor atual em DX.
								  
	cmp dx, 20                    ; Calcula se o número de ticks é igual a 20, 
	                              ; que corresponde a 1 segundo.
								  
	jl .wait_loop                 ; Se não atingiu o número de 20 ticks, retorna
	                              ; ao loop novamente.

	sti                           ; Retoma as interrupções mascaráveis.

	ret                           ; Retorna o controle para o ponto de chamada.
	
	
	
	
; =============================================================================
;
; ERRO DE DISCO
;
;
; Ao executar este bloco, exibe uma mensagem de erro informando que não houve o 
; carregamento Estágio 3 do bootloader. Ao teclar ENTER, volta a exibir o menu
; principal.
;
; =============================================================================


disk_error:

	mov dl, [drive_number]        ; Copia o código do drive de boot para DL.
	
	xor ax, ax                    ; Define a função 0 da interrupção de disco 
	                              ; (reset do disco).
								   
	int 0x13                      ; Chama a interrupção de disco do BIOS para
	                              ; reset dos controladores.
	
	mov si, error_str             ; Copia o endereço de memória da string error_str
	                              ; para SI.
								   
    call print_string             ; Imprime a string error_str.
    
	call wait_enter               ; Aguarda teclar ENTER.
	
.show_menu:
	
	jmp show_menu                 ; Salta para o bloco de exibição do menu.




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


header_str:                       ; String cabeçalho do prompt.

	db ' Bem vindo ao programa de instala', 0x87, 0x84, 'o do FAKENIX', 0x00


menu_str:                         ; String opções de menu.

	db '     1. Testar o FAKENIX', 0x0D, 0x0A
	db '     2. Instalar o FAKENIX', 0x0D, 0x0A
	db '     3. Configurar a instala', 0x87, 0x84, 'o', 0x0D, 0x0A
	db '     4. Sair', 0x0D, 0x0A
	db 0x0D, 0x0A, 0x0D, 0x0A
	db ' Digite a sua op', 0x87, 0x84, 'o: ', 0x00


run_str:                          ; String opção de menu 1.

	db ' Carregando o FAKENIX ...', 0x00


install_str:                      ; String opção de menu 2.

	db ' Instalando o FAKENIX ...', 0x00
	
	
option_str:                       ; String opção de menu 3.

	db ' Configurar instala', 0x87, 0x84, 'o (tecle ENTER): ', 0x00
	
	
shutdown_str:                     ; String opção de menu 4.

	db 'Tecle ENTER para sair.', 0x00


error_str:                        ; String erro de carregamento.
	
	db ' Erro ao carregar o FAKENIX. Por favor, tecle ENTER para voltar ao menu.', 0x00
	
	
enter_str:                        ; String tecle ENTER.

	db ' Tecle ENTER para voltar ao menu.', 0x00


linebr_str:                       ; String quebra de linha (simples).

	db 0x0D, 0x0A, 0x00


line_str:                         ; String quebra de linha (dupla).

	db 0x0D, 0x0A, 0x0D, 0x0A, 0x00
	
	
opt:                              ; Opção digitada no menu (1, 2, 3 ou 4).

	db 0x00
	
	
drive_number:                     ; Número do drive de boot.

	db 0x00




; =============================================================================
;
; AJUSTE DO BINÁRIO
;
;
; Completa o restante dos bytes do arquivo, que não são instruções ou dados, com
; zeros, até o byte 1024.
;
; =============================================================================


times 1024 - ($ - $$) db 0x00