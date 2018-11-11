BITS 64

SECTION .data

	SYS_OPEN: equ 2
	SYS_READ: equ 0
	SYS_CLOSE: equ 3
	O_RDONLY: equ 0

	buffer_size: equ 4096

	preprocessing_size: equ 256

	set_size: equ 256

SECTION .bss

	pattern: resb set_size
	current: resb set_size

	
	read_size: resq 1

	buffer: resb buffer_size

	pe_size: resq 1

	filename: resq 1

	file_desc: resq 1

SECTION .text

_read:
	mov rax, SYS_READ
	mov rdi, [file_desc]             ; load file descriptor
	mov rsi, buffer                  ; buffer 
	mov rdx, [read_size]             ; chars to be read
	syscall
	ret

_open:
	mov rax, SYS_OPEN
	mov rdi, [filename]
	mov rdx, O_RDONLY
	xor rsi, rsi
	syscall
	ret

_close:
	mov rax, SYS_CLOSE
	mov rdi, [file_desc]            ; load file descriptor
	syscall
	ret

_fill:								; fills 256 elements of db array
									; passed by pointer in RDX
									; with the content of AL
	mov rcx, 0
	_head2:
	mov byte[rdx + rcx], al
	inc rcx
	cmp rcx, set_size
	jbe _head2
	ret


global _start

_start:
	mov rax, 0
	mov rdx, current
	call _fill                      ; initialize temporary permutation
	mov rax, 1
	mov rdx, pattern
	call _fill                      ; initialize pattern
	pop rax                         ; pop #of arguments

	cmp rax, 2
	jne exit_error_b4_opening       ; wrong #of arguments - exit without closing the file
	

	                                ; correct #of arguments
	pop rax                         ; this is just the path to the binary
	pop rax                         ; this is the file's name
	mov [filename], rax             ; save it, we'll need it later

	;let's actually open a file
	call _open

	cmp rax, -1                     ; check if file had opened successfully
	JE exit_error_b4_opening

	mov [file_desc], rax; file descriptor

									; preprocessing
									; we process the first permutation and save it as the pattern for the file
									; we also determine the subset's size
	mov qword[read_size], 256
	call _read
	cmp rax, 0
	jbe exit_error

	xor rbp, rbp
	p_loop:
	movzx rdi, byte[buffer + rbp] ;
	cmp rdi, 0
	je end_p_loop 				    ; the first permutation had ended
	dec byte[pattern+rdi] 		    ; initalized to 1
	jnz exit_error                  ; if not zero then we've seen this number twice without seeing a zero in between
	inc rbp                         ; increase the length
	cmp rbp, rax                    ; we read than 256 byes without seeing a zero - return error
	jae exit_error  
	jmp p_loop                      ; continue if there were no errors
	end_p_loop:
	mov r13, rbp                    ; save the length in R13 - this is the length without 0
	inc rbp                         ; but we'll need the length with 0 in a second

	call _close                     ; close the file so that it resets our pointer to the beginning

;/preprocessing

	xor rdx, rdx
	mov rax, buffer_size
	div rbp                         ; rax holds floor(size/M_size), where M is the subset
	mul rbp                         ; now rax holds the largest M_size*n <= buffer_size
	mov [read_size], rax            ; save it

	                                ; read_size is set so that, assuming the file is correct,
	                                ; the buffer always contains a multiple of perutation's size
	                                ; it was supposed to optimize something but it turned out not to matter that much :/


	call _open                      ; re-open the file
	cmp rax, -1						; check if opened successfully
	je exit_error_b4_opening

	mov [file_desc], rax 			; file descriptor

	call _read

	mov R15, 0
	xor R14, R14
	while_read:
		cmp rax, 0
		je while_read_exit


		xor rbp, rbp
		main_loop:
			mov bl, byte[buffer + rbp]
			inc rbp								; increment the index in buffer
			_process_char:
				movzx r8, bl
				cmp r8, 0
				je _if_zero
				_else:
				cmp byte[current + r8], R15B 	; check if number under current[read_number]=#of current permutation
				jne exit_error 					; if not, then we've seen this number twice without seeing a 0 in between
				cmp byte[pattern + r8], 0		; check if the number was in the pattern
				jne exit_error 					; if not, then this is not a correct permutation
				inc byte[current + r8]			; increase the number of permutations this number was in
				inc R14 						; increase current permutation's size
				jmp _exit_pc					; skip "if zero" part
				_if_zero:
				inc R15 						; increase the number of permutations finished
				xor R14, R13 					; chceck if current permutation's length was same as pattern's
				jnz exit_error 					; if not, exit
												; xor stores result in the first argument, we do not need to zero R14
				_exit_pc:
				_pr_exit:
			cmp rbp, rax 						; check if current index in buffer < read_size
			jb main_loop						; if yes then loop
		back_to_read:
		cmp rax, [read_size] 					; check if #of bytes read = #of bytes to read
		jne while_read_exit 					; if not, then EOF occurred
		;cmp r8, 0 ;check if last char was 0
		call _read								; read next part of the file to the buffer
		jmp while_read;							; continue processing

	while_read_exit:
	cmp r8, 0 									;check if last number read was 0
	jne exit_error 								;if not, then error, else continue to exit_success
	
exit_success:
	call _close 								;close the file
	mov rax, 60
	mov rdi, 0
	syscall

exit_error:
exit_debug:
exit_error_mismatch:
	call _close
exit_error_b4_opening:
	mov rax, 60
	mov rdi, 1
	syscall
