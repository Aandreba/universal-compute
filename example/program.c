#define export
// #define export __kernel

export void saxpy(int offset, int n, float a, const float* x, float* y) {
    for (int i = 0; i < n; i++) {
        y[offset + i] += a * x[offset + i];
    }
}
