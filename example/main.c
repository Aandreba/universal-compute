#include <stdio.h>
#include <stdlib.h>
#include <universal-compute.h>

void errorHandler(uc_result res) {
    if (res < 0) {
        fprintf(stderr, "Error: %s (%ld)", ucErrorName(res), res);
        exit(1);
    }
}

int main() {
    puts("\n");
    const uc_context_config context_config = {.debug = true};
    const uc_buffer_config buffer_config;

    // Get devices
    size_t device_count = 5;
    uc_device *devices = (uc_device *)malloc(device_count * sizeof(uc_device));
    errorHandler(ucGetDevices(NULL, 0, devices, &device_count));
    printf("Available devices: %d\n", device_count);

    // Get device info
    for (int i = 0; i < device_count; i++) {
        const uc_device *device = &devices[i];
        printf("===== Device %d =====\n", i);

        // Get device backend
        size_t backend_len = sizeof(uc_backend);
        uc_backend backend;
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_BACKEND, &backend, &backend_len));
        printf("\tBackend: %s\n", ucBackendName(backend));

        // Get device vendor
        size_t vendor_len;
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_VENDOR, NULL, &vendor_len));
        char *vendor = malloc(vendor_len + 1);
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_VENDOR, vendor, &vendor_len));
        vendor[vendor_len] = 0;
        printf("\tVendor: %s\n", vendor);
        free(vendor);

        // Get device name
        size_t name_len;
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_NAME, NULL, &name_len));
        char *name = malloc(name_len + 1);
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_NAME, name, &name_len));
        name[name_len] = 0;
        printf("\tName: %s\n", name);
        free(name);

        // Get device core count
        size_t core_count_len = sizeof(size_t);
        size_t core_count;
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_CORE_COUNT, &core_count, &core_count_len));
        printf("\tCore count: %ld\n", core_count);

        // Create context
        uc_context context;
        const uc_result context_result = ucCreateContext(device, &context_config, &context);
        if (context_result < 0) {
            fprintf(stdout, "Error: %s (%ld)", ucErrorName(context_result), context_result);
            continue;
        }

        // Create buffer
        uc_buffer alpha;
        errorHandler(ucCreateBuffer(&context, 5 * sizeof(float), &buffer_config, &alpha));

        float alpha_contents[] = {1.f, 2.f, 3.f, 4.f, 5.f};
        uc_event write;
        errorHandler(ucBufferWrite(&alpha, 0, sizeof(alpha_contents), alpha_contents, &write));
        errorHandler(ucEventJoin(&write));
        errorHandler(ucEventRelease(&write));

        puts("Copied memory!\n");

        // Deinit everything
        errorHandler(ucBufferDeinit(&alpha));
        errorHandler(ucContextDeinit(&context));
        errorHandler(ucDeviceDeinit(device));
    }

    return ucDetectMemoryLeaks() ? 1 : 0;
}
