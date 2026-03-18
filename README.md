# ResourceTimers.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://NittanyLion.github.io/ResourceTimers.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://NittanyLion.github.io/ResourceTimers.jl/dev/)
[![Build Status](https://github.com/NittanyLion/ResourceTimers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/NittanyLion/ResourceTimers.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
![Authored by](authored_by.svg)

`ResourceTimers.jl` is a lightweight, thread-safe package for measuring execution time and memory allocation across multiple tasks with minimal overhead. It is designed as a low-latency alternative to `TimerOutputs.jl` for scenarios where performance and thread safety are critical.


## Features

- **Thread-safe**: Designed for use with `Base.Threads`.
- **Minimal overhead**: Zero allocations on the hot path (uses mutable structs and pre-allocated storage).
- **Simple API**: Use the `@meas` macro to wrap code blocks.
- **Detailed reporting**: Tracks execution time, memory allocation, and GC time.

## Installation



```julia
using Pkg
Pkg.add(url="https://github.com/NittanyLion/ResourceTimers.jl")
```

## Quick Start

```julia
using ResourceTimers

# 1. Define labels and create a timer
const rt = ResourceTimer( [:compute, :io, :overhead] )

# 2. Measure code blocks using an explicit task ID (1 in this case) for thread safety
@meas rt 1 compute begin
    sum(rand(1000, 1000))
end

@meas rt 1 io begin
    # Simulated I/O
end

# 3. View results
println(rt)

# 4. Reset all accumulators for a new run
reset!(rt)
```

## How It Works

`ResourceTimers.jl` pre-allocates a matrix of accumulators indexed by `(task_id, label)`. The `@meas` macro records elapsed time, allocated bytes, and GC time directly into the accumulator with no heap allocations. Thread safety is guaranteed as long as each concurrent task uses a unique `task_id`.  By default, task ids 1 through 256 are available, but the number of available task ids can be set. **Do *not* use threadid() as the task id unless you know what you are doing**.

## Multi-threaded Usage

```julia
using ResourceTimers

const rt = ResourceTimer([:work])

Threads.@threads for i in 1:100
    @meas rt i work begin
        sleep(0.01)
    end
end

show(rt)
```

## Alternatives

### TimerOutputs.jl

This package is heavily inspired by Kristoffer Carlsson's `TimerOutputs.jl` package.  The interface for `TimerOutputs.jl` is easier on the user than that of `ResourceTimers.jl`.  However, there is some overhead to this convenience plus `TimerOutputs.jl` is not thread safe.


### Profiling

Profiling offers greater detail than packages like `TimerOutputs.jl` and `ResourceTimers.jl`.  However, it is more demanding on the user than either of the time measurement packages mentioned here.


## Disclaimers

- **This is a development version, which will be added to the general registry when done.**
- Claude Opus 4.6 was used to help with the development of this package.

