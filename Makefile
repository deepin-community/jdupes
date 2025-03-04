# jdupes Makefile

# Default flags to pass to the C compiler (can be overridden)
CFLAGS ?= -O2 -g

# PREFIX determines where files will be installed. Common examples
# include "/usr" or "/usr/local".
PREFIX = /usr/local

# PROGRAM_NAME determines the installation name and manual page name
PROGRAM_NAME = jdupes

# BIN_DIR indicates directory where program is to be installed.
# Suggested value is "$(PREFIX)/bin"
BIN_DIR = $(PREFIX)/bin

# MAN_DIR indicates directory where the jdupes man page is to be
# installed. Suggested value is "$(PREFIX)/man/man1"
MAN_BASE_DIR = $(PREFIX)/share/man
MAN_DIR = $(MAN_BASE_DIR)/man1
MAN_EXT = 1

# Required external tools
CC ?= gcc
INSTALL = install
RM      = rm -f
RMDIR   = rmdir -p
MKDIR   = mkdir -p
INSTALL_PROGRAM = $(INSTALL) -m 0755
INSTALL_DATA    = $(INSTALL) -m 0644

# Main object files
OBJS += hashdb.o get_d_namlen.o
OBJS += args.o checks.o dumpflags.o extfilter.o filehash.o filestat.o jdupes.o helptext.o
OBJS += interrupt.o libjodycode_check.o loaddir.o match.o progress.o sort.o travcheck.o
OBJS += act_deletefiles.o act_linkfiles.o act_printmatches.o act_summarize.o act_printjson.o

# Configuration section
COMPILER_OPTIONS = -Wall -Wwrite-strings -Wcast-align -Wstrict-aliasing -Wstrict-prototypes -Wpointer-arith -Wundef
COMPILER_OPTIONS += -Wshadow -Wfloat-equal -Waggregate-return -Wcast-qual -Wswitch-default -Wswitch-enum -Wunreachable-code -Wformat=2
COMPILER_OPTIONS += -std=gnu11 -D_FILE_OFFSET_BITS=64 -fstrict-aliasing -pipe
COMPILER_OPTIONS += -DNO_ATIME

# Remove unused code if requested
ifdef GC_SECTIONS
 COMPILER_OPTIONS += -fdata-sections -ffunction-sections
 LINK_OPTIONS += -Wl,--gc-sections
endif


# Bare-bones mode (for the adventurous lunatic) - includes all LOW_MEMORY options
ifdef BARE_BONES
 LOW_MEMORY = 1
 COMPILER_OPTIONS += -DNO_DELETE -DNO_TRAVCHECK -DBARE_BONES -DNO_ERRORONDUPE
 COMPILER_OPTIONS += -DNO_HASHDB -DNO_HELPTEXT -DCHUNK_SIZE=4096 -DPATHBUF_SIZE=1024
endif

# Low memory mode
ifdef LOW_MEMORY
 USE_JODY_HASH = 1
 DISABLE_DEDUPE = 1
 override undefine ENABLE_DEDUPE
 COMPILER_OPTIONS += -DLOW_MEMORY
 COMPILER_OPTIONS += -DNO_HARDLINKS -DNO_SYMLINKS -DNO_USER_ORDER -DNO_PERMS
 COMPILER_OPTIONS += -DNO_ATIME -DNO_JSON -DNO_EXTFILTER -DNO_CHUNKSIZE
 COMPILER_OPTIONS += -DNO_JODY_SORT
 ifndef BARE_BONES
  COMPILER_OPTIONS += -DCHUNK_SIZE=16384
 endif
endif


UNAME_S=$(shell uname -s)

# Are we running on a Windows OS?
ifeq ($(OS), Windows_NT)
 ifndef NO_WINDOWS
  ON_WINDOWS=1
 endif
endif

# Debugging code inclusion
ifdef LOUD
 DEBUG=1
 COMPILER_OPTIONS += -DLOUD_DEBUG
endif
ifdef DEBUG
 COMPILER_OPTIONS += -DDEBUG
else
 COMPILER_OPTIONS += -DNDEBUG
endif
ifdef HARDEN
 COMPILER_OPTIONS += -Wformat -Wformat-security -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE -fpie -Wl,-z,relro -Wl,-z,now
