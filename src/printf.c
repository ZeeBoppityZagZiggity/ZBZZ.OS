#include"uart.h"
#include<stdarg.h>
// #include"printf.h"

// const char Rep[16] = "0123456789ABCDEF";

void cputs(const uint8_t * c) {
	int i = 0; 
	while(*(c + i) != '\0') {
		put(*(c + i)); 
		i++;
	}
}

char *convert(uint64_t num, int base) {
	// char Rep[] = "0123456789ABCDEF";
	char Rep[16];
	int i = 0;
	for (i = 0; i < 10; i++)
		Rep[i] = i + 48; 
	for (i = 10; i < 16; i++)
		Rep[i] = i + 87;
	char buf[32]; 
	char *ptr; 
	ptr = &buf[31]; 
	*ptr = '\0';

	do {
		*--ptr = Rep[num % base]; 
		num /= base; 
	} while(num != 0); 

	return ptr;
}

void printf(const char * format, ...) {
	char * traverse; 
	uint64_t i; 
	char *s; 

	va_list arg;
	va_start(arg, format); 

	for (traverse = format; *traverse != '\0'; traverse++) {
		while ( *traverse != '%') {
			if (*traverse == '\0') return;
			put(*traverse); 
			traverse++; 
		}

		traverse++; 
		switch(*traverse) {
			case 'c':
				i = va_arg(arg, int); 
				put(i);
				break;
			case 'd': 
				i = va_arg(arg, int);
				if (i < 0) {
					i = -i; 
					put('-');
				}
				cputs(convert(i, 10));
				break;
			case 's':
				s = va_arg(arg, char *); 
				cputs(s);
			case 'x':
				i = va_arg(arg, uint64_t);
				cputs(convert(i, 16));
				break;
		}
	}
	va_end(arg);
}

