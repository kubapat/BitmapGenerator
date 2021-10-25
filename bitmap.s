.data
	#toEncode:       .asciz "The answer for exam question 42 is not F."
	toEncode:	.asciz "The quick brown fox jumps over the lazy dog"
	lead:	        .asciz "CCCCCCCCSSSSEE1111444400000000"
	word:	        .skip  300
	rleWord:        .skip  300
	barcodeLine:    .asciz "WWWWWWWWBBBBBBBBWWWWBBBBWWBBBWWR"
	barcode:        .skip 3100
	barcodeDecrypt: .skip 3100
	menuStr:        .asciz "Choose what you want to do:\n1 - Encrypt message\n2 - Decrypt message\n"
	inputFormatStr: .asciz "%ld"
	formatStr:      .asciz "%c"
	filename:       .asciz "andyzaidmanismyhope.bmp"
	header:         .byte 0x42,0x4D,0x36,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x28,0x00,0x00,0x00,0x20,0x00,0x00,0x00,0x20,0x00,0x00,0x00,0x01,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00

	#Used for decryption
	barRead: .skip 3150
	rleRead: .skip 300
	decoded: .skip 300
.text

.globl main

main:
	push %rbp			#Prologue
	mov %rsp, %rbp

	mov $0, %rax
	mov $menuStr, %rdi
	call printf			#Print menu dialogue

	subq $16, %rsp
	leaq -16(%rbp), %rsi
	movq $inputFormatStr, %rdi
	movq $0, %rax
	call scanf			#Scanf action choice

	cmp $1, (%rsp)	#Encrypt
		jne decryptCheck	#If not 1 then check whether it's decryption

		mov $toEncode, %rdi
		call addLeadTrail		#Call subroutine adding lead and trail

		mov $word, %rdi			#Call subroutine doing run length encoding-8
		call rle

		call barcodeRoutine		#Call subroutine generating k for xor'ing (bitmap array)
		call encrypt			#Call subroutine doing xor
		call writeToFile		#Call subroutine writing to file
		jmp end

	decryptCheck:
	cmp $2, (%rsp)	#Decrypt
		jne end				#If neither of those two

		call readFromFile		#Call subroutine reading from file
		call barcodeRead		#Call subroutine decoding barcode to rle

		call decodeRle			#Call soubroutine decoding rle
		call removeLeadAndTrail		#Call subroutine removing lead and trail + outputting the message
	end:

	mov %rbp, %rsp			#Epilogue
	pop %rbp

	mov $0, %rdi			#Return code 0
	call exit


addLeadTrail:
	push %rbp			#Subroutine prologue
	mov %rsp, %rbp

	mov $lead, %rsi			#Move lead address to %rsi
	mov $word, %rdx			#Move word address to %rdx 
	mov $0, %r8			#Set counter of lead
	mov $0, %r9			#Set counter of whole word

	addLead:
		mov (%rsi,%r8), %al	#Copy %r8-th character of lead into 8-bit rax
		cmpb $0, %al		#Check whether this isn't the last char
			je exitAddLead	#if last terminate the loop
		mov %al, (%rdx,%r9)	#Copy %r8-th character of lead into %r9-th position word
		inc %r8			#Increase lead counter
		inc %r9			#Increase word counter
		jmp addLead		#Continue loop

	exitAddLead:

	mov $0, %r8			#Set message counter to 0
	addMessage:
		mov (%rdi,%r8), %al	#Copy %r8-th character of message into 8-bit rax
		cmpb $0, %al		#Check whether this isn't the last char
			je exitAddMessage

		mov %al, (%rdx, %r9)	#Copy %r8-th character of message into %r9-th position word
		inc %r8			#Increase message counter
		inc %r9			#Increase word counter
		jmp addMessage		#Continue loop

	exitAddMessage:

	mov $0, %r8			#Set message counter to 0
	addTrail:
		mov (%rsi,%r8), %al	#Copy %r8-th character of trail into 8-bit rax
		cmpb $0, %al		#Check whether this isn't the last char
			je exitAddTrail

		mov %al, (%rdx, %r9)	#Copy %r8-th character of trail into %r9-th position word
		inc %r8			#Increase message counter
		inc %r9			#Increase word counter
		jmp addTrail		#Continue loop

	exitAddTrail:

	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine



rle:
	push %rbp			#Subroutine prologue
	mov %rsp, %rbp

	mov $rleWord, %rsi		#Copy address of empty rleWorld to %rsi
	mov $0, %r8			#Set word counter to 0
	mov $0, %r9			#Set rleWord counter to 0


	mov (%rdi, %r8), %al		#Current character
	mov $0, %rdx			#Count of current character

	countRle:
		cmpb %al, (%rdi,%r8)	#Check whether current char is equal to current character
			jne otherChar

					#If they're equal
		inc %r8			#Increment word counter
		inc %rdx		#Increment the count of current character
		jmp countRle

		otherChar:
		#add $48, %rdx
		mov %dl, (%rsi, %r9)	#Append the count of current character into rleString
		inc %r9			#Increment rleWord counter

		mov %al, (%rsi, %r9)	#Append the current character into rleString
		inc %r9			#Increment rleWorld counter

		mov (%rdi,%r8), %al	#Move current char into current character
		inc %r8			#Increment word counter

		mov $1, %rdx		#Set count of current character to 1
		cmpb $0, %al		#Check if that's not the end of string
			je exitLoop

		jmp countRle


	exitLoop:

	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine


