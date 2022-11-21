using CSV
using SparseMatricesCSR
include("Helper.jl")
include("SparseDotTopN.jl")
include("Vectorizer.jl")

if length(ARGS) == 0
    # if not run from terminal
    # or in interactive mode for testing
    n_right = 10000
    n_left = 1000
    ntop = 20
    θ = 0.25
    data_path="./data"
else
    # if run from terminal
    data_path=ARGS[1]
    n_right = parse(Int, ARGS[2])
    n_left=parse(Int, ARGS[3])
    ntop=parse(Int, ARGS[4])
    θ=parse(Float64, ARGS[5])
end


println("Read data ...")
@time data = CSV.File("$(data_path)/companies_sorted.csv", select = ["name"], normalizenames = true, types = String, limit = n_right);
println("Fit and transform data ...")
@time right = fit_transform(data, true);
println("Fit and transform sample ...")
left = fit_transform(first(data, n_left));

@time slices = sparse_dot_topn(left, right, ntop, θ, Threads.nthreads());
res = vcat_csr(slices)
