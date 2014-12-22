#!/bin/sh
set -e
BASE_DIR="$(readlink -f "$(dirname "$0")")"
echo "$BASE_DIR"
cd "$BASE_DIR"

if [ -e root_package ];then
    echo "Removing already existing root_package, will create new one"
    rm -rf root_package
fi

cd webapp
DIR_ONLY=1 rake package
cd ..
mkdir -p output
rm -rf output/webapp
mv webapp/virtkick-webapp-linux-x86_64 output/webapp
cp -r backend output
rm -rf output/backend/.git

cd output/backend
python2 manage.py collectstatic --noinput
cd "$BASE_DIR"


mkdir -p output
cp -r template/* output
export NVM_DIR="$BASE_DIR/output/src/.nvm"
if ! [ -e "$NVM_DIR" ];then
    ( git clone https://github.com/creationix/nvm.git "$NVM_DIR" && cd "$NVM_DIR" && git checkout `git describe --abbrev=0 --tags` && rm -rf .git )
    . "$NVM_DIR/nvm.sh"
    nvm install 0.11
    rm -rf "$NVM_DIR/test"
else
    . "$NVM_DIR/nvm.sh"
fi
nvm use 0.11
cd "$BASE_DIR/output/src"
npm install
wsdir="$(find . -name ws -type d)"
unzip -q "$BASE_DIR/assets/ws.zip"
rm -rf "$wsdir"
mv ws "$wsdir"
cd "$BASE_DIR/output/bin"
if ! [ -e aria2c ];then
    echo "Downloading aria2c from https://github.com/coreb1te/aria2-builds-for-linux"
    wget -O- "https://github.com/coreb1te/aria2-builds-for-linux/blob/master/builds/aria2c-linux-x86_64.tar.xz?raw=true" | tar -Jx
    strip aria2c
fi
cd "$BASE_DIR"
mkdir -p root_package/opt root_package/usr/lib/systemd/system
mv output root_package/opt/virtkick
cp services/* root_package/usr/lib/systemd/system