barcodeRoutine:
	push %rbp
	mov %rsp, %rbp			#Subroutine prologue

	mov $0, %r8			#Set counter of barcodeline to 0
	mov $0, %r9			#Set counter of barcode to 0
	mov $0, %rcx			#Set number of chars in general to 0

	mov $barcodeLine, %rdi		#Copy barcodeLine address into %rdi
	mov $barcode, %rsi		#Copy barcode address into %rsi
	loopLine:
		mov $0, %r8

		withinLine:
		cmpb $0x42, (%rdi, %r8)	#If color is black
			je blackColor

		cmpb $0x57, (%rdi, %r8) #If color is white
			je whiteColor

		cmpb $0x52, (%rdi, %r8) #If color is red
			je redColor

		jmp anotherChar

		blackColor:
		#Blue
		movb $0, (%rsi, %r9)	#Write 0 to B
		inc %r9

		#Green
		movb $0, (%rsi, %r9)	#Write 0 to G
		inc %r9

		#Red
		movb $0, (%rsi, %r9)	#Write 0 to R
		inc %r9

		jmp anotherChar		#Another character

		whiteColor:
		#Blue
		movb $0xFF, (%rsi, %r9)	#Write FF to B
		inc %r9

		#Green
		movb $0xFF, (%rsi, %r9)	#Write FF to G
		inc %r9

		#Red
		movb $0xFF, (%rsi, %r9)	#Write FF to R
		inc %r9

		jmp anotherChar

		redColor:
		#Bluei
		movb $0, (%rsi, %r9)	#Write 0 to B
		inc %r9

		#Green
		movb $0, (%rsi, %r9)    #Write 0 to G
		inc %r9

		#Red
		movb $0xFF, (%rsi, %r9)	#Write FF to R
		inc %r9


		anotherChar:
                inc %r8			#Increment the line counter
                inc %rcx		#Increment the general counter

                cmp $1024, %rcx		#If all chars have been processed 32x32
                        je endLoop

                cmp $32, %r8		#If all chars within line have been processed
                        je loopLine

                jmp withinLine		#jump to another chars within the line

	endLoop:

	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine


encrypt:
	push %rbp
	mov %rsp, %rbp			#Subroutine prologue

	mov $1, %rcx
	mov $0, %r8			#Set counter of RLE message and barcode to 0

	mov $rleWord, %rsi		#Copy address of RLE to %rsi
	mov $barcode, %rdi		#Copy address of Barcode colors to %rdi

	loopEncrypt:
		cmp $0, %rcx		#If we are over the array
			je endEncryptLoop

		movb (%rsi, %r8), %cl	#Copy rle[%r8] to %rcx
		xor (%rdi,%r8), %cl	#xor (barcode[%r8], %rcx)
		movb %cl, (%rdi, %r8)	#Set value of barcode to %rcx as well
		inc %r8			#i++
		jmp loopEncrypt		#Jump to another

	endEncryptLoop:

	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine


writeToFile:
	push %rbp
	mov %rsp, %rbp			#Subroutine prologue


	mov $85, %rax			#sys_open
	mov $filename, %rdi		#filename
	mov $64, %rsi			#O_CREAT sys_open flag
	mov $420, %rdx			#File permissions
	syscall				#Do the system call

	mov %rax, %r8			#Pointer to filename

	mov $1, %rax			#sys_write
	mov %r8, %rdi			#Pointer to filename
	mov $header, %rsi		#BMP headlines
	mov $54, %rdx			#Count of headlines
	syscall				#Do the system call

	mov $1, %rax			#sys_write
	mov %r8, %rdi			#Pointer to filename
	mov $barcode, %rsi		#Barcode encoded array
	mov $3072, %rdx			#Array size 32x32x3
	syscall				#Do the system call

	mov $3, %rax			#sys_close
	mov %r8, %rdi			#Pointer to filename
	syscall				#Do the system call

	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine




readFromFile:
	push %rbp
	mov %rsp, %rbp			#Subroutine prologue

	mov $2, %rax			#sys_open
	mov $filename, %rdi		#filename
	mov $2, %rsi			#O_RDWR
	mov $402, %rdx			#Permissions
	syscall				#Do the system call

	mov %rax, %r8			#Copy file pointer 

	mov $0, %rax			#sys_read
	mov %r8, %rdi			#filepointer
	mov $barRead, %rsi		#array to read
	mov $3126, %rdx			#size 3126=3072+54
	syscall				#Do the system call

	mov $3, %rax			#sys_close
	mov %r8, %rdi			#filepointer
	syscall				#Do the system call


	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine


