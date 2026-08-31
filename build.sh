#!/bin/bash
set -euo pipefail

START_TIME=$(date +%s)
DATE=$(date +%Y%m%d)

# Directories
SRC_DIR="$(dirname "$(realpath "$0")")"
OUT_DIR="$SRC_DIR/out"
AK3_SRC="$SRC_DIR/AnyKernel3"
AK3_OUT="$OUT_DIR/AnyKernel3"
GCC32_DIR="$HOME/android/Toolchain/linaro_arm-linux-gnueabihf-7.5"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Build environment
export PATH="$GCC32_DIR/bin:$PATH"
export ARCH=arm
export SUBARCH=arm

if command -v ccache &>/dev/null; then
    echo -e "${YELLOW}ccache found, enabling it for this build.${NC}"
    export CROSS_COMPILE="ccache arm-linux-gnueabihf-"
else
    export CROSS_COMPILE="arm-linux-gnueabihf-"
fi

# Toolchain
if [ ! -d "$GCC32_DIR" ]; then
    echo -e "${RED}Toolchain not found.${NC}"
    echo -e "${YELLOW}Cloning GCC 7.5.0 toolchain to $GCC32_DIR...${NC}"
    mkdir -p "$HOME/android"
    git clone https://github.com/MayuriLabs/linaro_arm-linux-gnueabihf-7.5 "$GCC32_DIR" || {
        echo -e "${RED}Toolchain clone failed. Aborting.${NC}"
        exit 1
    }
fi

if [ ! -x "$GCC32_DIR/bin/arm-linux-gnueabihf-gcc" ]; then
    echo -e "${RED}Toolchain compiler not found at $GCC32_DIR/bin/arm-linux-gnueabihf-gcc.${NC}"
    echo -e "${RED}The clone may be incomplete or corrupted. Aborting.${NC}"
    exit 1
fi

# Variant (positional arg: "default" or "permissive")
VARIANT="${1:-default}"

case "$VARIANT" in
    default|permissive)
        ;;
    *)
        echo -e "${RED}Unknown variant: $VARIANT${NC}"
        echo "Usage: build.sh [default|permissive]"
        exit 1
        ;;
esac

# Naming
if [[ "$VARIANT" == "permissive" ]]; then
    ZIP_NAME="MidnightKernel-ha3g_${DATE}-permissive.zip"
else
    ZIP_NAME="MidnightKernel-ha3g_${DATE}.zip"
fi

# Submodules
if git submodule status --recursive | grep -E '^[+-]' > /dev/null; then
    echo -e "${RED}Submodules are not synced, syncing them...${NC}"
    git submodule update --init --recursive
fi

cd "$SRC_DIR" || exit 1

# Print variant
echo
echo -e "${YELLOW}Building kernel with $VARIANT variant.${NC}"

# Clean
if [ -f "$OUT_DIR/.config" ] || [ -f "$OUT_DIR/arch/arm/boot/zImage" ] || [ -f "$OUT_DIR/$ZIP_NAME" ]; then
    echo
    echo -ne "${GREEN}Clean build directory (out/)?${NC} [Y/n]: "
    read -r CLEAN_OUT || CLEAN_OUT=""
    echo

    if [[ ! "${CLEAN_OUT:-}" =~ ^[Nn]$ ]]; then
        rm -rf "$OUT_DIR"
    fi
fi

mkdir -p "$OUT_DIR"
BUILD_LOG="$OUT_DIR/build_${DATE}.log"

# Config
make O="$OUT_DIR" ARCH=arm lineageos_ha3g_defconfig 2>&1 | tee "$BUILD_LOG"

# Permissive patch
if [[ "$VARIANT" == "permissive" ]]; then
    # Append androidboot.selinux=permissive to the existing CONFIG_CMDLINE value
    sed -i '/^CONFIG_CMDLINE=/ s/"$/ androidboot.selinux=permissive"/' "$OUT_DIR/.config"
fi

# Build
make -j$(nproc) O="$OUT_DIR" KCFLAGS="-Wno-error" 2>&1 | tee -a "$BUILD_LOG"

if [ ! -f "$OUT_DIR/arch/arm/boot/zImage" ]; then
    echo -e "${RED}Build failed, zImage not found.${NC}"
    exit 1
fi

# Package
rm -rf "$AK3_OUT"
cp -r "$AK3_SRC" "$AK3_OUT"
cp "$OUT_DIR/arch/arm/boot/zImage" "$AK3_OUT/zImage"

(
    cd "$AK3_OUT" || exit 1
    rm -f "$OUT_DIR/$ZIP_NAME"
    zip -r9 "$OUT_DIR/$ZIP_NAME" . -x .git .gitignore .github/\* README.md LICENSE LICENCE || {
        echo -e "${RED}Packaging failed. Zip exited with error.${NC}"
        exit 1
    }
)

# Done
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo
echo -e "  ${GREEN}Build done:${NC}   $OUT_DIR/$ZIP_NAME"
echo
echo -e "  ${YELLOW}Variant:${NC}      $VARIANT"
echo
echo -e "  ${YELLOW}Build log:${NC}    $BUILD_LOG"
echo
echo -e "  ${YELLOW}Build time:${NC}   $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
echo
