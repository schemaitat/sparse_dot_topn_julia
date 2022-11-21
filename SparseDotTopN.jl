function print_ntop_matrix(A::SparseMatrixCSR, max_rows::Int = 10)
    (ip, ij, ix) = (A.rowptr, A.colval, A.nzval)
    chars = 0
    rows = []
    for i in 1:min(length(ip)-1, max_rows)
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
end

function sparse_dot_topn(A::SparseMatrixCSR, B::SparseMatrixCSR, ntop::Int, θ::Float64)
    (ap, aj, ax, am, an) = (A.rowptr, A.colval, A.nzval, A.m, A.n)
    (bp, bj, bx, bm, bn) = (B.rowptr, B.colval, B.nzval, B.m, B.n)
    @assert an == bm "Dimensions mismatch. A.cols = $(an) != B.nrows = $(bm)"

    # TODO
    # Rename to I, J, V, m, n
    (cp, cj, cx, cm, cn) = (Int[], Int[], Float32[], am, bn)

    for i in 1:am
        sums = zeros(Float32, bn)
        candidates = []

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
        
        if length(candidates) > ntop
            partialsort!(candidates, ntop, by = (x -> x[2]), rev = true)
        end

        nnz = min(length(candidates), ntop)
        for l in 1:nnz
            append!(cj, candidates[l][1])
            append!(cx, candidates[l][2])
        end

        # append!(cp,cp[end] + nnz)
        append!(cp, ones(nnz) * i)
    end

     return sparsecsr(cp, cj, cx, am, bn)
end

function sparse_dot_topn(A::SparseMatrixCSR, B::SparseMatrixCSR, ntop::Int, θ::Float64, n_threads:: Int)
    @assert n_threads <= Threads.nthreads()
    # insead of slicing the csr matrix, we slice the data and fit_transform
    (m, n, ai, aj , ax) = (A.m, A.n, A.rowptr, A.colval, A.nzval)

    batch_size = div(m, n_threads)
    n_batches = div(m, batch_size)
    if m % batch_size > 0
        # if there is a reminder
        n_batches += 1
    end
    batches_csr = []
    # println(ai)
    # println(aj)
    # println(ax)
    # println("--")
    for i in 0:n_batches-1
        row_start = i*batch_size+1
        row_end= min((i+1) * batch_size, m)
        slice = row_slice_csr(A, row_start, row_end)
        push!(batches_csr, slice)
    end

    prods = Array{SparseMatrixCSR}(undef, n_batches)
    println("Computing with $(n_threads) threads, batch_size = $(batch_size), n_batches = $(n_batches).")
    Threads.@threads for i in 1:n_batches
        prod = sparse_dot_topn(batches_csr[i], B, ntop, θ)
        prods[i] = prod
    end
    return prods
end
