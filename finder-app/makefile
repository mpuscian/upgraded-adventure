CROSS_COMPILE ?= "native"
.SILENT: default clean

default:
	# echo "$(CROSS_COMPILE)"; \
	if [ "$(CROSS_COMPILE)" = "aarch64-none-linux-gnu-" ]; then \
		aarch64-linux-gnu-gcc writer.c -o writer; \
	elif [ "$(CROSS_COMPILE)" = "native" ]; then \
		gcc writer.c -o writer; \
	else \
		echo "incorrect arguments"; \
	fi \

clean:
	rm -f writer
	rm -f *.o
