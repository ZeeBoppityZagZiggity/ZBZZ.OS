#ifndef UART_H
#define UART_H


#ifdef __cplusplus
#define UART_EXTERN_C extern "C"
#else
#define UART_EXTERN_C
#endif

#if defined(_WIN32)
#define UART_EXPORT UART_EXTERN_C __declspec(dllimport)
#else
#define UART_EXPORT UART_EXTERN_C __attribute__((visibility ("default")))
#endif

UART_EXPORT int c_put(int din);

#endif
