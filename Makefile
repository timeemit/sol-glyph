OUT_DIR := ./dist
SOLANA_TOOLS = $(shell dirname $(shell which cargo-build-bpf))
include ~/.local/share/solana/install/active_release/bin/sdk/bpf/c/bpf.mk

