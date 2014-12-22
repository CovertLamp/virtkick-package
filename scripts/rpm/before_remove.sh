#!/bin/bash
if which firewall-cmd > /dev/null && firewall-cmd --state > /dev/null; then
  echo "Closing port 3000 on zone public"
  firewall-cmd --zone=public --remove-port=3000/tcp --permanent
  firewall-cmd --reload
fi

for service in proxy webapp backend; do
  systemctl disable virtkick-$service
  systemctl stop virtkick-$service
done

for n in 1 2; do
  systemctl disable virtkick-work@$n
  systemctl stop virtkick-work@$n
done

