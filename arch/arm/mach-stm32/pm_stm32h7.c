/* SPDX-License-Identifier: GPL-2.0 */
/*
 * arch/arm/mach-stm32/pm_stm32h7.c
 *
 * STM32 Power Management code
 *
 * Copyright (C) 2024 Emcraft Systems
 * Vladimir Skvortsov, Emcraft Systems, <vskvortsov@emcraft.com>
 *
 */

#include <linux/suspend.h>
#include <linux/sched.h>
#include <linux/proc_fs.h>
#include <linux/interrupt.h>
#include <linux/sysfs.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/io.h>
#include <linux/delay.h>
#include <linux/of_address.h>
#include <linux/of_platform.h>
#include <linux/clk.h>
#include <asm/v7m.h>

extern void stm32_suspend_to_ram(void);

/*
 * Linker symbols
 */
extern char __sitcm_text, __eitcm_text;
extern char __itcm_start;
extern char __sdtcm_data, __edtcm_data;
extern char __dtcm_start;

/*
 * Device data structure
 */
static struct platform_driver stm32_pm_driver = {
	.driver = {
		.name = "stm32_pm",
	},
};

/*
 * Validate suspend state
 * @state		State being entered
 * @returns		1->valid, 0->invalid
 */
static int stm32_pm_valid(suspend_state_t state)
{
	int ret;

	switch (state) {
	case PM_SUSPEND_MEM:
		ret = 1;
		break;
	default:
		ret = 0;
		break;
	}

	return ret;
}

/*
 * Enter suspend
 * @state		State being entered
 * @returns		0->success, <0->error code
 */
static int stm32_pm_enter(suspend_state_t state)
{
	volatile u32 *scr = (void *)(BASEADDR_V7M_SCB + V7M_SCB_SCR);

	/*
	 * Allow STOP mode. Enter SLEEP DEEP on WFI.
	 */
	*scr |= V7M_SCB_SCR_SLEEPDEEP;

	/*
	 * Jump to suspend code in TCM
	 */
	stm32_suspend_to_ram();
	
	/*
	 * Switch to Normal mode. Disable SLEEP DEEP on WFI.
	 */
	*scr &= ~V7M_SCB_SCR_SLEEPDEEP;

	return 0;
}

/*
 * Power Management operations
 */
static struct platform_suspend_ops stm32_pm_ops = {
	.valid = stm32_pm_valid,
	.enter = stm32_pm_enter,
};

/*
 * Driver init
 * @returns		0->success, <0->error code
 */
static int __init stm32_pm_init(void)
{
	int ret = 0;
#if defined(CONFIG_STM32H7_STOP_MODE)
#if defined(CONFIG_PM_LPM_CODE_IN_TCM)
	/*
	 * Relocate code to TCM
	 */
	memcpy((void*)&__sitcm_text, (void*)&__itcm_start,
	       &__eitcm_text - &__sitcm_text);
#endif

	/*
	 * Register the PM driver
	 */
	if (platform_driver_register(&stm32_pm_driver) != 0) {
		printk(KERN_ERR "%s: register failed\n", __func__);
		ret = -ENODEV;
		goto out;
	}

	/*
	 * Register PM operations
	 */
	suspend_set_ops(&stm32_pm_ops);

	/*
	 * Here means success
	 */
	printk(KERN_INFO "Power Management for STM32\n");
	ret = 0;
#endif
 out:
	return ret;
}

/*
 * Driver clean-up
 */
static void __exit stm32_pm_cleanup(void)
{
	platform_driver_unregister(&stm32_pm_driver);
}

module_init(stm32_pm_init);
module_exit(stm32_pm_cleanup);

MODULE_AUTHOR("Vladimir Skvortsov");
MODULE_DESCRIPTION("STM32 PM driver");
MODULE_LICENSE("GPL");
