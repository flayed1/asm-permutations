BITS 64

SECTION .data
	Error: db "wrong # of arguments",10
	len_Error: equ $-Error
	Error_mismatch: db "mismatch",10
	len_Error_m: equ $-Error_mismatch
	Success: db "the file contains a correct permutation"
	len_Success: equ $-Success
	SYS_OPEN: equ 2
	SYS_READ: equ 0
	SYS_CLOSE: equ 3
	O_RDONLY: equ 0

	buffer_size: equ 4096
	buffer: times buffer_size db 0
	
	read_size: dq 0

	preprocessing_size: equ 256
	preprocessing_buffer: times preprocessing_size db 0

	p: equ 32
	T: times p dq 0

	pe_size: dq 0

	filename: times 256 db 0
	filename_len: dq 0

	file_desc: dq 0

SECTION .text

%macro process_char 1
	cmp rbp, rsi
	je back_to_read
	movzx %1, bl
	or %1,%1
	jz %%if_zero
	%%else: ;read a number
	cmp %1, 64
	jb %%comp
	cmp %1, 128
	jb %%comp_1
	cmp %1, 192
	jb %%comp_2
	%%comp_3:
		sub %1, 192
		bts r11, %1
		jc exit_error_mismatch
		jmp %%end_comp
	%%comp:
		bts r8, %1
		jc exit_error
		jmp %%end_comp
	%%comp_1:
		sub %1, 64
		bts r9, %1
		jc exit_error
		jmp %%end_comp
	%%comp_2:
		sub %1, 128
		bts r10, %1
		jc exit_error
	%%end_comp:
	%%end_else:

	jmp %%endif

	%%if_zero: ;read a zero
		bts r8, 0
		jc exit_error_mismatch
		xor r8, r12 ;check 1st 64 bits
		jnz exit_error_mismatch
		xor r9, r13 ;check 2nd 64 bits
		jnz exit_error_mismatch
		xor r10, r14 ;check 3rd 64 bits
		jnz exit_error_mismatch
		xor r11, r15 ;check 4th 64 bits
		jnz exit_error_mismatch
	%%endif:
	inc rbp
%endmacro

%macro process_register 0
process_char rdi
	mov bl, bh
process_char rdi
	shr rbx, 16
process_char rdi
	mov bl, bh
process_char rdi
	shr rbx, 16
process_char rdi
	mov bl, bh
process_char rdi
	shr rbx, 16
process_char rdi
	mov bl, bh
process_char rdi
%endmacro

global _start

_start:

	xor r10, r10
	xor r8, r8
	xor r9, r9
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	pop rax
	cmp rax, 2
	jne exit_error_b4_opening
	

	;correct #of arguments
	pop rax ;this is just the path to the binary
	pop rax ;now this is actually the name
	mov rsi, rax ;we move the name to rsi where it's needed to be printed
	mov r8, rax ;from now on, R8 stores our string
	mov [filename], r8; let's try this

	;now let's actually open a file
	mov rax, SYS_OPEN
	mov rdi, [filename]
	mov rdx, O_RDONLY
	xor rsi, rsi
	syscall

	cmp rax, -1
	JE exit_error_b4_opening

	mov [file_desc], rax; file descriptor

;preprocessing
	mov rax, SYS_READ ;syscall read
	mov rdi, [file_desc] ;load file descriptor
	mov rsi, preprocessing_buffer ;buffer 
	mov rdx, preprocessing_size ;chars to be read
	syscall

	mov rsi, rax
	xor rbp, rbp
	p_loop:
	movzx rdi, byte[preprocessing_buffer + rbp]
	cmp rdi, 0
	je end_p_loop
	mov rax, rdi
	shr rax, 6
	mov rdx, 063
	and rdx, rdi
	movzx rcx, dl   ;rdx stores the remainder, <=63, fits in 8 bit DL register
	cmp rax, 0
	je comp_p
	cmp rax, 1
	je comp_1_p
	cmp rax, 2
	je comp_2_p
	comp_3_p:
		cmp rax, 3
		jne end_comp_p;
		;R15
		bts r15, rcx
		jc exit_error
		jmp end_comp_p
	comp_1_p:
		cmp rax, 1
		jne comp_2_p
		;R13
		bts r13, rcx
		jc exit_error
		jmp end_comp_p
	comp_2_p:
		cmp rax, 2
		jne comp_3_p
		;R14
		bts r14, rcx
		jc exit_error
		jmp end_comp_p
	comp_p:
		jne comp_1_p
		;R12
		bts r12, rcx
		jc exit_error
	end_comp_p:
	inc rbp
	cmp rbp, rsi
	je exit_error
	jmp p_loop
	end_p_loop:
	inc rbp
	mov [pe_size], rbp
	bts r12, 0


	mov rax, SYS_CLOSE
	mov rdi, [file_desc] ;load file descriptor
	sys-call

;/preprocessing
	mov rbp, [pe_size]
	xor rdx, rdx
	mov rax, buffer_size
	div rbp
	;rax holds size/m_size
	mul rbp
	mov [read_size], rax


	mov rax, SYS_OPEN
	mov rdi, [filename]
	mov rdx, O_RDONLY
	xor rsi, rsi
	sys-call

	cmp rax, -1
	je exit_error_b4_opening

	mov [file_desc], rax; file descriptor

	mov rax, SYS_READ ;syscall read
	mov rdi, [file_desc] ;load file descriptor
	mov rsi, buffer ;buffer 
	mov rdx, [read_size] ;chars to be read

	while_read:
		;first read must be ready
		syscall
		cmp rax, [read_size]
		jg exit_error
		xor r8, r8
		xor r9, r9
		xor r10, r10
		xor r11, r11
		mov rsi, rax;
		cmp rax, 0
		je while_read_exit

		xor rbp, rbp
		xor rdi, rdi
		main_loop:
			mov rbx, [buffer + rbp]
			process_register
			cmp rbp, rsi
			jb main_loop

		back_to_read:
		;cmp rsi, [read_size] ;check if #of bytes read = #of bytes to read
		;jne while_read_exit ;if not, then EOF occurred
		mov rax, SYS_READ ;syscall read ;prepare next read
		mov rdi, [file_desc] ;load file descriptor
		mov rsi, buffer ;buffer 
		mov rdx, [read_size] ;chars to be read
		jmp while_read;

	while_read_exit:
	bts R8, 0
	jc exit_error
	jmp exit_success
	
exit_success:
	mov rax, SYS_CLOSE
	mov rdi, [file_desc] ;load file descriptor
	syscall

	mov rax, 1
	mov rdi, 1
	mov rsi, Success
	mov rdx, len_Success
	syscall
	mov rax, 60
	mov rdi, 0
	syscall
	

exit_error:
	mov rax, SYS_CLOSE
	mov rdi, [file_desc] ;load file descriptor
	syscall
	mov rax, 60
	mov rdi, 1
	syscall

exit_debug:
	mov rax, SYS_CLOSE
	mov rdi, [file_desc] ;load file descriptor
	syscall
	mov rax, 60
	mov rdi, r8
	syscall

exit_error_mismatch:
	mov rax, SYS_CLOSE
	mov rdi, [file_desc] ;load file descriptor
	syscall
	mov rax, 1
	mov rdi, 1
	mov rsi, Error_mismatch
	mov rdx, len_Error_m
	syscall
	mov rax, 60
	mov rdi, 1
	syscall

exit_error_b4_opening:
	mov rax, 1
	mov rdi, 1
	mov rsi, Error
	mov rdx, len_Error
	syscall
	mov rax, 60
	mov rdi, 1
	syscall
