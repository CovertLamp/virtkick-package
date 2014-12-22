#!/bin/bash
systemctl daemon-reload
for service in proxy webapp backend; do
  systemctl try-restart virtkick-$service
done

for n in 1 2; do
  systemctl try-restart virtkick-work@$n
done

