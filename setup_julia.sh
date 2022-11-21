#!/bin/bash
# remote install script
set -x

export SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export PATH=${PATH}:${HOME}/julia-1.8.1/bin

which julia
if [ $? -ne 0 ]; then
    cd $HOME
    apt-get update && apt-get install -y wget unzip
    wget https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.1-linux-x86_64.tar.gz
    tar zxvf julia-1.8.1-linux-x86_64.tar.gz
    echo 'export PATH=${PATH}:${HOME}/julia-1.8.1/bin' >> ~/.bashrc
fi

cd $SCRIPT_PATH/data
unzip -o $SCRIPT_PATH/data/archive.zip
ls -alh $SCRIPT_PATH/data

cat << EOF | julia
using Pkg

packages = ["StringAnalysis", "Unicode", "CSV",
    "DataFrames", "SparseArrays", "StatsBase", "SparseMatricesCSR"]

for p in packages
    Pkg.add(p)
end

Pkg.precompile()
EOF

