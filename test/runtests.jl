using Test
using MiniZ3

@testset "Easy multiple solutions" begin
    cfg = Config()
    set_param!(cfg, "model", "true")
    ctx = Context(cfg)
    solver = Solver(ctx)

    x = Variable{Integer}(ctx, "x")
    constraint!(solver, x > Constant{Integer}(ctx, 0))
    constraint!(solver, x < Constant{Integer}(ctx, 5))
    extracted_solutions = Int[]
    each_solution(solver) do model
        push!(extracted_solutions, Int(model, x))
    end
    @test sort(extracted_solutions) == [1, 2, 3, 4]
    @test num_solutions(solver) == 4

    # Verify we can iterate over the solutions again
    extracted_solutions = Int[]
    each_solution(solver) do model
        push!(extracted_solutions, Int(model, x))
    end
    @test sort(extracted_solutions) == [1, 2, 3, 4]

    # Verify that throwing an exception while enumerating
    # solutions doesn't leave the model in an inconsistent state
    @test_throws ErrorException begin
        each_solution(solver) do model
            error("threw an exception while iterating solutions")
        end
    end
    extracted_solutions = Int[]
    each_solution(solver) do model
        push!(extracted_solutions, Int(model, x))
    end
    @test sort(extracted_solutions) == [1, 2, 3, 4]
end

include("sudoku.jl")
