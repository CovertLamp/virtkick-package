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

if which firewall-cmd > /dev/null && firewall-cmd --state > /dev/null; then
  echo "Opening port 3000 on zone public"
  firewall-cmd --zone=public --add-port=3000/tcp --permanent
  firewall-cmd --reload
fi

for service in proxy webapp backend; do
  systemctl enable virtkick-$service
  systemctl start virtkick-$service
done

for n in 1 2; do
  systemctl enable virtkick-work@$n
  systemctl start virtkick-work@$n
done

