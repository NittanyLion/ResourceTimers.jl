using ResourceTimers
using Test
using Aqua

@testset "ResourceTimers.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(ResourceTimers)
    end
    # Write your tests here.
end
