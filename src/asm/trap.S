.option norvc
.altmacro 
.set NUM_GP_REGS, 32
.set NUM_FP_REGS, 32
.set REG_SIZE, 8 
.set MAX_CPUS, 8 

# I would like to thank Dr. Marz and his blog (Did you know he has a blog?) 
# for these neato macros and for how to use them. 
.macro save_gp i, basereg=t6
	sd		x\i, ((\i)*REG_SIZE)(\basereg)
.endm 
.macro load_gp i, basereg=t6
	ld 		x\i, ((\i)*REG_SIZE)(\basereg) 
.endm 
.macro save_fp i, basereg=t6
	fsd		f\i, ((NUM_GP_REGS+(\i))*REG_SIZE)(\basereg)
.endm
.macro load_fp i, basereg=t6
	fld		f\i, ((NUM_GP_REGS+(\i))*REG_SIZE)(\basereg)
.endm

.section .text 
.global m_trap_vector 
.align 4
m_trap_vector: 
	# Put t6 in mscratch to store later. 
	# We need it right now to save the others.
	
	csrrw t6, mscratch, t6 
	# Save the other registers. 
	.set 	i, 1
	.rept 	30
			save_gp %i 
			.set i, i+1 
	.endr 
	# Now save t6 
	mv 		t5, t6 
	csrr 	t6, mscratch 
	save_gp 31, t5 

	# Put trap frame into mscratch
	csrw 	mscratch, t5

	# Prepare to go into Zig to handle traps. 
	csrr 	a0, mepc 
	csrr 	a1, mtval 
	csrr 	a2, mcause 
	csrr 	a3, mhartid 
	csrr 	a4, mstatus 
	mv 		a5, t5 
	# load trap stack pointer
	ld 		sp, 520(a5) 
	# Go into zig trap handler
	call m_trap 

	# Zig trap handler will put return address to go to in a0. 
	csrw 	mepc, a0 

	csrr 	t6, mscratch 

	# Restore GP registers
	.set 	i, 1
	.rept 	31 
		load_gp %i 
		.set 	i, i+1 
	.endr 

	mret 

.global switch_to_user
switch_to_user:
	# a0 - Frame Address
	# a1 - Program Counter 
	# a2 - SATP Register
	csrw 	mscratch, a0 

	li 		t0, (1 << 7) | (1 << 5)
	csrw 	mstatus, t0 
	csrw 	mepc, a1 
	csrw 	satp, a2 
	li 		t1, 0xaaa 
	csrw 	mie, t1 
	la 		t2, m_trap_vector 
	csrw 	mtvec, t2 

	# j .

	sfence.vma 

	mv 		t6, a0 
	.set 	i, 1
	.rept 	31 
		load_gp %i, t6 
		.set 	i, i+1 
	.endr 

	mret 