
; Este código em Assembly implementa o estágio 2 do bootloader. O estágio 2 implementa o menu do sistema
; operacional, com as opções de testar, instalar ou configurar o boot.


[BITS 16]               ; O programa do estágio 2 roda em modo real de 16 bits.
[ORG 0x7E00]            ; O programa será executado no endereço 0x07E00.




; Salta para o ponto de entrada do programa.

jmp start




; Ao executar esta função, imprime o menu do bootloader. Ao imprimir o menu, verifica se o valor em
; opt é zero. Esta variável tem salvo nela a tecla que foi pressionada.
; 
; Se opt é zero (0x00), significa que não foi pressionada qualquer tecla de menu. Neste caso, imprime
; apenas as opções do menu. Se opt é diferente de zero, significa que foi pressionada a tecla 1,  2
; ou 3, correspondendo a uma das opções do menu. Neste caso, imprime o número da tecla pressionada que
; está em opt na frente do texto "Escolha uma opção: ".

print_menu:
    
	mov si, menu_str    ; Copia o endereço de memória da string menu_str para SI.
    call print_string   ; Imprime a string menu_str.
	cmp byte [opt], 0x00 ; Compara o valor em opt com 0x00.
	je .done            ; Se o valor em opt for 0x00, não há a opção digitada pelo usuário e salta para .done.
	mov ah, 0x0E        ; Define a função 0x0E da interrupção de vídeo (exibir caractere).
    mov al, byte [opt]  ; Copia o caractere salvo em opt para AL.
	int 0x10            ; Chama a interrupção para imprimir o caractere armazenado em AL no terminal.

.done:
	
	ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, salta uma linha no terminal (equivalente a usar "\n\n" em linguagens 
; de alto nível).

skip_a_line:

	mov si, line_str    ; Copia o endereço de memória da string line_str para SI.
    call print_string   ; Imprime a string line_str.

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




; Ao executar esta função, apaga todas as linhas a partir da linha número 5. As linhas de 1 a 4 não
; são apagadas porque fazem parte do cabeçalho do bootloader.

clear_screen:
    
	mov ah, 0x06        ; Define a função 6 da interrupção de vídeo (rolagem de tela).
    mov al, 0           ; Rola toda a tela (valor 0 significa limpar).
    mov bh, 0x07        ; Define o atributo do fundo (cor de texto e cor de fundo).
    mov cx, 0400h       ; Define a posição inicial (linha 5, coluna 0).
    mov dh, 24          ; Define a linha final da área a ser limpa.
    mov dl, 79          ; Define a última coluna da área a ser limpa.
    int 0x10            ; Chama a interrupção para executar a limpeza do terminal.

.reset_cursor:

    mov ah, 0x02        ; Define a função 2 da interrupção de vídeo (mover cursor).
    mov bh, 0x00        ; Seleciona a página de vídeo (padrão, página 0).
    mov dh, 0x04        ; Define a linha do cursor (linha 5).
    mov dl, 0x00        ; Define a coluna do cursor (coluna 0).
    int 0x10            ; Chama a interrupção para mover o cursor para (5,0).
    
	ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, lê o teclado até o usuário digitar ENTER.

wait_enter:
    
	mov ah, 0           ; Define a função 0 da interrupção de teclado (leitura de tecla).
    int 0x16            ; Chama a interrupção para ler a tecla pressionada.
    cmp al, 0x0D        ; Compara o valor em AL, que armazena o valor da tecla, com 0x0D (Enter).
    jne wait_enter      ; Se a tecla pressionada não for Enter, volta a ler o teclado novamente.
	
	ret                 ; Retorna o controle para o ponto de chamada.




; Ao executar esta função, bloqueia o programa pelo tempo de 1 segundo. Funciona verificando se o
; tempo passado desde a entrada na função equivale ao número de 20 ticks do PIT, configurado para
; emitir um tick a cada 50 ms (20 x 50 = 1000 ms).

delay:

	cli                 ; Interrompe as interrupções mascaráveis.
    
	mov ah, 0x00        ; Define a função 0 da interrupção de relógio (lê o tempo atual do sistema).
	int 0x1A            ; Chama a interrupção que retorna o tempo atual nos registradores CX e DX.
	mov bx, dx          ; Copia o valor de DX em BX, para comparação posterior.

.wait_loop:

	mov ah, 0x00        ; Define a função 0 da interrupção de relógio (lê o tempo atual do sistema).
	int 0x1A            ; Chama a interrupção que retorna o tempo atual nos registradores CX e DX.
	sub dx, bx          ; Subtrai o valor armazenado no registrador BX do valor atual em DX.
	cmp dx, 20          ; Calcula se o número de ticks é igual a 20, que corresponde a 1 segundo.	
	jl .wait_loop       ; Se não atingiu o número de 20 ticks, retorna ao loop novamente.

	sti                 ; Retoma as interrupções mascaráveis.

	ret                 ; Retorna o controle para o ponto de chamada.




