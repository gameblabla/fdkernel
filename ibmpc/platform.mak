#
# platform.mak - build target definition
#

CFLAGS_PLATFORM=-DIBMPC
NASMFLAGS_PLATFORM=-DIBMPC
#CFLAGS_PLATFORM=-DNEC98 -DJAPAN
#NASMFLAGS_PLATFORM=-DNEC98 -DJAPAN

ALLCFLAGS=$(ALLCFLAGS) $(CFLAGS_PLATFORM)
NASMFLAGS=$(NASMFLAGS) $(NASMFLAGS_PLATFORM)
