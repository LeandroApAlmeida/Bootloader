org 0x7C00              
bits 16                 




jmp short start
nop	




start:

	xor ax, ax          
	mov ds, ax          
	mov es, ax          
	mov ax, 0x0900      
	mov ss, ax          
	mov sp, 0xFFFF      
	
	mov ax, sp          
	mov dx, ax          

	call print_hex      
	
	mov ah, 0x0E        

	mov al, '-'         
	int 0x10            
	
	mov al, '>'         
	int 0x10

	mov si, help_str
	call print_string
	
	call skip_a_line
	
	mov ax, word 0xFFFF
	
.wait_key:

    mov ah, 0x00  
    int 0x16      

	cmp al, 0x0D
	je .push_ax    

	cmp al, 0x08 
    je .pop_ax

	jmp .wait_key 

.push_ax:

	push ax
	
	mov si, push_str
	call print_string
	
	jmp .print

.pop_ax:

	pop ax
	
	mov si, pop_str
	call print_string
	
.print:

	mov ax, SS          
	mov dx, ax         

	call print_hex      
 
	mov ah, 0x0E        
	mov al, ':'         
	int 0x10            

	mov ax, sp          
	mov dx, ax          

	call print_hex      

	call skip_a_line

	jmp .wait_key     




print_hex:
	
	mov si, hex_buffer  
	mov cx, 4           

.hex_loop:
	
	rol dx, 4           
	mov al, dl
	and al, 0x0F        
	add al, '0'         

	cmp al, '9'         
	jbe .store_char
	add al, 7           

.store_char:
	
	mov [si], al        
	inc si
	loop .hex_loop

	mov si, hex_buffer
	mov ah, 0x0E        

.print_loop:

	mov al, [si]
	int 0x10            
	inc si
	cmp al, 0
	jnz .print_loop
	ret




skip_a_line:

	mov si, line_str    
    call print_string   

	ret                 


	
	
print_string:

    mov ah, 0x0E        
	mov bl, 0x07        

.next_char:

    lodsb               
    or al, al           
    jz .done            
    int 0x10            
    jmp .next_char      

.done:

    ret              




hex_buffer: db '0000', 0  

line_str: db 0x0D, 0x0A, 0
	
help_str: db ' Tecle ENTER para empilhar. Tecle BACKSPACE para desempilhar',0
	
push_str: db '[empilhou...]: ', 0
	
pop_str: db '[desempilhou]: ', 0




times 510-($-$$) db 0
dw 0xAA55