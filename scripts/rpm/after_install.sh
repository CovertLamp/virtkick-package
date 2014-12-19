#!/bin/bash
set -e
echo "Setting up VirtKick"
cd /opt/virtkick
if ! getent passwd virtkick-run > /dev/null; then
  useradd virtkick-run -c "VirtKick running account" -s /bin/bash -m $ADD_LIBVIRT -d /var/lib/virtkick-run
  chown -R virtkick-run /var/lib/virtkick-run # CentOS does not create a user dir with proper ownership (why?)
  chmod 700 /var/lib/virtkick-run # .. and without proper rights
fi
export VIRTKICK_RUN_USER='virtkick-run'
export VIRTKICK_RUN_USER_HOME='/var/lib/virtkick-run'
systemctl start sshd
systemctl enable sshd
. setup/system.sh
chown -R virtkick-run:root /opt/virtkick

