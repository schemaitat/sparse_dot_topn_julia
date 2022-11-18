#%%
using StringAnalysis
using Unicode
using CSV
using DataFrames
using SparseArrays
using StatsBase
using SparseMatricesCSR
#%%

#%%
"""
    Create a map ["aaa","aab",...,"zzz"] -> [0,1,...,26^3-1]
"""
function get_ranks()
    chars = 'a':'z'
    ranks = Dict()
    for (i, ci) in enumerate(chars)
        for (j, cj) in enumerate(chars)
            for (k, ck) in enumerate(chars)
                ranks[ci*cj*ck]=26^2*i+26*j+k
            end
        end
    end
    return ranks
end

function normalize_word(word::String)
    # strip accents and normalize
    word = Unicode.normalize(word, casefold = true, stripmark = true)
    # keep only a-z
    word = replace(word, !(c -> 'a' <= c <= 'z') => "")
    return word
end

normalize_word(word::Missing) = normalize_word("")

function n_grams(word::String, n::Int = 3)
    if length(word) <= 3
        return [word]
    end
    # ind = collect(eachindex(word))
    # n_grams = [word[ind[i]:ind[i+2]] for i in 1:length(ind)-2]
    # we only work with a-z strings
    n_grams = [word[i:i+(n-1)] for i in 1:length(word)-(n-1)]
    return n_grams
end

function fit_transform(data, transpose = false)
    ranks = get_ranks()
    m = length(data)
    n = maximum(values(ranks))

    I=Int[]
    J=Int[]
    V=Float32[]

    for (i, row) in enumerate(data)
        word = normalize_word(row.name)
        values = Int[]
        for ng in n_grams(word)
            if length(ng) == 3
                # meaning that ng is a valid key
                push!(values, ranks[ng])
            end
        end
        # remove duplicate values for column indices
        # if we want to count, we would need to add up all
        # values for each {j : j in values}
        values = unique(values)
        nz = length(values)
        # append!(ap, ap[i]+nz)
        append!(I, ones(nz)*i)
        append!(J, values)
        append!(V, ones(nz) / sqrt(nz))
    end
    # sparsecsr constructs from csc parameters
    if transpose
        return sparsecsr(J,I,V,n,m)
    else
        return sparsecsr(I, J, V, m, n)
    end
end

function sparse_dot_topn(A::SparseMatrixCSR, B::SparseMatrixCSR, ntop::Int, θ::Float64)
    (ap, aj, ax, am, an) = (A.rowptr, A.colval, A.nzval, A.m, A.n)
    (bp, bj, bx, bm, bn) = (B.rowptr, B.colval, B.nzval, B.m, B.n)
    @assert an == bm "Dimensions mismatch. A.cols = $(an) != B.nrows = $(bm)"

    candidates = []
    (cp, cj, cx, cm, cn) = (Int[1], Int[], Float32[], am, bn)

    for i in 1:am
        sums = zeros(Float32, bn)
        jj_start = ap[i]
        jj_end = ap[i+1]-1

        for jj in jj_start:jj_end
            j = aj[jj]
            v = ax[jj]

            kk_start = bp[j]
            kk_end = bp[j+1]-1

            for kk in kk_start:kk_end
                k = bj[kk]
                sums[k] = sums[k] + (v * bx[kk])
            end
        end

        for l in eachindex(sums)
            if sums[l] >= θ
                push!(candidates, (l,sums[l]))
            end
        end
        
        # zero fill sums
        # sums = zeros(bn)
        if length(candidates) > ntop
            partialsort!(candidates, ntop, by = (x -> x[2]), rev = true)
        end

        nnz = min(length(candidates), ntop)
        for l in 1:nnz
            append!(cj, candidates[l][1])
            append!(cx, candidates[l][2])
        end

        candidates = []

        append!(cp,cp[end] + nnz)
    end

    return (cp, cj, cx)
end

#%%

#%%
n_right = 2000000
n_left = 100000
ntop = 10
θ = 0.25

println("Read data ...")
@time data = CSV.File("./companies_sorted.csv", select = ["name"], normalizenames = true, types = String, limit = n_right);
println("Fit and transform data ...")
@time right = fit_transform(data, true);
println("Fit and transform sample ...")
left = fit_transform(first(data, n_left))
println("Compute single threaded sparse topn product ...")
# @time prod = sparse_dot_topn(left, right, ntop, θ);


# threaded product
n_threads = Threads.nthreads()
batch_size = div(n_left ,n_threads)
batches_csr = []
# insead of slicing the csr matrix, we slice the data and fit_transform
for i in 0:n_threads-1
    push!(batches_csr, fit_transform(data[i*batch_size+1:(i+1)*batch_size]))
end

prods = []
println("Computing with $(n_threads) threads, batch_size = $(batch_size).")
@time Threads.@threads for i in 1:n_threads
    prod = sparse_dot_topn(batches_csr[i], right, ntop, θ)
    push!(prods, prod)
end
println("Display ntop matrix:")
println()
#%%

#%%
(ip, ij, ix) = prod
chars = 0
rows = []
max_rows = 10
for i in 1:min(length(ip), max_rows)-1
    row = ""
    row *= "$(i)|"
    jj_start = ip[i]
    jj_end = ip[i+1]-1
    for jj in jj_start:jj_end
        j = ij[jj]
        x = ix[jj]
        x = round(x, digits = 2)
        row *= " ($(j),$(x)) "
    end
    push!(rows, row)
end

max_len = maximum([length(r) for r in rows])
println("-" ^ (max_len + 2))

for row in rows
    padding = max_len - length(row)
    row *= " " ^ padding
    println("|" * row *  "|")
    println("-" ^ (max_len + 2))
end
#%%
