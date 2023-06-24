#include <stdio.h>
#include <stdlib.h>
#include <universal-compute.h>

void errorHandler(uc_result res)
{
    if (res < 0)
    {
        printf("Error: %s", (const char *)ucErrorName(res));
        exit(1);
    }
}

int main()
{
    printf("\n");

    // Get devices
    size_t device_count = 2;
    uc_device *devices = (uc_device *)malloc(device_count * sizeof(uc_device));
    errorHandler(ucGetDevices(NULL, 0, devices, &device_count));
    printf("Available devices: %d\n", device_count);

    // Get device info
    for (int i = 0; i < device_count; i++)
    {
        const uc_device *device = &devices[i];
        printf("===== Device %d =====\n", i);

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
        const size_t core_count_len = sizeof(size_t);
        size_t core_count;
        errorHandler(ucDeviceInfo(device, UC_DEVICE_INFO_CORE_COUNT, &core_count, &core_count_len));
        printf("\tCore count: %ld\n", core_count);

        errorHandler(ucDeviceDeinit(device));
    }

    free(devices);
}
