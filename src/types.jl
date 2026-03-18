
# Setup phase (not performance-critical)
const NUM_TASKS = 256
const labels = [:poop, :solve, :assemble]
const label_to_idx = Dict(ℓ => i for (i, ℓ) in enumerate(labels))


mutable struct TimingAccumulator
    count::Int
    total_time_ns::UInt64
    total_bytes::Int64
    total_gctime_ns::UInt64
end

TimingAccumulator() = TimingAccumulator(0, 0, 0, 0)

@inline function record!(acc::TimingAccumulator, time_ns, bytes, gctime_ns)
    acc.count += 1
    acc.total_time_ns += time_ns
    acc.total_bytes += bytes
    acc.total_gctime_ns += gctime_ns
    nothing
end


# Storage: outer Vector indexed by task, inner Vector indexed by label
const storage = [
    [TimingAccumulator() for _ in labels]
    for _ in 1:NUM_TASKS
]

# Hot path macro (minimal overhead)
macro meas(task_id, label, expr)
    idx = label_to_idx[label]  # resolved at macro expansion time if label is a literal
    quote
        local t0 = Base.time_ns()
        local b0 = Base.gc_bytes()
        local gc0 = Base.gc_time_ns()
        local val = $(esc(expr))
        local dt = Base.time_ns() - t0
        local db = Base.gc_bytes() - b0
        local dgc = Base.gc_time_ns() - gc0
        record!(storage[$(esc(task_id))][$idx], dt, db, dgc)
        val
    end
end

