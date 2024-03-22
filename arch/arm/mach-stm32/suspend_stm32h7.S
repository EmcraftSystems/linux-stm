/* SPDX-License-Identifier: GPL-2.0 */
/*
 * arch/arm/mach-stm32/suspend_stm32h7.S
 *
 * STM32 low-level suspend-to-RAM code. This code is relocated to
 * TCM during stm32_pm_init()
 *
 * Copyright (C) 2024 Emcraft Systems
 * Vladimir Skvortsov, Emcraft Systems, <vskvortsov@emcraft.com>
 *
 */

/*
 * This code runs from TCM (ARM tightly coupled memory).
 */

	.global stm32_suspend_to_ram
#if defined(CONFIG_PM_LPM_CODE_IN_TCM)
	.section .tcm.text, "ax"
#endif
	.align 4
	.thumb_func

stm32_suspend_to_ram:
	/*
	 * Put DDR into self-refresh
	 */
	ldr r0, fmc_sdcmr
	ldr r1, fmc_sdsr

	mov r2, #0xd		/* Program FMC_SDMR[CTB2][MODE] */
	str r2, [r0]

1:
	ldr r2, [r1]		/* Check FMC_SDSR[MODES2] */
	and r2, #0x18
	cmp r2, #0x8
	bne 1b

	/*
	 * Pass memory barriers, and switch to Sleep
	 */
	dsb
	isb
	wfi

	/*
	 * When at this point, we have been woken from Deep Sleep.
	 */

	/* Wait HSI clock is ready */
	ldr r0, rcc_rc
	ldr r2, rcc_rc_hsirdy
2:
	ldr r1, [r0]
	and r1, r2
	cmp r1, r2
	bne 2b

	/* Wait voltage levels ready (VOS3 is applied at this point) */
	ldr r0, pwr_csr1
	ldr r2, pwr_csr1_actvosrdy
3:
	ldr r1, [r0]
	and r1, r2
	cmp r1, r2
	bne 3b

	/* Restore VOS1 */
	ldr r0, pwr_d3cr
	ldr r1, [r0]
	orr r1, #0xc000
	and r1, #0xc000
	str r1, [r0]

	ldr r0, pwr_d3cr
	ldr r2, pwr_d3cr_vosrdy
4:
	ldr r1, [r0]
	and r1, r2
	cmp r1, r2
	bne 4b

	/* Re-enable HSE */
	ldr r0, rcc_rc
	ldr r1, [r0]
	ldr r2, rcc_rc_hseon
	orr r1, r2
	str r1, [r0]

	ldr r0, rcc_rc
	ldr r2, rcc_rc_hserdy
5:
	ldr r1, [r0]
	and r1, r2
	cmp r1, r2
	bne 5b

	/* Re-enable PLL1, PLL2 and PLL3 */
	ldr r0, rcc_rc
	ldr r1, [r0]
	ldr r2, rcc_rc_pllson
	orr r1, r2
	str r1, [r0]

	ldr r0, rcc_rc
	ldr r2, rcc_rc_pllsrdy
6:
	ldr r1, [r0]
	and r1, r2
	cmp r1, r2
	bne 6b

	/* Switch system clock to PLL1 */
	ldr r0, rcc_cfgr
	ldr r1, rcc_cfgr_sw1
	str r1, [r0]

	/*
	 * Take DDR out of self-refresh
	 */
	ldr r0, fmc_sdcmr
	ldr r1, fmc_sdsr

	mov r2, #0x8		/* Program FMC_SDMR[CTB2][MODE] */
	str r2, [r0]

7:
	ldr r2, [r1]		/* Check FMC_SDSR[MODES2] */
	ands r2, #0x18
	bne 7b

	/*
	 * Return to the kernel code running from DDR
	 */
	dsb
	isb
	bx lr

	.align 4
/* STM32H7 FMC registers and flags */
fmc_sdcmr:
	.word 0x52004150
fmc_sdsr:
	.word 0x52004158

/* STM32H7 RCC registers and flags */
rcc_rc:
	.word 0x58024400

rcc_cfgr:
	.word 0x58024410

rcc_cfgr_sw1:
	.word 0x3

rcc_rc_pllson:
	.word 0x15000000 /* PLL1 + PLL2 + PLL3 */

rcc_rc_pllsrdy:
	.word 0x2a000000

rcc_rc_hseon:
	.word 0x00010000

rcc_rc_hserdy:
	.word 0x00020000


rcc_rc_hsirdy:
	.word 0x00000004

rcc_rc_csirdy:
	.word 0x00000100

/* STM32H7 RWR registers and flags */
pwr_d3cr:
	.word 0x58024818

pwr_d3cr_vosrdy:
	.word 0x00002000

pwr_csr1:
	.word 0x58024804

pwr_csr1_actvosrdy:
	.word 0x00002000
