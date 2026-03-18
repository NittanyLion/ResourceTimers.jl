# ResourceTimers.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://NittanyLion.github.io/ResourceTimers.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://NittanyLion.github.io/ResourceTimers.jl/dev/)
[![Build Status](https://github.com/NittanyLion/ResourceTimers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/NittanyLion/ResourceTimers.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

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
labels = [:compute, :io, :overhead]
rt = ResourceTimer(labels)

# 2. Measure code blocks using threadid() for thread safety
@meas rt Threads.threadid() :compute begin
    sum(rand(1000, 1000))
end

@meas rt Threads.threadid() :io begin
    # Simulated I/O
end

# 3. View results
show(rt)

# 4. Reset all accumulators for a new run
reset!(rt)
```

## How It Works

`ResourceTimers.jl` pre-allocates a matrix of accumulators indexed by `(task_id, label)`. The `@meas` macro records elapsed time, allocated bytes, and GC time directly into the accumulator with no heap allocations. Thread safety is guaranteed as long as each concurrent task uses a unique `task_id`.
