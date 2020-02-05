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

@testset "xor" begin
    cfg = Config()
    set_param!(cfg, "model", "true")
    ctx = Context(cfg)
    solver = Solver(ctx)

    x = Variable{Bool}(ctx, "x")
    y = Variable{Bool}(ctx, "y")
    x_xor_y = x ⊻ y

    constraint!(solver, x_xor_y)

    @test check(solver) == true
    @test num_solutions(solver) == 2
end

@testset "arithmetic and equality" begin
    cfg = Config()
    set_param!(cfg, "model", "true")
    set_param!(cfg, "debug_ref_count", "true")
    ctx = Context(cfg)
    solver = Solver(ctx)

    x = Variable{Integer}(ctx, "x")
    y = Variable{Integer}(ctx, "y")
    one = Constant{Integer}(ctx, 1)
    two = Constant{Integer}(ctx, 2)

    y_plus_one = y + one

    constraint!(solver, x < y_plus_one)
    constraint!(solver, x > two)
    @test check(solver)
    m = model(solver)
    io = IOBuffer()
    print(io, m)
    @test String(take!(io)) == """
Model with assignments: [
x -> 3
y -> 3
]"""

    constraint!(solver, !(x == y))

    @test check(solver)
    m = model(solver)
    io = IOBuffer()
    print(io, m)
    @test String(take!(io)) == """
Model with assignments: [
y -> 4
x -> 3
]"""

    m = model(solver)
    @test Int(m, x) == 3
    @test Int(m, y) == 4

    MiniZ3.exclude_current_interpretation!(solver, m)
    @test check(solver)
    m = model(solver)
    @test Int(m, x) == 3
    @test Int(m, y) == 5
end

include("sudoku.jl")