barcodeRead:
        push %rbp
        mov %rsp, %rbp                  #Subroutine prologue

        mov $0, %r8                     #Set counter of barcodeline to 0
        mov $54, %r9                    #Set counter of barcode to 0
        mov $0, %rcx                    #Set number of chars in general to 0
	mov $0, %r10			#Set number of rleRead to 0

	mov $rleRead, %rdx
        mov $barcodeLine, %rdi          #Copy barcodeLine address into %rdi
        mov $barRead, %rsi              #Copy barcode address into %rsi

        loopLineRead:
                mov $0, %r8

                withinLineRead:
                cmpb $0x42, (%rdi, %r8) #If color is black
                        je blackColorRead

                cmpb $0x57, (%rdi, %r8) #If color is white
                        je whiteColorRead

                cmpb $0x52, (%rdi, %r8) #If color is red
                        je redColorRead

                jmp anotherCharRead	#Other char

                blackColorRead:		#If this is black
                #Blue
		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		xor $0, %al		#Xor with 0
		movb %al, (%rdx, %r10)	#Move it to rle array
                inc %r9
		inc %r10		#Increase the pointers

                #Green
		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		xor $0, %al		#Xor with 0
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers

                #Red
		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		xor $0, %al		#Xor with 0
		movb %al, (%rdx, %r10)	#Move it to rle array
                inc %r9			#Increase the pointers
		inc %r10

                jmp anotherCharRead     #Another character

                whiteColorRead:		#If this is white
                #Blue
		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		cmp $0xFF, %al		#Check whether it has been xored
			je endLoopRead

		xor $0xFF, %al		#Xor with FF
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers

                #Green
		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		cmp $0xFF, %al		#Check whether it has been xored
			je endLoopRead

		xor $0xFF, %al		#Xor with FF
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers



		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		cmp $0xFF, %al		#Check whether it has been xored
			je endLoopRead

		xor $0xFF, %al		#Xot with FF
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers

                jmp anotherCharRead

                redColorRead:		#If this is red 
                #Blue
		movzb (%rsi, %r9), %rax #Copy current byte to %rax
		xor $0, %al		#Xor with 0
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers

		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		xor $0, %al		#Xor with 0
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers

		movzb (%rsi, %r9), %rax	#Copy current byte to %rax
		xor $0xFF, %al		#Xor with FF
		movb %al, (%rdx, %r10)	#Move it to rle array
		inc %r9
		inc %r10		#Increase the pointers
		

                anotherCharRead:
                inc %r8                 #Increment the line counter
                inc %rcx                #Increment the general counter

                cmp $1024, %rcx         #If all chars have been processed 32x32
                        je endLoopRead

                cmp $32, %r8            #If all chars within line have been processed
                        je loopLineRead

                jmp withinLineRead      #jump to another chars within the line

        endLoopRead:

        mov %rbp, %rsp                  #Subroutine epilogue
        pop %rbp
        ret                             #return subroutine


decodeRle:
	push %rbp
	mov %rsp, %rbp			#Subroutine prologue

	mov $rleRead, %rdi		#Copy address of the rle encoded string into %rdi
	mov $decoded, %rsi		#Copy address of the rle decoded string into %rsi

	mov $0, %r8			#Counter within rle
	mov $0, %r9			#Counter within string


	decodeLoop:

	movb (%rdi, %r8), %cl		#Number of repetitions
	inc %r8

	movb (%rdi, %r8), %dl		#Character to output
	inc %r8

	outputLoop:
		movb %dl, (%rsi, %r9)	#Move character into decoded array
		inc %r9			#Increase pointer
		dec %cl			#Decrease no of repetitions

		cmpb $0, %cl		#If no of repetitions is 0 then end loop
			jne outputLoop

		
	cmp $0, (%rdi, %r8)		#If this is end of string end loop
		je endDecode

	jmp decodeLoop			#continue loop

	endDecode:
	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine


removeLeadAndTrail:
	push %rbp
	mov %rsp, %rbp			#Subroutine prologue


	push %r12
	push %r13
	push %r14			#Push callee-saved regs onto stack in order to use them

	mov $0, %r12			#Init counter as 0 in %r12
	mov $decoded, %r13		#Copy decoded array address into %r13

	countLoop:			#Count the length of string
		inc %r12		#Increase the counter
		cmp $0, (%r13, %r12)
			jne countLoop

	mov $30, %r14			#Set index of 1st character to 30
	subq $30, %r12			#Set index of the last character to strlen-30

	printLoop:
		mov $0, %rax
		mov $formatStr, %rdi
		mov (%r13, %r14), %rsi
		call printf		#Print the character

		inc %r14		#Increment the counter
		cmp %r14, %r12
			jne printLoop


	pop %r14			#Pop pushed regs
	pop %r13
	pop %r12
		
			


	mov %rbp, %rsp			#Subroutine epilogue
	pop %rbp
	ret				#return subroutine
