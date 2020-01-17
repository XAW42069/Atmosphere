/*
 * Copyright (c) 2019 Atmosphère-NX
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "asm_macros.s"

.section    .crt0, "ax", %progbits
.align      3
.global     _start
.type       _start, %function

_start:
    b       start
    b       start2

.global g_initialKernelEntrypoint
g_initialKernelEntrypoint:
    .quad   0

start:
    mov     x19, #1
    b       _startCommon
.global start2
.type   start2, %function
start2:
    mov     x19, xzr
_startCommon:
    // Disable interrupts, select sp_el2
    msr     daifset, 0b1111
    msr     spsel, #1

    mrs     x20, cntpct_el0

    // Set sctlr_el2 ASAP to disable mmu/caching if not already done.
    mov     x1, #0x0838
    movk    x1, #0x30C5,lsl #16
    msr     sctlr_el2, x1
    dsb     sy
    isb

    bl      cacheClearLocalDataCacheOnBoot
    cbz     x19, 1f

    // "Boot core only" stuff:
    bl      cacheClearSharedDataCachesOnBoot
    // Temporarily use temp end region as stack, then create the translation table
    adr     x0, _imageLayout
    ldr     x8, [x0, #8]
    ldr     x9, [x0, #0x20]
    add     sp, x8, x9
    bl      memoryMapSetupMmu

1:
    // Enable MMU, note that the function is not allowed to use any stack
    adr     x0, _imageLayout
    ldr     x18, =_postMmuEnableReturnAddr
    orr     x18, x18, #1
    bl      memoryMapEnableMmu

    // This is where we will land on exception return after enabling the MMU:
_postMmuEnableReturnAddr:
    // Get core ID
    mrs     x8, mpidr_el1
    and     x8, x8, #0xFF

    mov     w0, w8
    bl      memoryMapGetStackTop
    mov     sp, x0

    // Set up x18, other sysregs, BSS, etc.
    // Don't call init array to save space?
    mov     w0, w8
    mov     w1, w19
    bl      initSystem

    // Save x18, reserve space for exception frame
    stp     x18, xzr, [sp, #-0x10]!
    sub     sp, sp, #EXCEP_STACK_FRAME_SIZE

    dsb     sy
    isb

    mov     x0, sp
    mov     x1, x20
    bl      thermosphereMain

    dsb     sy
    isb

    // Jump to kernel
    b       _restoreAllRegisters

.pool

/*
typedef struct LoadImageLayout {
    uintptr_t startPa;
    uintptr_t tempPa;
    uintptr_t vbar;

    size_t maxImageSize;
    size_t maxTempSize;
    size_t mmuTable;
    size_t imageSize; // "image" includes "real" BSS but not tempbss
} LoadImageLayout;
*/
_imageLayout:
    .quad       __start_pa__
    .quad       __temp_pa__
    .quad       __vectors_start__
    .quad       __max_image_size__
    .quad       __max_temp_size__
    .quad       __mmu_tbl__
    .quad        __image_size__
