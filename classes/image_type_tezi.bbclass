inherit image_types

do_image_teziimg[depends] += "tezi-metadata:do_deploy virtual/bootloader:do_deploy persistent-storage:do_deploy"

TEZI_ROOT_FSTYPE ??= "ext4"
UBOOT_BINARY ??= "u-boot.${UBOOT_SUFFIX}"
UBOOT_BINARY_TEZI = "${UBOOT_BINARY}"
UBOOT_BINARY_TEZI_apalis-t30 = "apalis_t30.img"
UBOOT_BINARY_TEZI_apalis-tk1 = "apalis-tk1.img"
UBOOT_BINARY_TEZI_apalis-tk1-mainline = "apalis-tk1.img"
UBOOT_SECONDARY_HEADER = "u-boot-secondary-header"
OFFSET_UBOOT_SECONDARY_HEADER = "1"
OFFSET_UBOOT_SECONDARY = "1026"
PERSISTENT_IMAGE="persistent-tezi.tar.xz"

# for generic images this is not yet defined
TDX_VERDATE ?= "-${DATE}"
TDX_VERDATE[vardepsexclude] = "DATE"

def rootfs_get_size(d):
    import subprocess

    # Calculate size of rootfs in kilobytes...
    output = subprocess.check_output(['du', '-ks',
                                      d.getVar('IMAGE_ROOTFS', True)])
    return int(output.split()[0])

def rootfs_tezi_emmc(d):
    import subprocess
    from collections import OrderedDict
    deploydir = d.getVar('DEPLOY_DIR_IMAGE', True)
    kernel = d.getVar('KERNEL_IMAGETYPE', True)
    offset_bootrom = d.getVar('OFFSET_BOOTROM_PAYLOAD', True)
    offset_spl = d.getVar('OFFSET_SPL_PAYLOAD', True)
    imagename = d.getVar('IMAGE_NAME', True)
    imagename_suffix = d.getVar('IMAGE_NAME_SUFFIX', True)

    # Calculate size of bootfs...
    bootfiles = [ os.path.join(deploydir, kernel) ]
    has_devicetree = d.getVar('KERNEL_DEVICETREE', True)
    if has_devicetree:
        for dtb in d.getVar('KERNEL_DEVICETREE', True).split():
            #bootfiles.append(os.path.join(deploydir, kernel + "-" + dtb))
            bootfiles.append(os.path.join(deploydir, dtb))

    args = ['du', '-kLc']
    args.extend(bootfiles)
    output = subprocess.check_output(args)
    bootfssize_kb = int(output.splitlines()[-1].split()[0])

    bootpart_rawfiles = []

    has_spl = d.getVar('SPL_BINARY', True)
    if has_spl:
        bootpart_rawfiles.append(
              {
                "filename": d.getVar('SPL_BINARY', True),
                "dd_options": "seek=" + offset_bootrom
              })
    bootpart_rawfiles.append(
              {
                "filename": d.getVar('UBOOT_SECONDARY_HEADER', True),
                "dd_options": "seek=" + d.getVar('OFFSET_UBOOT_SECONDARY_HEADER', True)
              })
    bootpart_rawfiles.append(
              {
                "filename": d.getVar('UBOOT_BINARY_TEZI', True),
                "dd_options": "seek=" + (offset_spl if has_spl else offset_bootrom)
              })
    bootpart_rawfiles.append(
              {
                "filename": d.getVar('UBOOT_BINARY_TEZI', True),
                "dd_options": "seek=" + d.getVar('OFFSET_UBOOT_SECONDARY', True)
              })

    return [
        OrderedDict({
          "name": "mmcblk0",
          "table_type": "gpt",
          "partitions": [
            {
              "partition_size_nominal": 16,
              "want_maximised": False,
              "content": {
                "label": "BOOT",
                "filesystem_type": "FAT",
                "mkfs_options": "",
                "filename": imagename + ".bootfs.tar.xz",
                "uncompressed_size": bootfssize_kb / 1024
              }
            },
            {
              "partition_size_nominal": 512,
              "want_maximised": True,
              "content": {
                "label": "RFS",
                "filesystem_type": d.getVar('TEZI_ROOT_FSTYPE', True),
                "mkfs_options": "-E nodiscard",
                "filename": imagename + imagename_suffix + ".tar.xz",
                "uncompressed_size": rootfs_get_size(d) / 1024
              }
            },
            {
              "partition_size_nominal": 16,
              "want_maximised": False,
              "content": {
                "label": "BOOT",
                "filesystem_type": "FAT",
                "mkfs_options": ""
              }
            },
            {
              "partition_size_nominal": 512,
              "want_maximised": True,
              "content": {
                "label": "RFS",
                "filesystem_type": d.getVar('TEZI_ROOT_FSTYPE', True),
                "mkfs_options": "-E nodiscard"
              }
            },
            {
              "partition_size_nominal": 50,
              "want_maximised": False,
              "content": {
                "label": "PERSISTENT",
                "filename": d.getVar('PERSISTENT_IMAGE', True),
                "mkfs_options": "-E nodiscard",
                "filesystem_type": "ext4",
                "uncompressed_size": 5
              }
            },
            {
              "partition_size_nominal": 50,
              "want_maximised": False,
              "content": {
                "label": "PERSISTENT",
                "filename": d.getVar('PERSISTENT_IMAGE', True),
                "mkfs_options": "-E nodiscard",
                "filesystem_type": "ext4",
                "uncompressed_size": 5
              }
            }
          ]
        }),
        OrderedDict({
          "name": "mmcblk0boot0",
          "erase": "true",
          "content": {
            "filesystem_type": "raw",
            "rawfiles": bootpart_rawfiles
          }
        })]