endif

# MinGW needs this for printf() conversions to work
ifdef ON_WINDOWS
 ifndef NO_UNICODE
  UNICODE=1
  COMPILER_OPTIONS += -municode
 endif
 SUFFIX=.exe
 LIBEXT=.dll
 COMPILER_OPTIONS += -D__USE_MINGW_ANSI_STDIO=1 -DON_WINDOWS=1
 ifeq ($(UNAME_S), MINGW32_NT-5.1)
  OBJS += winres_xp.o
 else
  OBJS += winres.o
 endif
 override undefine ENABLE_DEDUPE
 DISABLE_DEDUPE = 1
else
 LIBEXT=.so
endif

# Don't use unsupported compiler options on gcc 3/4 (Mac OS X 10.5.8 Xcode)
# ENABLE_DEDUPE by default - macOS Sierra 10.12 and up required
ifeq ($(UNAME_S), Darwin)
 GCCVERSION = $(shell expr `LC_ALL=C gcc -v 2>&1 | grep '[cn][cg] version' | sed 's/[^0-9]*//;s/[ .].*//'` \>= 5)
 ifndef DISABLE_DEDUPE
  ENABLE_DEDUPE = 1
 endif
else
 GCCVERSION = 1
 BDYNAMIC = -Wl,-Bdynamic
 BSTATIC = -Wl,-Bstatic
endif

ifeq ($(GCCVERSION), 1)
 COMPILER_OPTIONS += -Wextra -Wstrict-overflow=5 -Winit-self
endif

# Use jody_hash instead of xxHash if requested
ifdef USE_JODY_HASH
 COMPILER_OPTIONS += -DUSE_JODY_HASH -DNO_XXHASH2
 OBJS_CLEAN += xxhash.o
 else
 ifndef EXTERNAL_HASH_LIB
  OBJS += xxhash.o
 endif
endif  # USE_JODY_HASH

# Stack size limit can be too small for deep directory trees, so set to 16 MiB
# The ld syntax for Windows is the same for both Cygwin and MinGW
ifndef LOW_MEMORY
 ifeq ($(OS), Windows_NT)
  COMPILER_OPTIONS += -Wl,--stack=16777216
 else ifeq ($(UNAME_S), Darwin)
  COMPILER_OPTIONS += -Wl,-stack_size -Wl,0x1000000
 else
  COMPILER_OPTIONS += -Wl,-z,stack-size=16777216
 endif
endif

# Don't do clonefile on Mac OS X < 10.13 (High Sierra)
ifeq ($(UNAME_S), Darwin)
 DARWINVER := $(shell expr `uname -r | cut -d. -f1` \< 17)
 ifeq "$(DARWINVER)" "1"
  COMPILER_OPTIONS += -DNO_CLONEFILE=1
 endif
endif

### Dedupe feature stuff (BTRFS, XFS, APFS)

# ENABLE_DEDUPE should be ON by default for Linux
ifeq ($(UNAME_S), Linux)
 ifndef DISABLE_DEDUPE
  ENABLE_DEDUPE = 1
 endif
endif

# Allow forced override of ENABLE_DEDUPE
ifdef DISABLE_DEDUPE
 override undefine ENABLE_DEDUPE
 override undefine STATIC_DEDUPE_H
endif

# Catch someone trying to enable dedupe in flags and turn on ENABLE_DEDUPE
ifneq (,$(findstring DENABLE_DEDUPE,$(CFLAGS) $(CFLAGS_EXTRA)))
 ENABLE_DEDUPE = 1
 $(warn Do not enable dedupe in CFLAGS; use make ENABLE_DEDUPE=1 instead)
 ifdef DISABLE_DEDUPE
  $(error DISABLE_DEDUPE set but -DENABLE_DEDUPE is in CFLAGS. Choose only one)
 endif
endif

# Actually enable dedupe
ifdef ENABLE_DEDUPE
 COMPILER_OPTIONS += -DENABLE_DEDUPE
 OBJS += act_dedupefiles.o
else
 OBJS_CLEAN += act_dedupefiles.o
