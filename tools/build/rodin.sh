#!/bin/bash

# Adaptado por Adam Spaini para POCO X7 Pro (rodin - MediaTek)

kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
output_dir="${kernel_dir}/output"
kernel_name="Kernel-Rodin_"
zip_name="${kernel_name}$(date +"%Y%m%d").zip"
ZIMAGE="${objdir}/arch/arm64/boot/Image.gz"  # O Image si no usas compresión
CLANG_DIR="${kernel_dir}/tc/clang"

export CONFIG_FILE="gki_defconfig"  # Asegúrate que exista
export ARCH="arm64"
export KBUILD_BUILD_HOST=rodin-builder
export KBUILD_BUILD_USER=adams4d13
export PATH="${CLANG_DIR}/bin:${PATH}"

# Colores
NC='\033[0m'
RED='\033[0;31m'
LGR='\033[1;32m'
LYW='\033[1;33m'

clone_tools() {
    echo -e "${LYW}Configurando toolchain...${NC}"
    mkdir -p "${kernel_dir}/tc"

    [ -d "$CLANG_DIR" ] || {
        echo -e "${LYW}Clonando CrDroid Clang...${NC}"
        git clone -q --depth=1 \
            https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git \
            -b 15.0 "$CLANG_DIR"
    }
}

make_defconfig() {
    echo -e "${LGR}Generando defconfig...${NC}"
    make ARCH=${ARCH} O=${objdir} ${CONFIG_FILE}
}

compile_kernel() {
    echo -e "${LGR}Compilando kernel...${NC}"
    make -j$(nproc) \
        O=${objdir} \
        ARCH=arm64 \
        CC="ccache clang" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        DTC_EXT=dtc \
        LLVM=1 \
        LLVM_IAS=1 \
        HOSTCC=clang \
        HOSTCXX=clang++
}

finalize() {
    echo -e "${LGR}Finalizando compilación...${NC}"

    if [[ -f "${ZIMAGE}" ]]; then
        mkdir -p "${output_dir}"
        cp -v "${ZIMAGE}" "${output_dir}/"
        echo -e "${LGR}✅ Kernel compilado exitosamente: ${ZIMAGE}${NC}"
    else
        echo -e "${RED}❌ Falló la compilación. No se encontró ${ZIMAGE}${NC}"
        exit 1
    fi
}

# Flujo principal
clone_tools
make_defconfig
compile_kernel
finalize