VERSION=0.3
ITERATION=4

function generate_rpm {
    SUFFIX="$1"
    shift
    fpm --workdir `pwd`/tmp --rpm-compression=xz -s dir -t rpm \
    "$@" -n "virtkick" -v "$VERSION" \
    --iteration "$ITERATION" \
    -p "virtkick-VERSION-ITERATION${SUFFIX}_ARCH.rpm" \
    -m "Damian Kaczmarek <rush@virtkick.io>" \
    --after-install scripts/rpm/after_install.sh \
    opt 
}

function generate_deb {
    SUFFIX="$1"
    shift
    fpm --workdir `pwd`/tmp --deb-compression=bzip2 -s dir -t deb \
    "$@" -n "virtkick" -v "$VERSION" \
    --iteration "$ITERATION" \
    -p "virtkick-VERSION-ITERATION${SUFFIX}_ARCH.deb" \
    -m "Damian Kaczmarek <rush@virtkick.io>" \
    --after-install scripts/rpm/after_install.sh \
    opt 
}

generate_rpm "" -d 'bash' -d 'openssh' -d 'libvirt > 1.1' -d 'libvirt-python > 1.1' -d 'python > 2.7' -d 'libxml2-python > 2.7' -d 'qemu-kvm > 1.2'
generate_deb "" -d 'bash' -d 'openssh-server' -d 'libvirt-bin > 1.1' -d 'libvirt-python > 1.1' -d 'python > 2.7' -d 'python-libxml2 > 2.7' -d 'qemu-kvm > 1.2'
