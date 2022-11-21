using Unicode

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