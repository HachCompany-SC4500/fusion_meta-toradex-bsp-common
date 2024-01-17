#!/usr/bin/env bash
#
# Copyright (C) 2019 Witekio
# Author: Dragan Cecavac <dcecavac@witekio.com>
#
# Usage:
#       ./generate-u-boot-secondary-header.sh secondary-bootloader-start-block
#
#		Secondary bootloader image table format
#
#		Address		Description				Value
#		0x200		reserved Chip Num		0
#		0x204		reserved Drive Type		0
#		0x208		tag						0x00112233
#		0x20C		first sector number		<script-argument>
#		0x210		reserved Sector Count	0
#
#		Script will insert the provided argument at the address range 0x20C-0x20F.
#		Other memory locations in the specified range will be filled with the default values.
#

if [ "$#" -ne 1 ]; then
	echo "Incorrect argument number"
	echo "Usage: ./generate-u-boot-secondary-header.sh secondary-bootloader-start-block"
	exit 1
fi

prefix='\x00\x00\x00\x00\x00\x00\x00\x00\x33\x22\x11\x00'

sector_number_byte_1="$(( $1 & 0xff ))"
sector_number_byte_1=`printf "%x" $sector_number_byte_1`

sector_number_byte_2="$(( ( $1 >> 8 ) & 0xff ))"
sector_number_byte_2=`printf "%x" $sector_number_byte_2`

sector_number_byte_3="$(( ( $1 >> 16 ) & 0xff ))"
sector_number_byte_3=`printf "%x" $sector_number_byte_3`

sector_number_byte_4="$(( ( $1 >> 32 ) & 0xff ))"
sector_number_byte_4=`printf "%x" $sector_number_byte_4`

suffix='\x00\x00\x00\x00'

echo -n -e "${prefix}" > u-boot-secondary-header
echo -n -e "\x${sector_number_byte_1}" >> u-boot-secondary-header
echo -n -e "\x${sector_number_byte_2}" >> u-boot-secondary-header
echo -n -e "\x${sector_number_byte_3}" >> u-boot-secondary-header
echo -n -e "\x${sector_number_byte_4}" >> u-boot-secondary-header
echo -n -e "${suffix}" >> u-boot-secondary-header
