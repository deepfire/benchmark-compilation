VERBOSE ?=
DEBUG ?=
TRACE ?=
KEEP_GOING ?=
GHC ?=
CLASH_NIXPKGS ?=
CLASH_PINNED ?=
SHELL := $(shell which bash)
COMMON_FLAGS := $(if ${VERBOSE},--verbose) $(if ${DEBUG},--debug) $(if ${TRACE},--trace) $(if ${KEEP_GOING},--keep-going) $(if ${GHC},--ghc ${GHC}) $(if ${CLASH_NIXPKGS},--clash-nixpkgs) $(if ${CLASH_PINNED},--clash-pinned)

all: bench

bench:
	@./bench/bench.sh ${COMMON_FLAGS} benchmark
prepare:
	@./bench/bench.sh ${COMMON_FLAGS} prepare
measure:
	@./bench/bench.sh ${COMMON_FLAGS} measure

.PHONY: all bench cls
cls:
	@echo -en "\ec"
