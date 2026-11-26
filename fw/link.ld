/* 4 KB of block RAM at address 0: code, data and stack together. */
MEMORY { ram : ORIGIN = 0x00000000, LENGTH = 4096 }

SECTIONS {
    .text : {
        *(.text.start)
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        *(.data*)
        *(.sdata*)
        *(.bss*)
        *(.sbss*)
    } > ram
}