def rootfs_tezi_rawnand(d):
    from collections import OrderedDict
    imagename = d.getVar('IMAGE_NAME', True)
    imagename_suffix = d.getVar('IMAGE_NAME_SUFFIX', True)

    # Use device tree mapping to create product id <-> device tree relationship
    dtmapping = d.getVarFlags('TORADEX_PRODUCT_IDS')
    dtfiles = []
    for f, v in dtmapping.items():
        dtfiles.append({ "filename": v, "product_ids": f })

    return [
        OrderedDict({
          "name": "u-boot1",
          "content": {
            "rawfile": {
              "filename": d.getVar('UBOOT_BINARY_TEZI', True),
              "size": 1
            }
          },
        }),
        OrderedDict({
          "name": "u-boot2",
          "content": {
            "rawfile": {
              "filename": d.getVar('UBOOT_BINARY_TEZI', True),
              "size": 1
            }
          }
        }),
        OrderedDict({
          "name": "u-boot-env",
          "erase": True,
          "content": {}
        }),
        OrderedDict({
          "name": "ubi",
          "ubivolumes": [
            {
              "name": "kernel",
              "size_kib": 8192,
              "type": "static",
              "content": {
                "rawfile": {
                  "filename": d.getVar('KERNEL_IMAGETYPE', True),
                  "size": 5
                }
              }
            },
            {
              "name": "dtb",
              "content": {
                "rawfiles": dtfiles
              },
              "size_kib": 128,
              "type": "static"
            },
            {
              "name": "m4firmware",
              "size_kib": 896,
              "type": "static"
            },
            {
              "name": "rootfs",
              "content": {
                "filesystem_type": "ubifs",
                "filename": imagename + imagename_suffix + ".tar.xz",
                "uncompressed_size": rootfs_get_size(d) / 1024
              }
            }
          ]
        })]

python rootfs_tezi_json() {
    import json
    from collections import OrderedDict
    from datetime import datetime

    deploydir = d.getVar('DEPLOY_DIR_IMAGE', True)
    # patched in IMAGE_CMD_teziimg() below
    release_date = "%release_date%"

    data = OrderedDict({ "config_format": 2, "autoinstall": True })

    # Use image recipes SUMMARY/DESCRIPTION/PV...
    data["name"] = d.getVar('SUMMARY', True)
    data["description"] = d.getVar('DESCRIPTION', True)
    data["version"] = d.getVar('PV', True)
    data["release_date"] = release_date
    if os.path.exists(os.path.join(deploydir, "prepare.sh")):
        data["prepare_script"] = "prepare.sh"
    if os.path.exists(os.path.join(deploydir, "wrapup.sh")):
        data["wrapup_script"] = "wrapup.sh"
    if os.path.exists(os.path.join(deploydir, "marketing.tar")):
        data["marketing"] = "marketing.tar"
    if os.path.exists(os.path.join(deploydir, "toradexlinux.png")):
        data["icon"] = "toradexlinux.png"
    if os.path.exists(os.path.join(deploydir, "u-boot-secondary-header")):
        data["uboot_secondary_header"] = "u-boot-secondary-header"

    product_ids = d.getVar('TORADEX_PRODUCT_IDS', True)
    if product_ids is None:
        bb.fatal("Supported Toradex product ids missing, assign TORADEX_PRODUCT_IDS with a list of product ids.")

    data["supported_product_ids"] = d.getVar('TORADEX_PRODUCT_IDS', True).split()

    if bb.utils.contains("TORADEX_FLASH_TYPE", "rawnand", True, False, d):
        data["mtddevs"] = rootfs_tezi_rawnand(d)
    else:
        data["blockdevs"] = rootfs_tezi_emmc(d)

    deploy_dir = d.getVar('DEPLOY_DIR_IMAGE', True)
    with open(os.path.join(deploy_dir, 'image.json'), 'w') as outfile:
        json.dump(data, outfile, indent=4)
    bb.note("Toradex Easy Installer metadata file image.json written.")
}

do_image_teziimg[prefuncs] += "rootfs_tezi_json"



