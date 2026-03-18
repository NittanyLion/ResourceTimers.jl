# Answers

## 1. What issues am I overlooking?

### `@timed` itself has overhead
`@timed` allocates a `NamedTuple` on every call. If the goal is absolute minimum overhead, consider calling `time_ns()` (or `Base.gc_num()` if you need allocation stats) directly around the measured code. This avoids the allocation entirely.

### Task migration invalidates `Threads.threadid()` as a stable index
Since Julia 1.7+, tasks can migrate between threads. If you're using `Threads.threadid()` as the "user-provided integer", a task could be rescheduled onto a different thread mid-execution, meaning two tasks could end up writing to the same storage unit concurrently. You have two options:
- Use `Threads.threadid()` but accept that it only works for `@threads`-style parallelism where tasks are pinned.
- Make the user explicitly pass a task index (as your `@meas 4 ...` example suggests), which puts the burden on the caller but is genuinely safe.

The second option is the right call for your design—just document it clearly.

### Dict lookup on every measurement is unnecessary overhead
Looking up a `Symbol` key in a `Dict` on every measurement call involves hashing and potential cache misses. If the label set is small, there are faster alternatives (see question 2).

### Aggregation at the end across storage units
You'll need to merge results from all storage units into a single summary. This is fine as long as you do it after all tasks are done (no synchronization needed). Just make sure the API has a clear "finalize" step.


## 2. Are there any storage unit types that would be more performant?

Yes. The fastest option is a **mutable accumulator struct** that updates in-place, combined with a storage structure that avoids hashing overhead.

### Recommended design

```julia
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
```

This has **zero allocation per measurement**—it's just four integer additions.

### For the per-task storage unit

Ranked from fastest to slowest:

1. **`Vector{TimingAccumulator}` with integer label keys** — If you can map your labels (`:poop`, etc.) to small integers (1, 2, 3…) at setup time, indexing into a pre-allocated `Vector` is a single pointer offset. No hashing, no branching.

2. **A small fixed `Dict{Symbol, TimingAccumulator}`** — If labels must be symbols, pre-populate the Dict during setup so all keys exist before any measurements run. Then `dict[:poop]` is just a lookup + in-place mutation of the returned struct (no insertion ever happens on the hot path). This is acceptable overhead for most use cases.

3. **`MultiDict` or appending to vectors** — Worst option. Every measurement allocates or grows a container. Aggregation is deferred but the per-call cost is much higher.

### Putting it all together

```julia
# Setup phase (not performance-critical)
const NUM_TASKS = 8
const labels = [:poop, :solve, :assemble]
const label_to_idx = Dict(l => i for (i, l) in enumerate(labels))

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
```

This gives you:
- **Zero allocations** on the hot path
- **No locks or atomics** (each task writes to its own `storage[task_id]`)
- **No Dict lookup** at measurement time (label → index is resolved at compile time or setup time)
- **Simple aggregation**: just sum the accumulators across task indices at the end
