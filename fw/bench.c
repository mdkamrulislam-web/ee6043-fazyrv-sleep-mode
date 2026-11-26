// Workload program for the power measurements.
// Every pass does the same fixed job, which uses the whole core
// (shifts, XOR, add, compare, branches, byte and word loads/stores):
//   1. fill a 64-word buffer with pseudo-random numbers (xorshift32),
//   2. CRC-32 over the 256 bytes of the buffer (bit by bit),
//   3. insertion sort of the buffer,
//   4. checksum = CRC xor (sum of the sorted words, weighted by position).
// The result is compared with the value from fw/bench_ref.py.
// LEDs: pass counter (bits 3..0 of pass >> LED_SHIFT). On a wrong result the
// LEDs show 1010 and the program stops.

#define GPIO (*(volatile unsigned int *)0x10000000u)

#ifndef EXPECTED
#define EXPECTED 0u
#endif
#ifndef LED_SHIFT
#define LED_SHIFT 0
#endif

#define N 64

static unsigned int buf[N];

static unsigned int xorshift32(unsigned int *s)
{
    unsigned int x = *s;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *s = x;
    return x;
}

static unsigned int crc32(const unsigned char *p, unsigned int n)
{
    unsigned int crc = 0xFFFFFFFFu;
    for (unsigned int i = 0; i < n; i++) {
        crc ^= p[i];
        for (int k = 0; k < 8; k++)
            crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}

static void sort(unsigned int *a, unsigned int n)
{
    for (unsigned int i = 1; i < n; i++) {
        unsigned int v = a[i];
        unsigned int j = i;
        while (j > 0 && a[j - 1] > v) {
            a[j] = a[j - 1];
            j--;
        }
        a[j] = v;
    }
}

static unsigned int work(void)
{
    unsigned int seed = 0x12345678u;
    for (unsigned int i = 0; i < N; i++)
        buf[i] = xorshift32(&seed);
    unsigned int crc = crc32((const unsigned char *)buf, sizeof buf);
    sort(buf, N);
    unsigned int sum = 0;
    for (unsigned int i = 0; i < N; i++)
        sum += buf[i] ^ (i << 24);
    return crc ^ sum;
}

int main(void)
{
    unsigned int pass = 0;
    for (;;) {
        unsigned int r = work();
        if (r != EXPECTED) {
            GPIO = 0xAu;            // 1010 = wrong result
            for (;;) { }
        }
        pass++;
        GPIO = pass >> LED_SHIFT;
    }
}
