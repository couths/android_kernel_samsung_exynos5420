#!/bin/bash

START_TIME=$(date +%s)
DATE=$(date +%Y%m%d)

# Directories
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
AK3_SRC="$SRC_DIR/AnyKernel3"
AK3_OUT="$OUT_DIR/AnyKernel3"
GCC32_DIR="$HOME/android/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
VARIANT="default"
CUSTOM_NAME=""

# Build environment
export PATH="$GCC32_DIR/bin:$PATH"
export ARCH=arm
export SUBARCH=arm
export CROSS_COMPILE=arm-linux-androideabi-

# Toolchain
if [ ! -d "$GCC32_DIR" ]; then
    echo -e "${RED}Toolchain not found.${NC}"
    echo -e "${YELLOW}Cloning GCC 4.9 toolchain to $GCC32_DIR...${NC}"
    mkdir -p "$HOME/android"
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 "$GCC32_DIR"
fi

# Usage
usage() {
    echo
    echo "Usage: bash build.sh [variant] [options]"
    echo
    echo "Variants:"
    echo "  default        Build normal kernel (default)"
    echo "  permissive     Build with androidboot.selinux=permissive"
    echo
    echo "Options:"
    echo "  -n \"name\"      Custom zip name (without .zip)"
    echo "  -h             Show this help message"
    echo
    exit 0
}

# Options
while getopts ":n:h" opt; do
    case ${opt} in
        n)
            CUSTOM_NAME="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            ;;
    esac
done

shift $((OPTIND - 1))

# Variant
if [ -n "$1" ]; then
    case "$1" in
        permissive)
            VARIANT="permissive"
            ;;
        default)
            VARIANT="default"
            ;;
        *)
            echo "Unknown variant: $1"
            usage
            ;;
    esac
fi

# Naming
if [ -n "$CUSTOM_NAME" ]; then
    ZIP_NAME="$CUSTOM_NAME"
    [[ "$ZIP_NAME" != *.zip ]] && ZIP_NAME="$ZIP_NAME.zip"
else
    if [[ "$VARIANT" == "permissive" ]]; then
        ZIP_NAME="MidnightKernel-v1_ha3g_${DATE}-permissive.zip"
    else
        ZIP_NAME="MidnightKernel-v1_ha3g_${DATE}.zip"
    fi
fi

# Submodules
if git submodule status --recursive | grep -E '^-|\+' > /dev/null; then
    echo -e "${RED}Submodules are not synced, syncing them...${NC}"
    git submodule update --init --recursive
fi

cd "$SRC_DIR" || exit 1

# Print variant
echo
echo -e "${YELLOW}Building kernel with $VARIANT variant.${NC}"

# Clean
if [ -f "$OUT_DIR/.config" ] || [ -f "$OUT_DIR/arch/arm/boot/zImage" ]; then
    echo
    echo -ne "${GREEN}Clean build directory (out/)?${NC} [Y/n]: "
    read CLEAN_OUT
    echo

    if [[ "$CLEAN_OUT" =~ ^[Yy]$ ]]; then
        rm -rf "$OUT_DIR"
    fi
fi

mkdir -p "$OUT_DIR"

# Config
make O="$OUT_DIR" ARCH=arm lineageos_ha3g_defconfig

# Permissive patch
sed -i '/CONFIG_CMDLINE=/ s/androidboot.selinux=permissive//g' "$OUT_DIR/.config"
if [[ "$VARIANT" == "permissive" ]]; then
    sed -i '/CONFIG_CMDLINE=/ s/"$/ androidboot.selinux=permissive"/' "$OUT_DIR/.config"
fi

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
    zip -r9 "$OUT_DIR/$ZIP_NAME" . -x .git README.md .github\*
)

# Done
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo
echo -e "  ${GREEN}Build done:${NC}   $OUT_DIR/$ZIP_NAME"
echo
echo -e "  ${YELLOW}Variant:${NC}      $VARIANT"
echo
echo -e "  ${YELLOW}Build time:${NC}   $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
echo