; Ponto de entrada do programa.
	
start:

	cli                 ; Interrompe as interrupções mascaráveis para configurar o programa.

	; Reinicia a pilha do bootloader, que está localizada no endereço 0x9000:
	
	mov sp, 0xFFFF      ; Move o ponteiro SP (Stack Pointer) para o topo da pilha.
	
	; Limpa a tela completamente.
	
	mov ah, 0x06        ; Define a função 6 da interrupção de vídeo (rolagem de tela).
    mov al, 0           ; Rola toda a tela (valor 0 significa limpar).
    mov bh, 0x07        ; Define o atributo do fundo (cor de texto e cor de fundo).
    mov cx, 0           ; Define a posição inicial (linha 0, coluna 0).
    mov dh, 24          ; Define a linha final da área a ser limpa.
    mov dl, 79          ; Define a última coluna da área a ser limpa.
    int 0x10            ; Chama a interrupção para executar a limpeza do terminal.
	
	mov ah, 0x02        ; Define a função 2 da interrupção de vídeo (mover cursor).
    mov bh, 0x00        ; Seleciona a página de vídeo (padrão, página 0).
    mov dh, 0x00        ; Define a linha do cursor (linha 0).
    mov dl, 0x00        ; Define a coluna do cursor (coluna 0).
    int 0x10            ; Chama a interrupção para mover o cursor para (0,0).
	
	; Imprime o cabeçalho do bootloader.
	
	mov si, header_str  ; Copia o endereço de memória da string header_str para SI.
    call print_string   ; Imprime a string header_str.
	
	mov si, linebr_str  ; Copia o endereço de memória da string linebr_str para SI.
    call print_string   ; Imprime a string linebr_str.

	; Imprime a borda do cabeçalho.

	mov ah, 0x0E        ; Define a função 0x0E da interrupção de vídeo (exibir caractere).

	mov al, ' '         ; Carrega o caractere ' ' em AL.
	int 0x10            ; Chama a interrupção para imprimir o caractere armazenado em AL no terminal.
    
	mov al, '='         ; Carrega o caractere '=' em AL.
    mov cx, 78          ; Define o valor 78 em CX, usado como contador de caracteres.

.border_loop:
    
	int 0x10            ; Chama a interrupção para imprimir o caractere armazenado em AL no terminal.
	loop .border_loop   ; Decrementa o valor de CX e repete o loop (78 vezes), enquanto CX for maior ou igual a 0.
	
	mov si, linebr_str  ; Copia o endereço de memória da string linebr_str para SI.
	call print_string   ; Imprime a string linebr_str.
	
	sti                 ; Retoma as interrupções mascaráveis.




; Ao executar este bloco, exibe o menu do sistema operacional e espera a interação do usuário, 
; que deve digitar o número do item de menu escolhido.

show_menu:

	mov [opt], byte 0x00 ; Copia 0x00 para opt, indicando nenhuma opção de menu selecionada.
	
	call clear_screen   ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu     ; Exibe o menu do sistema operacional.

.wait_key:

    mov ah, 0x00        ; Define a função 0 da interrupção de teclado (leitura de tecla).
    int 0x16            ; Chama a interrupção para ler a tecla pressionada, que é armazenada em AL.

	cmp al, '1'         ; Compara o valor em AL com '1'.        
	je run_os           ; Se o valor em AL for '1', carrega o estágio 3.

	cmp al, '2'         ; Compara o valor em AL com '2'.
    je install_os       ; Se o valor em AL for '2', carrega o estágio 3.

	cmp al, '3'         ; Compara o valor em AL com '3'.
    je show_option      ; Se o valor em AL for '3', exibe o menu de opções do boot.

	jmp .wait_key       ; Se o valor em AL não for '1', '2' ou '3', volta a ler a tecla.




; Ao executar este bloco, simula o carregamento do Sistema Operacional. 

run_os:
	
	mov [opt], al       ; Copia AL, que tem armazenado o valor da tecla pressionada, para opt.
	
	call clear_screen   ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu     ; Imprime o menu, agora obtendo o caractere em opt para a resposta.
	
	call skip_a_line    ; Pula uma linha.
	
	mov si, run_str     ; Copia o endereço de memória da string run_str para SI.
	call print_string   ; Imprime a string run_str.
    
	call load_stage3    ; Carrega o estágio 3.




; Ao executar este bloco, simula a instalação do Sistema Operacional. 

