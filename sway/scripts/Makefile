# Binários C das TUIs (tasks primeiro; dirs e menu global seguem).
# yambar-tasks-c vai ao lado dos scripts (gitignored); o toggle e o chip
# usam o binário se executável, senão o .py. UI exige notcurses;
# o core-test (só libc) roda em qualquer lugar, sem TTY.
CC ?= cc
CFLAGS ?= -std=c17 -O2 -Wall -Wextra -Werror

all: yambar-tasks-c yambar-dirs-c

yambar-tasks-c: yambar-tasks.c tasks-core.c tasks-core.h
	$(CC) $(CFLAGS) -o $@ yambar-tasks.c tasks-core.c \
	    $(shell pkg-config --cflags --libs notcurses)

yambar-dirs-c: yambar-dirs.c tasks-core.c tasks-core.h
	$(CC) $(CFLAGS) -o $@ yambar-dirs.c tasks-core.c \
	    $(shell pkg-config --cflags --libs notcurses)

core-test: tasks-core.c tasks-core.h
	$(CC) $(CFLAGS) -DTASKS_CORE_TEST -o $@ tasks-core.c

# Núcleo sob ASan/UBSan em /tmp (sem artefato no repo).
test: tasks-core.c tasks-core.h
	$(CC) -std=c17 -O1 -g -Wall -Wextra -Werror \
	    -fsanitize=address,undefined -DTASKS_CORE_TEST \
	    -o /tmp/opencode-tasks-core-asan tasks-core.c
	/tmp/opencode-tasks-core-asan

clean:
	rm -f yambar-tasks-c yambar-dirs-c core-test
