// LED counter for FazyRV on the PYNQ-Z2.
// GPIO (fsoc): writing 0x1000_0000 sets the LEDs, reading it returns SW0 in bit 0.
// The LEDs show a 4-bit binary counter. SW0 = 0: slow, SW0 = 1: four times faster.

#define GPIO (*(volatile unsigned int *)0x10000000u)

#ifndef DELAY_SLOW
#define DELAY_SLOW 3000000u   // loop passes per LED step (set by fw/build.sh)
#endif

static void wait(unsigned int n)
{
    // One pass = addi + bnez; the asm keeps the compiler from removing the loop.
    while (n--) {
        __asm__ volatile ("" ::: "memory");
    }
}

int main(void)
{
    unsigned int count = 0;
    for (;;) {
        GPIO = count;
        count++;
        wait((GPIO & 1u) ? (DELAY_SLOW / 4u) : DELAY_SLOW);
    }
}
