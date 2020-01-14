using Test
using Z3

@testset "Easy sudoku" begin
    cfg = Config()
    set_param!(cfg, "model", "true")
    ctx = Context(cfg)
    solver = Solver(ctx)

    grid = [Variable{Integer}(ctx, "cell_$(i)_$(j)") for i in 1:9, j in 1:9]

    for cell in grid
        constraint!(solver, cell > Constant{Integer}(ctx, 0))
        constraint!(solver, cell < Constant{Integer}(ctx, 10))
    end

    function eachblock(grid::AbstractMatrix)
        @assert size(grid) == (9, 9)
        [view(grid, i:i+2, j:j+2) for i in 1:3:7, j in 1:3:7]
    end

    for block in Iterators.flatten((eachrow(grid), eachcol(grid), eachblock(grid)))
        constraint!(solver, distinct(block...))
    end

    givens = [
    6 0 0 0 1 8 0 0 2
    0 0 0 0 0 0 0 1 0
    0 9 0 0 7 2 6 0 4
    0 8 7 2 0 0 3 0 1
    3 0 0 6 8 7 0 0 9
    2 0 9 0 0 3 7 5 0
    8 0 1 7 9 0 0 4 0
    0 2 0 0 0 0 0 0 0
    9 0 0 8 2 0 0 0 6
    ]

    for (i, given) in enumerate(givens)
        if given != 0
            constraint!(solver, grid[i] == Constant{Integer}(ctx, given))
        end
    end

    @test check(solver)
    m = model(solver)
    solution = Int.(Ref(m), grid)

    for row in eachrow(solution)
        @test sort(row) == 1:9
    end
    for col in eachcol(solution)
        @test sort(col) == 1:9
    end
    for i in 1:3:7
        for j in 1:3:7
            @test sort(vec(solution[i:i+2, j:j+2])) == 1:9
        end
    end
    @test solution == [
     6 7 4 3 1 8 5 9 2
     5 3 2 9 6 4 8 1 7
     1 9 8 5 7 2 6 3 4
     4 8 7 2 5 9 3 6 1
     3 1 5 6 8 7 4 2 9
     2 6 9 1 4 3 7 5 8
     8 5 1 7 9 6 2 4 3
     7 2 6 4 3 1 9 8 5
     9 4 3 8 2 5 1 7 6
     ]
 end
