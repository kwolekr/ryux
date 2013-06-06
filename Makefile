PROGNAME = ryux
rm = /bin/rm -f
CC = cc
CXX = c++
AS = nasm
DEFS = -Wno-multichar
INCLUDES = -I. -I/usr/local/include
LIBS = -L/usr/local/lib
DEFINES = $(INCLUDES) $(DEFS) -DSYS_UNIX=1

ASFLAGS = 

#
# The order in which these are listed is *very important*!
# They determine where in the image each module is placed
#
SOURCES = bootloader/bootloader_I.asm \
bootloader/bootloader_II.asm \
kernel/kernel.asm \
drivers/fdc_driver.asm \

OBJECTS = ${SOURCES:.asm=.bin}
SRCS = ${addprefix src/,$(SOURCES)}
OBJS = ${addprefix obj/,$(OBJECTS)}

.SILENT:

obj/%.bin: src/%.asm
	mkdir -p $(@D);
	$(rm) $@;
	if ${AS} ${ASFLAGS} $< -o $@; then \
		printf "\033[32mbuilt $@.\033[m\n"; \
	else \
		printf "\033[31mbuild of $@ failed!\033[m\n"; \
		false; \
	fi
	
all: $(PROGNAME)
debug: $(PROGNAME)

$(PROGNAME) : $(OBJS)
	cat $(OBJS) > $(PROGNAME)
	printf "\033[32mlinked $@.\033[m\n"

clean:
	$(rm) $(PROGNAME) core *~
	$(rm) -rf obj/*

