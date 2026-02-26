#!/bin/bash

START_TIME=$(date +%s)

SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
DATE=$(date +%Y%m%d)
ZIP_NAME="MidnightKernel-v1_ha3g_${DATE}.zip"
AK3_SRC="$SRC_DIR/AnyKernel3"
AK3_OUT="$OUT_DIR/AnyKernel3"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if git submodule status --recursive | grep -E '^-|\+' > /dev/null; then
    echo -e "${RED}Submodules are not synced, syncing them...${NC}"
    git submodule update --init --recursive
fi

# Toolchain
GCC32_DIR="/tmp/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"

if [ ! -d "$GCC32_DIR" ]; then
    echo -e "${RED}Toolchain not found.${NC}"
    echo -e "${YELLOW}Cloning GCC 4.9 toolchain...${NC}"
    cd /tmp || exit 1
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9
fi

cd "$SRC_DIR" || exit 1

export PATH="$GCC32_DIR/bin:$PATH"
export ARCH=arm
export SUBARCH=arm
export CROSS_COMPILE=arm-linux-androideabi-

# Clean
if [ -f "$OUT_DIR/.config" ] || [ -f "$OUT_DIR/arch/arm/boot/zImage" ]; then
    echo
    echo -ne "${GREEN}Clean build directory (out/)?${NC} [Y/n]: "
    read CLEAN_OUT
    echo

    if [[ "$CLEAN_OUT" =~ ^[Yy]$ ]]; then
        rm -rf "$OUT_DIR"
        # make clean
    fi
fi

mkdir -p "$OUT_DIR"

# Config
make O="$OUT_DIR" ARCH=arm lineageos_ha3g_defconfig

# Build
make -j$(nproc) O="$OUT_DIR" KCFLAGS="-Wno-error"

if [ ! -f "$OUT_DIR/arch/arm/boot/zImage" ]; then
    echo -e "${RED}Build failed. zImage not found. Aborting packaging.${NC}"
    exit 1
fi

# Package
rm -rf "$AK3_OUT"
cp -r "$AK3_SRC" "$AK3_OUT"

cp "$OUT_DIR/arch/arm/boot/zImage" "$AK3_OUT/zImage"

(
    cd "$AK3_OUT" || exit 1
    rm -f "$OUT_DIR/$ZIP_NAME"
    zip -r9 "$OUT_DIR/$ZIP_NAME" . \
        -x .git README.md .github\*
)

# Done
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo
echo -e "  ${GREEN}Build done:${NC}   $OUT_DIR/$ZIP_NAME"
echo -e "  ${YELLOW}Build time:${NC}   $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
echo