endif
ifdef STATIC_DEDUPE_H
 COMPILER_OPTIONS += -DSTATIC_DEDUPE_H
endif


### Find and use nearby libjodycode by default
ifndef IGNORE_NEARBY_JC
 ifneq ("$(wildcard ../libjodycode/libjodycode.h)","")
  $(info Found and using nearby libjodycode at ../libjodycode)
  COMPILER_OPTIONS += -I../libjodycode -L../libjodycode
  ifeq ("$(wildcard ../libjodycode/version.o)","")
   $(error You must build libjodycode before building jdupes)
  endif
 endif
 STATIC_LDFLAGS += ../libjodycode/libjodycode.a
 ifdef ON_WINDOWS
  DYN_LDFLAGS += -l:../libjodycode/libjodycode$(LIBEXT)
 else
  DYN_LDFLAGS += -ljodycode
 endif
endif


CFLAGS += $(COMPILER_OPTIONS) $(CFLAGS_EXTRA)
LDFLAGS += $(LINK_OPTIONS) $(LDFLAGS_EXTRA)


all: libjodycode_hint $(PROGRAM_NAME) dynamic_jc

dynamic_jc: $(PROGRAM_NAME)
	$(CC) $(CFLAGS) $(OBJS) $(BDYNAMIC) $(LDFLAGS) $(DYN_LDFLAGS) -o $(PROGRAM_NAME)$(SUFFIX)

static_jc: $(PROGRAM_NAME)
	$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) $(STATIC_LDFLAGS) $(BDYNAMIC) -o $(PROGRAM_NAME)$(SUFFIX)

static: $(PROGRAM_NAME)
	$(CC) $(CFLAGS) $(OBJS) -static $(LDFLAGS) $(STATIC_LDFLAGS) -o $(PROGRAM_NAME)$(SUFFIX)

static_stripped: $(PROGRAM_NAME) static
	-strip $(PROGRAM_NAME)$(SUFFIX)

$(PROGRAM_NAME): $(OBJS)
	:

winres.o: winres.rc winres.manifest.xml
	./tune_winres.sh
	windres winres.rc winres.o

winres_xp.o: winres_xp.rc
	./tune_winres.sh
	windres winres_xp.rc winres_xp.o

installdirs:
	test -e $(DESTDIR)$(BIN_DIR) || $(MKDIR) $(DESTDIR)$(BIN_DIR)
	test -e $(DESTDIR)$(MAN_DIR) || $(MKDIR) $(DESTDIR)$(MAN_DIR)

install: $(PROGRAM_NAME) installdirs
	$(INSTALL_PROGRAM)	$(PROGRAM_NAME)$(SUFFIX)   $(DESTDIR)$(BIN_DIR)/$(PROGRAM_NAME)$(SUFFIX)
	$(INSTALL_DATA)		$(PROGRAM_NAME).1 $(DESTDIR)$(MAN_DIR)/$(PROGRAM_NAME).$(MAN_EXT)

uninstalldirs:
	-test -e $(DESTDIR)$(BIN_DIR) && $(RMDIR) $(DESTDIR)$(BIN_DIR)
	-test -e $(DESTDIR)$(MAN_DIR) && $(RMDIR) $(DESTDIR)$(MAN_DIR)

uninstall: uninstalldirs
	$(RM)	$(DESTDIR)$(BIN_DIR)/$(PROGRAM_NAME)$(SUFFIX)
	$(RM)	$(DESTDIR)$(MAN_DIR)/$(PROGRAM_NAME).$(MAN_EXT)

test:
	./test.sh

stripped: $(PROGRAM_NAME)
	strip $(PROGRAM_NAME)$(SUFFIX)

clean:
	$(RM) $(OBJS) $(OBJS_CLEAN) build_date.h $(PROGRAM_NAME)$(SUFFIX) *~ .*.un~ *.gcno *.gcda *.gcov

distclean: clean
	$(RM) -rf *.pkg.tar* jdupes-*-*/ jdupes-*-*.zip

chrootpackage:
	+./chroot_build.sh

package:
	+./generate_packages.sh $(ARCH)

libjodycode_hint:
	$(info hint: if ../libjodycode is built but jdupes won't run, try doing 'make static_jc')
