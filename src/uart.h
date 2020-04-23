#ifndef UART_H
#define UART_H

#include <stdint.h>

#ifdef __cplusplus
#define UART_EXTERN_C extern "C"
#else
#define UART_EXTERN_C
#endif

UART_EXTERN_C void makeUART(void);
UART_EXTERN_C void put(uint8_t din);
UART_EXTERN_C void puts(uint8_t * din);
UART_EXTERN_C void print(uint8_t * din);
UART_EXTERN_C uint8_t read(void);

#endif
