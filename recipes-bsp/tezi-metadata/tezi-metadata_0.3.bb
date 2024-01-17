DESCRIPTION = "Toradex Easy Installer Metadata"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://prepare.sh \
    file://wrapup.sh \
    file://toradexlinux.png \
    file://marketing.tar;unpack=false \
    file://u-boot-secondary-header \
"

inherit deploy nopackages

do_deploy () {
    install -m 644 ${WORKDIR}/prepare.sh ${DEPLOYDIR}
    install -m 644 ${WORKDIR}/wrapup.sh ${DEPLOYDIR}
    install -m 644 ${WORKDIR}/toradexlinux.png ${DEPLOYDIR}
    install -m 644 ${WORKDIR}/marketing.tar ${DEPLOYDIR}
    install -m 644 ${WORKDIR}/u-boot-secondary-header ${DEPLOYDIR}
}

addtask deploy before do_package after do_install

COMPATIBLE_MACHINE = "(apalis-imx6|apalis-t30|apalis-tk1|colibri-imx6|colibri-imx7)"

PACKAGE_ARCH = "${MACHINE_ARCH}"