install_os:
	
	mov [opt], al       ; Copia AL, que tem armazenado o valor da tecla pressionada, para opt.
	
	call clear_screen   ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu     ; Imprime o menu, agora obtendo o caractere em opt para a resposta.
	
	call skip_a_line    ; Pula uma linha.
	
	mov si, install_str ; Copia o endereço de memória da string run_str para SI.
	call print_string   ; Imprime a string run_str.
	
	call load_stage3    ; Carrega o estágio 3.

	


; Ao executar este bloco, carrega o terceiro estágio do bootloader, responsável por carregar o
; kernel do sistema operacional na memória. Como não existe um sistema operacional, carrega o
; jogo da cobrinha.
	
load_stage3:
	
	call delay          ; Simula um tempo de processamento para o carregamento do estágio 3.
	call delay          ; ...
	call delay          ; ...
    
	call clear_screen   ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	; Carrega o estágio 3 na memória.
	
	mov ah, 0x02        ; Define a função 2 da interrupção de disco (ler setores do disco).
	mov al, 4           ; Define que 4 setores devem ser carregados para a memória RAM.
	mov ch, 0           ; O cilindro do disco é definido como 0 (padrão).
	mov cl, 4           ; Define o setor do disco aonde inicia a leitura, que é o 4.
	mov dh, 0           ; A cabeça de leitura do disco é 0 (padrão).
	mov dl, 0x80        ; Assume que o tipo do disco é o primeiro HD.
	mov bx, 0x8200      ; Endereço na memória RAM aonde o terceiro estágio será carregado.
	int 0x13            ; Chama a interrupção de disco, para ler os setores e carregar na memória RAM.
	jc disk_error       ; Se a flag de carry (CF) estiver definida como 1, salta para o tratador de erro.
	jmp 0x0000:0x8200   ; Se a leitura do disco foi bem-sucedida, entrega o controle para o estágio 3.		




; Ao executar este bloco, exibe o menu de configurações. Como não existe um sistema operacional, espera
; apenas que se tecle ENTER para voltar ao menu.

show_option:
	
	mov [opt], al       ; Copia o valor de AL, que tem armazenado o valor da tecla pressionada, para opt.
	
	call clear_screen   ; Limpa o terminal, mantendo apenas o cabeçalho.
	
	call print_menu     ; Imprime o menu, agora obtendo o caractere em BL para a resposta.
	
	call skip_a_line    ; Pula uma linha.
    
	mov si, option_str  ; Copia o endereço de memória da string option_str para SI.
    call print_string   ; Imprime a string option_str.

	call wait_enter     ; Aguarda o usuário teclar ENTER.

.show_menu:
	
	jmp show_menu       ; Salta para o bloco de exibição do menu.




; Ao executar este bloco, exibe uma mensagem de erro informando que não houve o carregamento estágio 3 do
; bootloader.

disk_error:

	mov dl, 0x80        ; Código do drive de boot (0x80 é disco rígido).
	xor ax, ax          ; Define a função 0 da interrupção de disco (reset do disco).
	int 0x13            ; Chama a interrupção de disco do BIOS para resetar os controladores.
	
	mov si, error_str   ; Copia o endereço de memória da string error_str para SI.
    call print_string   ; Imprime a string error_str.
	
	call skip_a_line    ; Pula uma linha.
	
	mov si, enter_str   ; Copia o endereço de memória da string enter_str para SI.
    call print_string   ; Imprime a string enter_str.
    
	call wait_enter     ; Aguarda o usuário teclar ENTER.
	
.show_menu:
	
	jmp show_menu       ; Salta para o bloco de exibição do menu.




; Seção de dados do programa:


header_str: db ' Bem vindo ao programa de instala', 0x87, 0x84, 'o do FAKENIX', 0

menu_str:

db '     1. Testar o FAKENIX', 0x0D, 0x0A
db '     2. Instalar o FAKENIX', 0x0D, 0x0A
db '     3. Configurar a instala', 0x87, 0x84, 'o', 0x0D, 0x0A, 0x0D, 0x0A
db ' Digite a sua op', 0x87, 0x84, 'o: ', 0

opt: db 0x00

run_str: db ' Carregando o FAKENIX ...', 0

install_str: db ' Instalando o FAKENIX ...', 0

error_str: db ' Erro ao carregar o FAKENIX. Por favor, tecle ENTER para voltar ao menu.', 0
		      
enter_str: db ' Tecle ENTER para voltar ao menu.', 0

option_str: db ' Configurar instala', 0x87, 0x84, 'o (tecle ENTER): ', 0

linebr_str: db 0x0D, 0x0A, 0

line_str: db 0x0D, 0x0A, 0x0D, 0x0A, 0




; Completa o restante dos bytes do arquivo, que não são instruções ou dados, com zeros, até o byte
; 1024.

times 1024 - ($ - $$) db 0