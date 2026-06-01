
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>

int main ()
{
    int fd = open ("/proc/zynqpdp8l", O_RDWR);
    if (fd < 0) {
        fprintf (stderr, "open error: %m\n");
        return -1;
    }
    void *ptr = mmap (NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
        fprintf (stderr, "mmap error: %m\n");
        return -1;
    }
    uint32_t *arr = (uint32_t *)ptr;
    for (int i = 0; i < 1024; i += 16) {
        printf ("%03X :", i);
        for (int j = 0; j < 16; j ++) {
            printf (" %08X", arr[i+j]);
        }
        printf ("\n");
    }
    return 0;
}
