#!/bin/bash

# Modified for Poco X7 Pro (Mediatek) - No AnyKernel

kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
output_dir="${kernel_dir}/output"
kernel_name="Avarice-kernel_"
zip_name="$kernel_name$(date +"%Y%m%d").zip"
ZIMAGE="${objdir}/arch/arm64/boot/Image.gz"
CLANG_DIR="${kernel_dir}/tc/clang"
GCC64_DIR="${kernel_dir}/tc/gcc64"
GCC32_DIR="${kernel_dir}/tc/gcc32"
MKDTIMG="${kernel_dir}/tc/mkdtimg"
DTB_IMG="${objdir}/arch/arm64/boot/dtb.img"

export CONFIG_FILE="gki_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_HOST=adams4d13
export KBUILD_BUILD_USER=arch-linux
export PATH="${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"

# Colors
NC='\033[0m'
RED='\033[0;31m'
LGR='\033[1;32m'
LYW='\033[1;33m'

clone_tools() {
    echo -e "${LYW}Setting up toolchains...${NC}"
    
    mkdir -p "${kernel_dir}/tc"

    [ -d "$CLANG_DIR" ] || {
        echo -e "${LYW}Cloning Crdroid Clang...${NC}"
        git clone -q --depth=1 --single-branch \
            https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git \
            -b 15.0 "$CLANG_DIR"
    }

    [ -d "$GCC64_DIR" ] || {
        echo -e "${LYW}Cloning GCC64...${NC}"
        git clone -q --depth=1 --single-branch \
            https://github.com/mvaisakh/gcc-arm64.git "$GCC64_DIR"
    }

    [ -d "$GCC32_DIR" ] || {
        echo -e "${LYW}Cloning GCC32...${NC}"
        git clone -q --depth=1 --single-branch \
            https://github.com/mvaisakh/gcc-arm.git "$GCC32_DIR"
    }

    [ -f "$MKDTIMG" ] || {
        echo -e "${LYW}Cloning mkdtimg...${NC}"
        git clone -q --depth=1 \
            https://android.googlesource.com/platform/system/libufdt "${kernel_dir}/tc/libufdt"
        make -C "${kernel_dir}/tc/libufdt/utils"
        cp "${kernel_dir}/tc/libufdt/utils/src/mkdtboimg.py" "$MKDTIMG"
    }
}

make_defconfig() {
    echo -e "${LGR}Generating Defconfig${NC}"
    make -s ARCH=${ARCH} O=${objdir} ${CONFIG_FILE} -j$(nproc)
}

compile() {
    echo -e "${LGR}######### Compiling kernel #########${NC}"
    make -j$(nproc) -l$(nproc) \
        O=${objdir} \
        ARCH=arm64 \
        CC="ccache clang" \
        SUBARCH=arm64 \
        DTC_EXT=dtc \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
        AR=llvm-ar \
        STRIP=llvm-strip \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        READELF=llvm-readelf \
        HOSTCC=clang \
        HOSTCXX=clang++ \
        HOSTAR=llvm-ar \
        HOSTLD=ld.lld \
        LLVM_NM=llvm-nm \
        LD=ld.lld \
        NM=llvm-nm \
        LLVM=1 \
        LLVM_IAS=1
}

create_images() {
    echo -e "${LGR}Creating DTB image...${NC}"
    
    # For Mediatek, concatenate all dtb files into dtb.img
    if find "${objdir}/arch/arm64/boot/dts/mediatek" -name '*.dtb' | grep -q .; then
        find "${objdir}/arch/arm64/boot/dts/mediatek" -name '*.dtb' -exec cat {} + > "${DTB_IMG}"
    else
        echo -e "${RED}Error: No DTB files found in ${objdir}/arch/arm64/boot/dts/mediatek${NC}"
        exit 1
    fi
}

package_kernel() {
    echo -e "${LGR}Packaging kernel images...${NC}"
    
    mkdir -p "${output_dir}"
    cp -v "${ZIMAGE}" "${DTB_IMG}" "${output_dir}/"
    
    # Create a simple zip with just the kernel images
    (cd "${output_dir}" && zip -r9 "${zip_name}" "Image.gz" "dtb.img")
    
    echo -e "${LGR}Kernel images packaged to: ${output_dir}/${zip_name}${NC}"
}

finalize_build() {
    cd "${objdir}"
    
    if [[ -f "${ZIMAGE}" && -f "${DTB_IMG}" ]]; then
        echo -e "${LGR}Build successful!${NC}"
        package_kernel
    else
        echo -e "${RED}Build failed! Missing:${NC}"
        [ -f "${ZIMAGE}" ] || echo -e "${RED}- ${ZIMAGE}${NC}"
        [ -f "${DTB_IMG}" ] || echo -e "${RED}- ${DTB_IMG}${NC}"
        exit 1
    fi
}

echo -e "${LYW}Cleaning up space...${NC}"
sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache 2>/dev/null

clone_tools
make_defconfig
compile
create_images
finalize_build

cd "${kernel_dir}"
