# boot.S bootloader of ZBZZ.OS
# Preston Provins, Grayson Bruner, and Charles Rizzo
# 1/18/2020
.option norvc
# .section .data

.section .data 

.section .text.start
.global _start
_start:
	# Tell any Hardware threads not helping bootstrap
	# to kindly wait.
	csrr  	t0, mhartid
	bnez  	t0, infloop #send nonzero hartid's to infloop?

	#Load the global pointer
	.option norelax
	la		gp,__global_pointer$
	# SATP should be zero, but let's make sure
	csrw  satp, zero
	la 		t0, _bss
	la 		t1, _ebss
	bgeu	t0, t1, contpoint

clearbss:	#Clear out BSS
#	bge		t0,t1,park
	sd		zero,(t0)
	addi	t0,t0,8
	blt     t0,t1,clearbss
contpoint:	
	la		sp, _sp0 #Load Stack Pointer
	la		a0, kinit
	#li		t0, 0x1800
	#csrw	mstatus,t0	#Setting privilege level to 3 (machine)
	# Setting privilege to level 3 (machine) and enabling interrupts
	li		t0, 0x1800
	csrw 	mstatus, t0
	csrw	mepc, a0
	# la t2, m_trap_vector 
	# csrw mtvec, t2 
	# li t3, (1 << 3) | (1 << 7) | (1 << 11) 
	# csrw mie, t3 
	la 	a0, _heap_start 
	la 	a1, _heap_size
	call kheap
	
	la		ra, post_init
	mret
# Go here after kinit to enable interrupts and go to kmain
post_init:
	li 		t0, 0x09a0
	csrw 	mstatus, t0 
	la  	t2, m_trap_vector 
	csrw	mtvec, t2 

	la 		t1, kmain 
	csrw 	mepc, t1 
	# li 		t3, 0x888
	li 		t3, 0xaaa
	csrw 	mie, t3
	la 		ra, infloop 
	mret


infloop:
  wfi
  j infloop
mret

