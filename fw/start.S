// Reset entry: set the stack pointer to the top of the 4 KB RAM, then run main().
.section .text.start
.global _start
_start:
    li   sp, 4096
    call main
1:  j    1b
