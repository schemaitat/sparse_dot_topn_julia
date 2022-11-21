#!/bin/bash
set -xe

NODE_IP=$1
INITIAL_SETUP=$2
REMOTE_USER=root
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ "${INITIAL_SETUP:-x}" != "x" ]; then 
    ssh-copy-id root@$NODE_IP
fi

# rsync this folder to remote machine
rsync -a --progress --exclude data/*.csv $SCRIPT_PATH $REMOTE_USER@$NODE_IP:/root
# unzip archive file

REMOTE_DIR=/root/$(basename $SCRIPT_PATH)

ssh $REMOTE_USER@$NODE_IP "/bin/bash $REMOTE_DIR/setup_julia.sh"
# small test
ssh $REMOTE_USER@$NODE_IP "/bin/bash $REMOTE_DIR/benchmark.sh 100000 10000 500 0.25" | tee $SCRIPT_PATH/.log_small
# real test
ssh $REMOTE_USER@$NODE_IP "/bin/bash $REMOTE_DIR/benchmark.sh 2500000 150000 500 0. 2500000 150000 500 0.5" | tee $SCRIPT_PATH/.log_big
scp $REMOTE_USER@$NODE_IP:$REMOTE_DIR/.log $SCRIPT_PATH/.log_big_scp