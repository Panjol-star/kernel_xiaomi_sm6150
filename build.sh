#!/bin/bash
#
# Compile script for kernel
#

SECONDS=0 # builtin bash timer

# Allowed codenames
ALLOWED_CODENAMES=("sweet" "courbet" "tucana" "toco" "phoenix" "davinci")

# Bypass prompt jika dijalankan di GitHub Actions (mengambil dari env variable DEVICE)
if [ -z "$DEVICE" ]; then
    read -p "Enter device codename: " DEVICE
fi

# Check if the entered codename is in the allowed list
if [[ ! " ${ALLOWED_CODENAMES[@]} " =~ " ${DEVICE} " ]]; then
    echo "Error: Invalid codename. Allowed codenames are: ${ALLOWED_CODENAMES[*]}"
    exit 1
fi

ZIPNAME="${DEVICE}-$(date '+%Y%m%d-%H%M').zip"

export ARCH=arm64
export KBUILD_BUILD_USER=runner
export KBUILD_BUILD_HOST=github@workflows

# Menyesuaikan path clang dengan direktori hasil clone di GitHub Actions
export PATH="${PWD}/clang/bin:$PATH"

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
	echo "Cleaned output folder"
fi

echo -e "\nStarting compilation for $DEVICE...\n"

make O=out ARCH=arm64 ${DEVICE}_defconfig
make -j$(nproc) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

echo -e "\nKernel compiled successfully! Zipping up...\n"

if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
else
	if ! git clone -q https://github.com/basamaryan/AnyKernel3 -b master AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
fi

# Modify anykernel.sh to replace device names
sed -i "s/device\.name1=.*/device.name1=${DEVICE}/" AnyKernel3/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=${DEVICE}in/" AnyKernel3/anykernel.sh

cp $kernel AnyKernel3
cp $dtbo AnyKernel3
cp $dtb AnyKernel3
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git
cd ..
rm -rf AnyKernel3
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
