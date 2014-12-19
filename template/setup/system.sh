#!/bin/sh
set -e

function mysudo() {
    ASUSER="$1"
    shift
    echo "Run command($ASUSER)" "$@" 1>&2
    if [ "$(whoami)" == "$ASUSER" ];then
        "$@"
    else
        sudo -u "$ASUSER" "$@"
    fi
}

export VIRTKICK_RUN_USER=${VIRTKICK_RUN_USER:-$(whoami)}
export VIRTKICK_RUN_USER_HOME="$(bash -c "echo $(echo ~$VIRTKICK_RUN_USER)")" #"

if ! [ -e .system-setup ];then

  if which systemctl &> /dev/null;then
    mysudo root systemctl enable libvirtd
    mysudo root systemctl start libvirtd
  fi
  
  # rules for CentOS
  if [ -d /etc/polkit-1/localauthority/50-local.d ] && [ ! -e /etc/polkit-1/localauthority/50-local.d/50-libvirt-virtkick.pkla ];then
    echo '[Remote libvirt SSH access for virtkick]
Identity=unix-user:virtkick
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes
' | mysudo root tee /etc/polkit-1/localauthority/50-local.d/50-libvirt-virtkick.pkla > /dev/null
  fi


  if [ -d /etc/polkit-1/rules.d ] && mysudo root [ ! -e /etc/polkit-1/rules.d/50-io.virtkick.libvirt.unix.manage.rules ];then
    echo 'polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" &&
    subject.user == "virtkick") {
    return polkit.Result.YES;
  }
});
' | mysudo root tee /etc/polkit-1/rules.d/50-io.virtkick.libvirt.unix.manage.rules > /dev/null
  fi

  if ! [ -e $VIRTKICK_RUN_USER_HOME/.ssh/id_rsa_virtkick ];then
    mysudo $VIRTKICK_RUN_USER  mkdir -p $VIRTKICK_RUN_USER_HOME/.ssh
    mysudo $VIRTKICK_RUN_USER ssh-keygen -q -N "" -f $VIRTKICK_RUN_USER_HOME/.ssh/id_rsa_virtkick
    mysudo $VIRTKICK_RUN_USER echo '
Host localhost
  User virtkick
  IdentityFile ~/.ssh/id_rsa_virtkick
  StrictHostKeyChecking no
    ' >> $VIRTKICK_RUN_USER_HOME/.ssh/config
  fi
  echo 'I am about to create user "virtkick" in group "kvm" and add your public ssh key to allow passwordless login'

  # this makes no attempt to decide which port to use if multiple ports specified. so pick the first one.
  export SSH_PORT=$(sudo grep -oE "^\s*Port\s+[0-9]+" /etc/ssh/sshd_config|grep -oE "[0-9]+"|head -n 1)
  if [ "$SSH_PORT" == "" ];then
    export SSH_PORT="22"
  fi
  echo $SSH_PORT > .ssh-port

  mysudo root bash -c '
  if ! [ -e /var/run/libvirt/libvirt-sock ];then
    echo "Cannot find /var/run/libvirt/libvirt-sock, please install libvirt and enable libvirtd" && exit 1
  fi;
  export LIBVIRT_GROUP=$(stat -c "%G" /var/run/libvirt/libvirt-sock)
  if [ "$LIBVIRT_GROUP" != \"root\" ];then
    export ADD_LIBVIRT="-G $LIBVIRT_GROUP"
  fi && 
  if ! getent group kvm > /dev/null; then 
    echo "It seems KVM is not installed, no group kvm?" && exit 1
  fi &&
  if ! getent passwd virtkick > /dev/null; then 
    useradd virtkick -m -c "VirtKick orchestrator" -s /bin/bash -g kvm $ADD_LIBVIRT
  fi && 
  echo "virtkick:*" | chpasswd -e &&
  mkdir -p ~virtkick/{.ssh,hdd,iso} &&
  chown -R virtkick:kvm ~virtkick &&
  chmod 750 ~virtkick &&
  cat > ~virtkick/.ssh/authorized_keys' < $VIRTKICK_RUN_USER_HOME/.ssh/id_rsa_virtkick.pub
  if ! mysudo $VIRTKICK_RUN_USER ssh -p $SSH_PORT -o "StrictHostKeyChecking no" virtkick@localhost virsh list > /dev/null;then
    echo 'Cannot run "virsh list" on virtkick@localhost, libvirt is not setup properly!'
    echo 'virtkick user needs rights to read/write /var/run/libvirt/libvirt-sock'
    exit 1
  fi
  mysudo $VIRTKICK_RUN_USER ssh -p $SSH_PORT -o "StrictHostKeyChecking no" virtkick@localhost 'mkdir -p ~/bin && cat > ~/bin/aria2c && chmod +x ~/bin/aria2c' < bin/aria2c
  touch .system-setup
else
  export SSH_PORT="$(cat .ssh-port 2> /dev/null || echo 22)"
fi
