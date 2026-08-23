; =============================================================================
;
; IMPRESSÃO DE STRING NA POSIÇÃO DO CURSOR
;
;
; Ao executar esta função, imprime uma string no terminal, na posição atual do
; cursor, caractere por caractere, até encontrar o byte nulo 0x00, que denota o 
; final da string.
;
; =============================================================================
	
	
print_string:

    mov ah, 0x0E                  ; Define a função 0x0E da interrupção de vídeo 
	                              ; do BIOS (exibir caractere).
								  
	mov bl, 0x07                  ; Define as cores de fonte e fundo (fundo preto, 
	                              ; texto branco).

.next_char:

    lodsb                         ; Carrega o próximo byte da string apontada por
	                              ; SI para AL, e inclementa SI.
								  
    or al, al                     ; Faz uma operação OR de AL com ele mesmo. Se
	                              ; AL for 0, o resultado será 0.
								  
    jz .done                      ; Se AL for 0 (alcançou o fim da string), salta
	                              ; para .done.
								  
    int 0x10                      ; Chama a interrupção para imprimir o caractere
	                              ; armazenado em AL no terminal.
								  
    jmp .next_char                ; Retorna ao início do laço .next_char, para 
	                              ; processar o próximo caractere.

.done:

    ret                           ; Retorna o controle para o ponto de chamada.
	
	
	

; =============================================================================
;
; DESLIGAR O COMPUTADOR VIA APM
;
;
; Como estou usando funções de APM (Advanced Power Management) para desligar o
; computador em Modo Real, em hardware real não iria funcionar nas máquinas pós 
; anos 1990/2000. Porém na máquina virtual QEMU, utilizada para os testes, ela 
; ainda funciona.
;
; =============================================================================


shutdown:

	cli                           ; Interrompe as interrupções mascaráveis para
	                              ; configurar o programa.

                                  ; -------------------------------------------
                                  ; 1. Verifica se APM está presente
								  ; -------------------------------------------

    mov ax, 0x5300                ; Define a função 0x5300, que é usada para 
	                              ; detectar a presença do APM.
								  
    xor bx, bx                    ; Zera o valor de BX.
	
    int 0x15                      ; Chama a interrupção 0x15, para testar se a 
	                              ; APM está presente.
								  
    jc .apm_not_present           ; Se a APM não está presente no sistema, salta
	                              ; para .apm_not_present.

                                  ; -------------------------------------------
                                  ; 2. Conecta-se à interface APM
								  ; -------------------------------------------

    mov ax, 0x5301                ; Define a função 0x5301, que é usada para 
	                              ; conectar-se ao APM.
								  
    xor bx, bx                    ; Zera o valor de BX.
	
    int 0x15                      ; Chama a interrupção 0x15, para realizar a 
	                              ; conexão ao APM.
								  
    jc .apm_connection_failed     ; Se não se conectou com a APM, salta para 
	                              ; .apm_connection_failed.

                                  ; -------------------------------------------
                                  ; 3. Desliga o computador
								  ; -------------------------------------------

    mov ax, 0x5307                ; Define a função APM_SET_POWER_STATE, que altera
                                  ; o estado de energia do dispositivo.
								  
    mov bx, 0x0001                ; Define o dispositivo-alvo. O valor 0x0001 
	                              ; significa todos os dispositivos.
								  
    mov cx, 0x0003                ; Define o estado de energia do dispositivo. O
	                              ; valor 0x0003 indica Power Off.
								  
    int 0x15                      ; Chama a interrupção 0x15, para executar o comando
	                              ; de desligar o computador.

    jmp .failed_shutdown          ; Se o desligamento não foi bem-sucedido, salta
	                              ; para .failed_shutdown.

.apm_not_present:

    mov si, apm_not_found_str     ; Copia o endereço de memória da string apm_not_found_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string apm_not_found_str.
	
    jmp .hang                     ; Salta para .hang.

.apm_connection_failed:

    mov si, apm_conn_fail_str     ; Copia o endereço de memória da string apm_conn_fail_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string apm_conn_fail_str.
	
    jmp .hang                     ; Salta para .hang.

.failed_shutdown:

    mov si, shutdown_fail_str     ; Copia o endereço de memória da string shutdown_fail_str
	                              ; para SI.
								  
    call print_string             ; Imprime a string shutdown_fail_str.
	
    jmp .hang                     ; Salta para .hang.

.hang:
    
	                              ; -------------------------------------------
	                              ; Loop infinito para evitar reinicialização ou 
								  ; comportamento indesejado.
								  ; -------------------------------------------
    
	hlt                           ; Entra em modo de baixa energia até a próxima 
	                              ; interrupção ("congela")
    jmp .hang
	
	
	
	
; =============================================================================
;
; AGUARDAR A TECLA ENTER SER PRESSIONADA
;
;
; Ao executar esta rotina, fica lendo o teclado até se digitar ENTER.
;
; =============================================================================


wait_enter:
    
	mov ah, 0x00                  ; Define a função 0 da interrupção de teclado 
	                              ; (leitura de tecla).
								  
    int 0x16                      ; Chama a interrupção para ler a tecla pressionada.
	
    cmp al, 0x0D                  ; Compara o valor em AL, que armazena o valor
	                              ; da tecla, com 0x0D (ENTER).
								  
    jne wait_enter                ; Se a tecla pressionada não for ENTER, volta
	                              ; a ler o teclado novamente.
	
	ret                           ; Retorna o controle para o ponto de chamada.
	
	
	

; =============================================================================
; SEÇÃO DE DADOS DO PROGRAMA
; =============================================================================


apm_not_found_str:                ; String de erro na localização da APM.

	db 'APM BIOS not found!', 0xD, 0xA, 0x00


apm_conn_fail_str:                ; String de erro na conexão com a APM.
	
	db 'APM connection failed!', 0xD, 0xA, 0x00


shutdown_fail_str:                ; String de erro no shutdown via APM.

	db 'Shutdown failed via APM!', 0xD, 0xA, 0x00