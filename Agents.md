# Agents.md

Instructions for AI coding agents working on ResourceTimers.jl.

## Project Overview

ResourceTimers.jl is a lightweight, thread-safe Julia package for measuring execution time, memory allocation, and GC time. It is designed for minimal overhead on the hot path.

## Architecture

- `src/ResourceTimers.jl` — Single-file package containing all types, the `@meas` macro, `show`, and `reset!`.
- `ResourceAccumulator` — Mutable struct holding running totals (count, time, bytes, gctime). Updated in-place with zero allocations.
- `ResourceTimer` — Immutable struct holding a pre-allocated `Vector{Vector{ResourceAccumulator}}` indexed by `(task_id, label)`, plus a `Dict{Symbol, Int}` mapping labels to indices.
- `@meas timer task_id label expr` — The main macro. Labels are passed as bare identifiers (not `:symbol`). The macro uses `QuoteNode` internally.

## Thread Safety Model

Thread safety relies on each concurrent task using a **distinct `task_id`** integer. There are no locks or atomics. `Threads.threadid()` is safe as a task ID only with `@threads`-style parallelism (pinned tasks). For `@spawn`-based parallelism, users must supply their own unique IDs.

## Key Conventions

- The package uses Julia 1.12+ features (`StyledStrings`).
- Unicode operators (`∈`, `ℓ`, `≤`, `÷`) are used throughout the source — follow this style.
- The `show` method uses `StyledStrings` and `@sprintf` for colored terminal output.
- All exported symbols: `ResourceTimer`, `ResourceAccumulator`, `@meas`, `record!`, `reset!`.

## Testing

- Tests are in `test/runtests.jl`.
- Aqua.jl is used for code quality checks (`Aqua.test_all`).
- Run tests with `julia --project=. -e 'using Pkg; Pkg.test()'`.

## Documentation

- Built with Documenter.jl. Config in `docs/make.jl`.
- Pages: `docs/src/index.md` (home), `docs/src/api.md` (API reference).
- All public functions and types have docstrings.

## Common Tasks

- **Adding a new label stat**: Add a field to `ResourceAccumulator`, update `record!`, `reset!`, and the `show` method.
- **Adding a new exported function**: Add it to the `export` line and write a docstring. Add a `@docs` block in `docs/src/api.md`.
