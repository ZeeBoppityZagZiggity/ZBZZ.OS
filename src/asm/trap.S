# trap.S
# Assembly level trap handler

.option norvc

.altmacro
.set  GP_REG_COUNT, 32
.set  FP_REG_COUNT, 32
.set  REG_SIZE, 8
.set  MAX_CPUS, 8

.macro save_gp  i,  basereg=t6
  sd  x\i,  ((\i)*REG_SIZE)(\basereg)
.endm

.macro load_gp  i,  basereg=t6
  ld  x\i,  ((\i)*REG_SIZE)(\basereg)
.endm

.macro save_fp  i,  basereg=t6
  sd  f\i,  ((GP_REG_COUNT+(\i))*REG_SIZE)(\basereg)
.endm

.macro load_fp  i,  basereg=t6
  ld  f\i,  ((GP_REG_COUNT+(\i))*REG_SIZE)(\basereg)
.endm

.section .text
.global asm_trap_vector
.align 4
asm_trap_vector:
  csrrw   t6, mscratch, t6
  .set  i,  1
  .rept 30
    save_gp   %i
    .set  i,  i+1
  .endr

  mv  t5, t6
  csrr  t6, mscratch
  save_gp   31, t5

  csrw  mscratch, t5

  csrr	a0, mepc
  csrr	a1, mtval
  csrr	a2, mcause
  csrr	a3, mhartid
  csrr	a4, mstatus
  mv		a5, t5
  #ld		sp, 520(a5)
  call	ktrap

  csrw	mepc, a0
  csrr	t6, mscratch

  .set	i, 1
  .rept	31
    load_gp %i
    .set	i, i+1
  .endr

  mret