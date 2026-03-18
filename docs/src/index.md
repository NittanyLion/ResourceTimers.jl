```@meta
CurrentModule = ResourceTimers
```

# ResourceTimers.jl

ResourceTimers.jl is a lightweight, thread-safe package for measuring execution time and memory allocation across multiple tasks with minimal overhead.

It is designed as an alternative to `TimerOutputs.jl` for high-performance scenarios where thread safety and low latency are critical.

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
labels = [:compute, :io, :overhead]
rt = ResourceTimer(labels)

# 2. Measure code blocks
# Use threadid() as the task index for thread-safe storage
@meas rt Threads.threadid() :compute begin
    sum(rand(1000, 1000))
end

# 3. View results
show(rt)
```