python get_latest_rootfs_tarball () {
  import os
  import re
  imagedeploydir = d.getVar('IMGDEPLOYDIR', True)
  image_name = d.getVar('IMAGE_NAME', True)
  files = os.listdir(imagedeploydir)
  rootfs_files = []

  for f in files:
    if f.endswith(".rootfs.tar.xz"):
      rootfs_files.append(os.path.join(imagedeploydir,f))

  lrf = max(rootfs_files, key=os.path.getctime)
  lrf_raw = lrf.replace(".rootfs.tar.xz", '')

  lrf_basename = os.path.basename(lrf_raw)

  if lrf_basename != image_name:
    print("WARNING: latest roots tarball ({}) is different then expected ({}). That incosistency might occur during development process when there were some errors during do_image_tezi task. Making a clean bould should help.\n". format(lrf_basename,image_name))

  # In some situations when there was some errors during do_image_tezi buildsystem generates IMAGE_NAME with current date
  # Unforunately there is no new rootfs tarbale created and build fails due to nonexisting file with new IMAGE_NAME.
  # To avoid that situation during build we look for newest existing rootfs and provide its name as LATEST_IMAGE_NAME
  # During clean build or when there was no previous errors LATEST_IMAGE_NAME is the same as IMAGE_NAME.
  # Populated LATEST_IMAGE_NAME is usued in do_image_teziimg and in generate_swu_image steps.
  d.setVar('LATEST_IMAGE_NAME', os.path.basename(lrf_raw))

}

do_image_teziimg[prefuncs] += "get_latest_rootfs_tarball"

IMAGE_CMD_teziimg () {
	bbnote "Create bootfs tarball"

	# Fixup release_date in image.json, convert ${TDX_VERDATE} to isoformat
	# This works around the non fatal ERRORS: "the basehash value changed" when DATE is referenced
	# in a python prefunction to do_image
	ISODATE=`echo ${TDX_VERDATE} | sed 's/.\(....\)\(..\)\(..\).*/\1-\2-\3/'`
	sed -i "s/%release_date%/$ISODATE/" ${DEPLOY_DIR_IMAGE}/image.json

	# Create list of device tree files
	if test -n "${KERNEL_DEVICETREE}"; then
		for DTS_FILE in ${KERNEL_DEVICETREE}; do
			DTS_BASE_NAME=`basename ${DTS_FILE} .dtb`
			if [ -e "${DEPLOY_DIR_IMAGE}/${DTS_BASE_NAME}.dtb" ]; then
				KERNEL_DEVICETREE_FILES="${KERNEL_DEVICETREE_FILES} ${DTS_BASE_NAME}.dtb"
			else
				bbfatal "${DTS_FILE} does not exist."
			fi
		done
	fi

	cd ${DEPLOY_DIR_IMAGE}

	case "${TORADEX_FLASH_TYPE}" in
		rawnand)
		# The first transform strips all folders from the files to tar, the
		# second transform "moves" them in a subfolder ${IMAGE_NAME}_${PV}.
		# The third transform removes zImage from the device tree.
		${IMAGE_CMD_TAR} --transform='s/.*\///' --transform 's,^,${IMAGE_NAME}-Tezi_${PV}/,' --transform="flags=r;s|${KERNEL_IMAGETYPE}-||" -chf ${IMGDEPLOYDIR}/${IMAGE_NAME}-Tezi_${PV}${TDX_VERDATE}.tar image.json toradexlinux.png marketing.tar prepare.sh wrapup.sh ${SPL_BINARY} ${UBOOT_BINARY_TEZI} ${KERNEL_IMAGETYPE} ${KERNEL_DEVICETREE_FILES} ${IMGDEPLOYDIR}/${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.tar.xz
		;;
		*)
		# Create bootfs...
		${IMAGE_CMD_TAR} --transform="flags=r;s|${KERNEL_IMAGETYPE}-||" -chf ${IMGDEPLOYDIR}/${IMAGE_NAME}.bootfs.tar -C ${DEPLOY_DIR_IMAGE} ${KERNEL_IMAGETYPE} ${KERNEL_DEVICETREE_FILES}
		xz -f -k -c ${XZ_COMPRESSION_LEVEL} ${XZ_THREADS} --check=${XZ_INTEGRITY_CHECK} ${IMGDEPLOYDIR}/${IMAGE_NAME}.bootfs.tar > ${IMGDEPLOYDIR}/${IMAGE_NAME}.bootfs.tar.xz

		# The first transform strips all folders from the files to tar, the
		# second transform "moves" them in a subfolder ${IMAGE_NAME}-Tezi_${PV}.
		${IMAGE_CMD_TAR} --transform='s/.*\///' --transform 's,^,${IMAGE_NAME}-Tezi_${PV}/,' -chf ${IMGDEPLOYDIR}/${IMAGE_NAME}-Tezi_${PV}${TDX_VERDATE}.tar image.json toradexlinux.png marketing.tar prepare.sh wrapup.sh ${SPL_BINARY} ${UBOOT_BINARY_TEZI} ${UBOOT_SECONDARY_HEADER} ${PERSISTENT_IMAGE} ${IMGDEPLOYDIR}/${IMAGE_NAME}.bootfs.tar.xz ${IMGDEPLOYDIR}/${LATEST_IMAGE_NAME}.rootfs.tar.xz
		;;
	esac
}

IMAGE_TYPEDEP_teziimg += "tar.xz"
