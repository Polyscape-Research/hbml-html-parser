#include "simd.h"
#include <stdalign.h>
#include <stdio.h>
#include <immintrin.h>

#define SIZE 1024 

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

