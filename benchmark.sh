#!/bin/bash
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
RIGHT=$1
LEFT=$2
NTOP=$3
THETA=$4
LOG_FILE=$SCRIPT_PATH/.log

which julia
if [ $? -ne 0 ]; then
    export PATH=${PATH}:${HOME}/julia-1.8.1/bin
fi

echo "$(date)" > $LOG_FILE
threads=(1 2 4 8 16)
for t in ${threads[@]}; do
    echo "Benchmarking with $t threads ..." | tee $LOG_FILE
    julia -t $t ${SCRIPT_PATH}/NameSim.jl "${SCRIPT_PATH}/data" $RIGHT $LEFT $NTOP $THETA | tee  $LOG_FILE
    echo "END" | tee $LOG_FILE
done