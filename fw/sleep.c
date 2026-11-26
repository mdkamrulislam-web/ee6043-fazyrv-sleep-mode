// LED counter that SLEEPS between steps instead of busy-waiting (needs the SLEEP design).
// Same behaviour as main.c: binary count on LED0-LED3, SW0 = 1 makes it four times faster.
// main.c waits in a software loop (the processor keeps running); this program asks the
// sleep controller to stop the processor's clock for SLEEP_CYCLES clock cycles.

#define GPIO  (*(volatile unsigned int *)0x10000000u)
#define SLEEP (*(volatile unsigned int *)0x20000000u)   // write N: sleep N clock cycles

#ifndef SLEEP_CYCLES
#define SLEEP_CYCLES 96250000u   // about 0.77 s at 125 MHz, like main.c on the 4-bit core
#endif

int main(void)
{
    unsigned int count = 0;
    for (;;) {
        GPIO = count;
        count++;
        SLEEP = (GPIO & 1u) ? (SLEEP_CYCLES / 4u) : SLEEP_CYCLES;
    }
}
