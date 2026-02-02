#!/bin/bash

KSU_DIR="KernelSU"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Checking if submodules are synced...${NC}"

if git submodule status KernelSU AnyKernel3 | grep -q '^[+-]'; then
    echo -e "${RED}Submodules are not synced, syncing them...${NC}"
    git submodule update --init
else
    echo -e "${GREEN}Submodules are already synced.${NC}"
fi

echo
echo "This script patches KernelSU to ensure it compiles correctly on this kernel."
echo
echo -e "${RED}You do NOT need this script for building the kernel via build.sh.${NC}"
echo
read -rp "Continue patching KernelSU? [y/N]: " ANSWER

if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo
echo -e "${YELLOW}Patching KernelSU...${NC}"
echo

# Fix U16_MAX in allowlist.c
sed -i '/#include/a #ifndef U16_MAX\n#define U16_MAX ((u16)~0U)\n#endif' \
    "$KSU_DIR/kernel/allowlist.c"

# Fix struct initialization in throne_tracker.c
sed -i 's/struct data_path data = { 0 };/struct data_path data = { { 0 } };/g' \
    "$KSU_DIR/kernel/throne_tracker.c"

# Cleanup Makefile flags
sed -i 's/ccflags-y += -Wno-incompatible-pointer-types//g' "$KSU_DIR/kernel/Makefile"
sed -i 's/ccflags-y += -Wno-gcc-compat//g' "$KSU_DIR/kernel/Makefile"
sed -i 's/ccflags-y += -Wno-int-conversion//g' "$KSU_DIR/kernel/Makefile"

# Allow larger stack frames
echo "ccflags-y += -Wframe-larger-than=2048" >> "$KSU_DIR/kernel/Makefile"

echo -e "${GREEN}Done.${NC}"
echo
