module ResourceTimers

using StyledStrings, Printf



export ResourceTimer, ResourceAccumulator, @meas, record!, reset!

import Base: time_ns, gc_bytes, gc_time_ns, show



"""
    ResourceAccumulator

A mutable struct that accumulates timing and resource usage statistics for a specific task and label.

# Fields
- `count::Int`: The number of times this accumulator has been updated.
- `total_time_ns::UInt64`: The total execution time in nanoseconds.
- `total_bytes::Int64`: The total number of bytes allocated.
- `total_gctime_ns::UInt64`: The total time spent in garbage collection in nanoseconds.
"""
mutable struct ResourceAccumulator
    count::Int
    total_time_ns::UInt64
    total_bytes::Int64
    total_gctime_ns::UInt64
end

ResourceAccumulator() = ResourceAccumulator(0, 0, 0, 0)

"""
    record!(acc::ResourceAccumulator, time_ns, bytes, gctime_ns)

Update the accumulator `acc` with new measurement data.

# Arguments
- `acc::ResourceAccumulator`: The accumulator to update.
- `time_ns`: The execution time in nanoseconds to add.
- `bytes`: The number of allocated bytes to add.
- `gctime_ns`: The garbage collection time in nanoseconds to add.

This function increments the `count` field by 1 and adds the provided values to the respective total fields.
"""
@inline function record!(acc::ResourceAccumulator, time_ns, bytes, gctime_ns)
    acc.count += 1
    acc.total_time_ns += time_ns
    acc.total_bytes += bytes
    acc.total_gctime_ns += gctime_ns
    nothing
end

"""
    ResourceTimer

A thread-safe timer that aggregates timing and resource usage data across multiple tasks.

# Fields
- `storage::Vector{Vector{ResourceAccumulator}}`: A matrix of accumulators, indexed by task ID and label index.
- `label_to_idx::Dict{Symbol, Int}`: A mapping from label symbols to their integer indices.
- `labels::Vector{Symbol}`: The list of valid labels.

# Constructors
    ResourceTimer(labels::Vector{Symbol}; ntasks::Int = 256)

Creates a new `ResourceTimer` with the specified labels. `ntasks` should be set to the maximum expected task ID (or thread ID) to ensure thread safety.
"""
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

ResourceTimer(labels::Vector{Symbol}, ntasks ) = ResourceTimer(labels::Vector{Symbol}; ntasks = ntasks ) 

"""
    @meas(timer, task_id, label, expr)

Measure the execution time and memory allocation of `expr` and record it in `timer`.

# Arguments
- `timer`: The `ResourceTimer` instance.
- `task_id`: An integer representing the current task or thread ID. This determines which accumulator to update.
- `label`: A bare identifier (e.g. `compute`, not `:compute`) naming the code block. Must match one of the labels defined in `timer`.
- `expr`: The expression to evaluate and measure.

# Example
```julia
task_id = 1
@meas rt task_id computation begin
    # ... computation ...
end
```
"""
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

"""
    show(io::IO, rt::ResourceTimer)

Print a formatted summary table of the resource usage statistics accumulated in `rt`.

The table includes:
- **label**: The label symbol.
- **count**: Total number of measurements for that label.
- **time**: Total execution time in seconds.
- **mem**: Total memory allocated in Megabytes (MB).
- **gctime**: Total garbage collection time in seconds.

The output is sorted by total execution time in descending order.
"""
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


"""
    reset!(rt::ResourceTimer)

Reset all accumulators in the `ResourceTimer` to zero.

This clears the `count`, `total_time_ns`, `total_bytes`, and `total_gctime_ns` fields for all labels and tasks.
"""
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
