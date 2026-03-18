# objectives

* I am in the process of creating an alternative to the TimerOutputs.jl package
* I want the package to be thread safe and have absolute minimum overhead


# plan

* the idea is to store the output of the @timed macro in a vector of storage units (perhaps a Dict) where each unit is indexed by a user-provided integer reflecting task
    - if different integers represent different tasks, thread safety ought to be maintained
* I'm wondering what the best option is for each storage unit
* I have thought of the following possibilities:
    - a reentrant Dict instead of a vector of storage units (suspect this is slow)
    - a Dict for each storage unit, aggregating each time a measurement is added (concerned about overhead)
    - a MultiDict for each storage unit, just adding an entry each time a measurement is added (concerned about overhead)
* I will be aggregating at the end to produce output similar to what TimerOutputs.jl spits out


# example

@meas 4 :poop runsomething()

* this should add the output of @timed to entry :poop in storage unit 4

# questions

1. What issues am I overlooking?
2. Are there any storage unit types that would be more performant?
