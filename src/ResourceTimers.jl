module ResourceTimers

using StyledStrings, Printf



export ResourceTimer, ResourceAccumulator, @meas, record!, reset!

import Base: time_ns, gc_bytes, gc_time_ns, show



mutable struct ResourceAccumulator
    count::Int
    total_time_ns::UInt64
    total_bytes::Int64
    total_gctime_ns::UInt64
end

ResourceAccumulator() = ResourceAccumulator(0, 0, 0, 0)

@inline function record!(acc::ResourceAccumulator, time_ns, bytes, gctime_ns)
    acc.count += 1
    acc.total_time_ns += time_ns
    acc.total_bytes += bytes
    acc.total_gctime_ns += gctime_ns
    nothing
end

struct ResourceTimer
    storage::Vector{Vector{ResourceAccumulator}}
    label_to_idx::Dict{Symbol, Int}
    labels::Vector{Symbol}
end

function ResourceTimer(labels::Vector{Symbol}; ntasks::Int = 256)
    label_to_idx = Dict(ℓ => i for (i, ℓ) in enumerate(labels))
    storage = [[ResourceAccumulator() for _ ∈ labels] for _ ∈ 1:ntasks]
    ResourceTimer(storage, label_to_idx, labels)
end

# Hot path macro (minimal overhead)
macro meas(timer, task_id, label, expr)
    quote
        local rt = $(esc(timer))
        local idx = rt.label_to_idx[$(QuoteNode(label))]
        local t0 = time_ns()
        local b0 = gc_bytes()
        local gc0 = gc_time_ns()
        local val = $(esc(expr))
        local dt = time_ns() - t0
        local db = gc_bytes() - b0
        local dgc = gc_time_ns() - gc0
        record!(rt.storage[$(esc(task_id))][idx], dt, db, dgc)
        val
    end
end

function cpad( s, n, p :: Union{AbstractChar,AbstractString}=' ') 
    ss = string( s )
    nn = textwidth( ss )
    ( topad = n - nn ) ≤ 0 && return ss
    leftie = topad ÷ 2
    return rpad( lpad( ss, leftie + nn, p ), n, p )
end


show( io :: IO, ::MIME"text/plain", rt :: ResourceTimer ) = nothing

function show( io :: IO, rt :: ResourceTimer )
    cum = Dict{Symbol,@NamedTuple{ count:: Int, time::Float64, gcmb :: Float64, gctime :: Float64 }}()
    
    total_count = 0
    total_time = 0.0
    total_gcmb = 0.0
    total_gctime = 0.0

    for sym ∈ rt.labels
        time = gcmb = gctime = 0.0
        count = 0
        for s ∈ rt.storage
            ra = s[ rt.label_to_idx[sym] ]
            count += ra.count
            time += ra.total_time_ns * 1e-9
            gcmb += ra.total_bytes * 1e-6
            gctime += ra.total_gctime_ns * 1e-9
        end
        cum[sym] = (count=count, time=time, gcmb=gcmb, gctime=gctime)
        
        total_count += count
        total_time += time
        total_gcmb += gcmb
        total_gctime += gctime
    end

    println( styled"{bold:$(rpad( \"label\", 40 )) {green:$(lpad(\"count\",6))}  {red:$(cpad(\"time\",12))}  {blue:$(cpad(\"mem\",9))}  {yellow:$(cpad(\"gctime\",8))}}" )
    println( "-"^82 )
    for (sym,cs) ∈ sort(collect(cum), by=x->x.second.time, rev=true)
        time = @sprintf "%.3f" cs.time
        gctime = @sprintf "%.3f" cs.gctime
        igcmb = Int( round( cs.gcmb; digits = 0 ) )
        println( styled"$(rpad( \"$sym \", 40, '‧' )) {green:$(lpad(cs.count,6))}  {red:$(lpad(time,10))}{shadow: s}  {blue:$(lpad(igcmb,6))}{shadow: MB}  {yellow:$(lpad(gctime,6))}{shadow: s}" )
    end
    
    println( "-"^80 )
    t_time = @sprintf "%.3f" total_time
    t_gctime = @sprintf "%.3f" total_gctime
    t_igcmb = Int( round( total_gcmb; digits = 0 ) )
    println( styled"{bold:$(rpad( \"TOTAL\", 40 ))} {green:$(lpad(total_count,6))}  {red:$(lpad(t_time,10))}{shadow: s}  {blue:$(lpad(t_igcmb,6))}{shadow: MB}  {yellow:$(lpad(t_gctime,6))}{shadow: s}" )
    return nothing
end


function reset!( rt :: ResourceTimer )
    for s ∈ rt.storage, sym ∈ rt.labels
        ra = s[ rt.label_to_idx[sym] ]
        ra.count = 0
        ra.total_time_ns = 0
        ra.total_bytes = 0
        ra.total_gctime_ns = 0
    end
    return nothing
end

end
