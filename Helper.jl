function unfold_ptr(A::SparseMatrixCSR)
    (m, n, ap, aj , ax) = (A.m, A.n, A.rowptr, A.colval, A.nzval)
    (I,J,V)=(Int[],aj,ax)
    for i in 1:length(ap)-1
        append!(I, ones(Int, ap[i+1]-ap[i]) * i)
    end
    return (I, J, V, m, n)
end

function row_slice_csr(A::SparseMatrixCSR, from::Int, to::Int)
    (m, n, ap, aj , ax) = (A.m, A.n, A.rowptr, A.colval, A.nzval)
    bp = ap[from:to+1]
    I = []
    for i in 1:length(bp)-1
        #unfold row pointer
        append!(I, ones(Int32, bp[i+1]-bp[i]) * i)
    end
    J = aj[bp[1]:bp[end]-1]
    V = ax[bp[1]:bp[end]-1]
    return sparsecsr(I, J, V, to-from+1, n)
end

function vcat_csr(slices::Array{SparseMatrixCSR})
    (I, J, V, m, n) = (Int[], Int[], Float32[], 0, 0)
    for (i, s) in enumerate(slices)
        (SI, SJ, SV, sm, sn) = unfold_ptr(s)
        SI = SI .+ m
        append!(I, SI)
        append!(J, SJ)
        append!(V, SV)
        m += sm
        n = sn 
    end
    return sparsecsr(I, J, V, m, n)
end