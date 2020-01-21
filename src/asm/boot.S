# boot.S bootloader of ZBZZ.OS
# Preston Provins
# 1/18/2020
.option norvc
.section .data

.section .text.init
.global _start
_start:
	# Tell any Hardware threads not helping bootstrap
	# to kindly wait.
	csrr  t0, mhartid
	bnez  t0, park
	# SATP should be zero, but let's make sure
	csrw  satp, zero
	la t0, _bss
	la t1, _ebss
	bgeu	t0, t1, contpoint

contpoint:
park:
infloop:
  wfi
  j infloop
mret