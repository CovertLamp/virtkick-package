#needs BASE_DIR set
set -e
export BASE_DIR="$(pwd)"
export NVM_DIR="$BASE_DIR/src/.nvm"
export PATH="$BASE_DIR/bin:$PATH"
. "$NVM_DIR/nvm.sh"
nvm use 0.11 > /dev/null
