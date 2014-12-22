VERSION=0.3
ITERATION=4

COMPRESSION=gz
if [ "$1" != "" ];then
    COMPRESSION="$1"
fi

function generate_rpm {
    SUFFIX="$1"
    if [ "$COMPRESSION" == "gz" ];then
	COMPRESSION_RPM="gzip"
    else
	COMPRESSION_RPM="$COMPRESSION"
    fi
    shift
    fpm --workdir `pwd`/tmp --rpm-compression=$COMPRESSION_RPM -s dir -t rpm \
    "$@" -n "virtkick" -v "$VERSION" \
    --iteration "$ITERATION" \
    -p "virtkick-VERSION-ITERATION${SUFFIX}_ARCH.rpm" \
    -m "Damian Kaczmarek <rush@virtkick.io>" \
    --after-install scripts/rpm/after_install.sh \
    --before-remove scripts/rpm/before_remove.sh \
    -C root_package \
    opt usr
}

function generate_deb {
    SUFFIX="$1"
    shift
    fpm --workdir `pwd`/tmp --deb-compression=$COMPRESSION -s dir -t deb \
    "$@" -n "virtkick" -v "$VERSION" \
    --iteration "$ITERATION" \
    -p "virtkick-VERSION-ITERATION${SUFFIX}_ARCH.deb" \
    -m "Damian Kaczmarek <rush@virtkick.io>" \
    --after-install scripts/rpm/after_install.sh \
    --before-remove scripts/rpm/before_remove.sh \
    -C root_package \
    opt usr
}

generate_rpm "" -d 'bash' -d 'openssh' -d 'libvirt > 1.1' -d 'libvirt-python > 1.1' -d 'python > 2.7' -d 'libxml2-python > 2.7' -d 'qemu-kvm > 1.2'
generate_deb "" -d 'bash' -d 'openssh-server' -d 'libvirt-bin > 1.1' -d 'libvirt-python > 1.1' -d 'python > 2.7' -d 'python-libxml2 > 2.7' -d 'qemu-kvm > 1.2'
