#!/bin/bash
# Huaicheng Li <huaicheng@cs.uchicago.edu>
# Run FEMU as a black-box SSD (FTL managed by the device)

# image directory
IMGDIR=/home/shyoon/images
# Virtual machine disk image
OSIMGF=$IMGDIR/u20s.qcow2
echo "OSIMG = $OSIMGF"
# Configurable SSD Controller layout parameters (must be power of 2)
secsz=512 # sector size in bytes
secs_per_pg=8 # number of sectors in a flash page
blks_per_pl=256 # number of blocks per plane
pls_per_lun=1 # keep it at one, no multiplanes support
luns_per_ch=8 # number of chips per channel
nchs=8 # number of channels
blks_per_pl=512 # number of blocks per plane

# Latency in nanoseconds
ch_xfer_lat=0 # channel transfer time, ignored for now

# GC Threshold (1-100)
gc_thres_pcent=75
gc_thres_pcent_high=95

#-----------------------------------------------------------------------

#Compose the entire FEMU BBSSD command line options
FEMU_OPTION_COMMON="-device femu"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",namespaces=1"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",femu_mode=1"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",secsz=${secsz}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",secs_per_pg=${secs_per_pg}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",blks_per_pl=${blks_per_pl}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",pls_per_lun=${pls_per_lun}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",luns_per_ch=${luns_per_ch}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",nchs=${nchs}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",ch_xfer_lat=${ch_xfer_lat}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",gc_thres_pcent=${gc_thres_pcent}"
FEMU_OPTION_COMMON=${FEMU_OPTION_COMMON}",gc_thres_pcent_high=${gc_thres_pcent_high}"

# Latency in nanoseconds (SLC)
# value from Analysis on Heterogeneous SSD ... paper
pg_rd_lat_slc=30000 # page read latency
pg_wr_lat_slc=160000 # page write latency
blk_er_lat_slc=3000000 # block erase latency
pgs_per_blk_slc=256 # number of pages per flash block
ssd_size_slc=24576 # in megabytes, if you change the above layout parameters, make sure you manually recalculate the ssd size and modify it here, please consider a default 25% overprovisioning ratio.

FEMU_OPTION_SLC=${FEMU_OPTION_COMMON}",devsz_mb=${ssd_size_slc}"
FEMU_OPTION_SLC=${FEMU_OPTION_SLC}",pgs_per_blk=${pgs_per_blk_slc}"
FEMU_OPTION_SLC=${FEMU_OPTION_SLC}",pg_rd_lat=${pg_rd_lat_slc}"
FEMU_OPTION_SLC=${FEMU_OPTION_SLC}",pg_wr_lat=${pg_wr_lat_slc}"
FEMU_OPTION_SLC=${FEMU_OPTION_SLC}",blk_er_lat=${blk_er_lat_slc}"

# Latency in nanoseconds (QLC)
pg_rd_lat_qlc=140000 # page read latency
pg_wr_lat_qlc=3102500 # page write latency
blk_er_lat_qlc=350000000 # block erase latency
pgs_per_blk_qlc=1024 # number of pages per flash block
ssd_size_qlc=98304 # in megabytes, if you change the above layout parameters, make sure you manually recalculate the ssd size and modify it here, please consider a default 25% overprovisioning ratio.

FEMU_OPTION_QLC=${FEMU_OPTION_COMMON}",devsz_mb=${ssd_size_qlc}"
FEMU_OPTION_QLC=${FEMU_OPTION_QLC}",pgs_per_blk=${pgs_per_blk_qlc}"
FEMU_OPTION_QLC=${FEMU_OPTION_QLC}",pg_rd_lat=${pg_rd_lat_qlc}"
FEMU_OPTION_QLC=${FEMU_OPTION_QLC}",pg_wr_lat=${pg_wr_lat_qlc}"
FEMU_OPTION_QLC=${FEMU_OPTION_QLC}",blk_er_lat=${blk_er_lat_qlc}"


echo ${FEMU_OPTION_SLC}
echo ${FEMU_OPTION_QLC}

if [[ ! -e "$OSIMGF" ]]; then
	echo ""
	echo "VM disk image couldn't be found ..."
	echo "Please prepare a usable VM image and place it as $OSIMGF"
	echo "Once VM disk image is ready, please rerun this script again"
	echo ""
	exit
fi

sudo ./qemu-system-x86_64 \
    -name "FEMU-BBSSD-VM" \
    -enable-kvm \
    -cpu host \
    -smp 24 \
    -m 64G \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    ${FEMU_OPTION_SLC} \
    ${FEMU_OPTION_SLC} \
    ${FEMU_OPTION_SLC} \
    ${FEMU_OPTION_SLC} \
    ${FEMU_OPTION_QLC} \
    ${FEMU_OPTION_QLC} \
    ${FEMU_OPTION_QLC} \
    ${FEMU_OPTION_QLC} \
    -net user,hostfwd=tcp::8080-:22 \
    -net nic,model=virtio \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log
