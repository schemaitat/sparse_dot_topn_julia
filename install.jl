using Pkg

packages = ["StringAnalysis", "Unicode", "CSV", 
    "DataFrames", "SparseArrays", "StatsBase", "SparseMatricesCSR"]

for p in packages
    Pkg.add(p)
end

Pkg.precompile()