#include "simd.h"
#include <stdalign.h>
#include <stdio.h>

#define SIZE 1024 

#if defined(__x86_64__) || defined(_M_X64)
#include <immintrin.h>


alignas(16) float in[SIZE];
alignas(16) float comp[SIZE];
alignas(16) float out[SIZE];

// TODO test if C's simd is faster than zigs

int find_bottom_simd(float a[], int b) {
    for (int i = 0; i < SIZE; i++) {
        in[i] = a[i];
    }
    return 1;
}

#endif
