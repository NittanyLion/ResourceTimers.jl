```@meta
CurrentModule = ResourceTimers
```

# ResourceTimers.jl

ResourceTimers.jl is a lightweight, thread-safe package for measuring execution time and memory allocation across multiple tasks with minimal overhead.

It is designed as an alternative to `TimerOutputs.jl` for high-performance scenarios where thread safety and low latency are critical.

## Features

- **Thread-safe**: Each concurrent task writes to its own storage slot — no locks or atomics required.
- **Minimal overhead**: Zero allocations on the hot path.
- **Simple API**: Wrap any expression with the `@meas` macro.
- **Detailed reporting**: Tracks execution time, memory allocation, and GC time per label.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/NittanyLion/ResourceTimers.jl")
```

## Quick Start

```julia
using ResourceTimers

# 1. Create a timer with the labels you want to track
const rt = ResourceTimer([:compute, :io, :overhead])

# 2. Measure code blocks (pass a unique integer task ID per thread/task)
task_id = 1
@meas rt task_id compute begin
    sum(rand(1000, 1000))
end

# 3. View aggregated results across all tasks
show(rt)

# 4. Reset for a new run
reset!(rt)
```

## Multi-threaded Usage

```@example
using ResourceTimers

const rt = ResourceTimer([:work], 1000)

Threads.@threads for i in 1:1000
    @meas rt i work begin
        sleep(0.01)
    end
end

println(rt)
```

See the [API Reference](@ref) for full details.
