// PCG32, the generator family Godot's RandomNumberGenerator uses.
#include "sim.h"

#define PCG_MULT 6364136223846793005ULL
#define PCG_DEFAULT_INC 1442695040888963407ULL
#define U24_RANGE 16777216.0f // 2^24: float32 mantissa for a uniform [0,1)

uint32_t rng_u32(Rng *r) {
    uint64_t old = r->state;
    r->state = old * PCG_MULT + r->inc;
    uint32_t xorshifted = (uint32_t)(((old >> 18u) ^ old) >> 27u);
    uint32_t rot = (uint32_t)(old >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((~rot + 1u) & 31u));
}

void rng_seed(Rng *r, uint64_t seed) {
    r->state = 0u;
    r->inc = (PCG_DEFAULT_INC << 1u) | 1u;
    rng_u32(r);
    r->state += seed;
    rng_u32(r);
}

float rng_range(Rng *r, float lo, float hi) {
    float unit = (float)(rng_u32(r) >> 8u) / U24_RANGE;
    return lo + unit * (hi - lo);
}
