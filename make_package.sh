VERSION=`git describe --tags`

[ -z "$COMPRESSION" ] && COMPRESSION='gz'

if [ -z "$1" ]; then
  echo "Iteration set to 0. Use \`$0 123\` to set the iteration number."
  ITERATION='0'
else
  ITERATION="$1"
fi


function generate_rpm {
  SUFFIX="$1"
  if [ "$COMPRESSION" == "gz" ]; then
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

generate_rpm '' \
    -d 'bash' \
    -d 'openssh' \
    -d 'qemu-kvm > 1.2' \
    -d 'libvirt > 1.1' \
    -d 'libvirt-python > 1.1' \
    -d 'python > 2.7' \
    -d 'libxml2-python > 2.7'

generate_deb ''  \
    -d 'bash' \
    -d 'openssh-server' \
    -d 'qemu-kvm > 1.2'
    -d 'libvirt-bin > 1.1' \
    -d 'libvirt-python > 1.1' \
    -d 'python > 2.7' \
    -d 'python-libxml2 > 2.7'
