; ═════════════════════════════════════════════════════════════════════════════
;                        SHARED - MULT-STAGE BOOTLOADER
; ═════════════════════════════════════════════════════════════════════════════
;
; Este arquivo de código-fonte contém rotinas que são utilizadas pelos três
; estágios do bootloader, portanto, ele evita a duplicação desnecessária de
; código. Isso é possível pois os três programas são Modo Real (16-bit), o que
; possibilita o compartilhamento de código entre ambos.
;
; A importação das rotinas compartilhadas para o código-fonte de um estágio se 
; dá com o uso da diretiva %include, desta forma:
;
;
;     %include "shared.asm"
;
;
; A diretiva %include do pré-processador NASM funciona como um "copiar e colar" 
; no código. Ele pega o código-fonte deste módulo e insere no ponto exato onde
; ela está sendo declarada no código-fonte do estágio.
;
; ═════════════════════════════════════════════════════════════════════════════




; =============================================================================
;
; IMPRIMIR STRING
;
;
; Ao executar esta função imprime uma string no terminal, na posição atual do
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
; Em Modo Real não é possível ter acesso à ACPI para desligar o computador, por
; limitações no acesso à memória do computador. Dessa forma, uso funções de APM 
; (Advanced Power Management) para tentar o desligamento.
;
; Em hardware real estas funções não irão funcionar nas máquinas pós anos 
; 1990/2000. Ainda assim utilizo, pois a máquina virtual Qemu onde os testes são
; realizados implementa funções de APM, e, portanto, permite sair do terminal
; teclando ESC quando está no jogo. Quando testado no computador real, estas
; funções falham, como é o esperado.
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
    
	hlt                           ; Entra em modo de baixa energia.
	                              
    jmp .hang
	
	
	
	
; =============================================================================
;
; AGUARDAR ENTER
;
;
; Ao executar esta rotina, fica lendo o teclado até se pressionar a tecla ENTER.
;
; =============================================================================


wait_enter:
    
	mov ah, 0x00                  ; Define a função 0 da interrupção de teclado 
	                              ; do BIOS (leitura de tecla).
								  
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