module MiniZ3

export Config,
    set_param!,
    Context,
    Solver,
    Model,
    Variable,
    Constant,
    constraint!,
    check,
    model,
    and,
    or,
    distinct,
    each_solution,
    num_solutions

using z3_jll
include("cz3.jl")

abstract type AST <: Number end
Base.unsafe_convert(::Type{cz3.ast}, a::AST) = Base.unsafe_convert(cz3.ast, ast(a))
context(a::AST) = context(ast(a))


macro z3_finalizer(obj, function_name::Symbol)
    quote
        finalizer($(esc(obj))) do x
            ccall(($(QuoteNode(function_name)), libz3), Cvoid, (Ptr{Cvoid},), x)
            x.pointer = C_NULL
        end
    end
end

mutable struct Config
    pointer::cz3.config

    function Config()
        obj = new(ccall((:Z3_mk_config, libz3), cz3.config, ()))
        @z3_finalizer obj Z3_del_config
    end
end
Base.unsafe_convert(::Type{cz3.config}, c::Config) = c.pointer

function set_param!(c::Config, param::AbstractString, value::AbstractString)
    ccall((:Z3_set_param_value, libz3), Cvoid, (cz3.config, cz3.string, cz3.string), c, param, value)
end

function handle_error(ctx::cz3.context, error::cz3.error_code)
    println("Z3 internal error: $error")
end

mutable struct Context
    pointer::cz3.context

    function Context(cfg::Config)
        obj = new(ccall((:Z3_mk_context_rc, libz3), cz3.context, (cz3.config,), cfg))
        ccall((:Z3_set_error_handler, libz3), Cvoid, (cz3.context, Ptr{Cvoid}), obj, @cfunction(handle_error, Cvoid, (cz3.context, cz3.error_code)))
        @z3_finalizer obj Z3_del_context
    end
end
Base.unsafe_convert(::Type{cz3.context}, ctx::Context) = ctx.pointer

mutable struct Solver
    context::Context
    pointer::cz3.solver
    scopes::Vector{Vector{AST}}

    function Solver(ctx::Context)
        obj = new(ctx,
            ccall((:Z3_mk_solver, libz3),
                cz3.solver, (cz3.context,), ctx),
            [[]])
        ccall((:Z3_solver_inc_ref, libz3), Cvoid, (cz3.context, cz3.solver), ctx, obj)
        finalizer(obj) do obj
            ccall((:Z3_solver_dec_ref, libz3), Cvoid, (cz3.context, cz3.solver), ctx, obj)
        end
    end
end
Base.unsafe_convert(::Type{cz3.solver}, s::Solver) = s.pointer
context(s::Solver) = s.context

mutable struct Model
    context::Context
    pointer::cz3.model

    function Model(ctx::Context, pointer::cz3.model)
        obj = new(ctx, pointer)
        ccall((:Z3_model_inc_ref, libz3), Cvoid, (cz3.context, cz3.model), ctx, obj)
        finalizer(obj) do obj
            ccall((:Z3_model_dec_ref, libz3), Cvoid, (cz3.context, cz3.model), ctx, obj)
        end
    end
end

Base.unsafe_convert(::Type{cz3.model}, m::Model) = m.pointer
context(m::Model) = m.context

function Base.show(io::IO, model::Model)
    print(io, "Model with assignments: [\n")
    print(io, unsafe_string(ccall((:Z3_model_to_string, libz3), cz3.string, (cz3.context, cz3.model), context(model), model)))
    print(io, "]")
end

mutable struct ASTRefCount
    context::Context
    pointer::cz3.ast

    function ASTRefCount(ctx::Context, pointer::cz3.ast)
        obj = new(ctx, pointer)
        ccall((:Z3_inc_ref, libz3), Cvoid, (cz3.context, cz3.ast), ctx, pointer)
        finalizer(obj) do obj
            ccall((:Z3_dec_ref, libz3), Cvoid, (cz3.context, cz3.ast), ctx, obj)
        end
    end
end
Base.unsafe_convert(::Type{cz3.ast}, ast::ASTRefCount) = ast.pointer
context(a::ASTRefCount) = a.context

struct Sort{T}
    ast::ASTRefCount

    function Sort{Bool}(ctx::Context)
        new(ASTRefCount(ctx, ccall((:Z3_mk_bool_sort, libz3),
            cz3.ast, (cz3.context,), ctx)))
    end

    function Sort{Integer}(ctx::Context)
        new(ASTRefCount(ctx, ccall((:Z3_mk_int_sort, libz3), cz3.ast, (cz3.context,), ctx)))
    end
end
ast(s::Sort) = s.ast
Base.unsafe_convert(::Type{cz3.ast}, s::Sort) = Base.unsafe_convert(cz3.ast, ast(s))
context(s::Sort) = context(ast(s))

abstract type Value{T} <: AST end

struct Variable{T} <: Value{T}
    ast::ASTRefCount

    function Variable{T}(ctx::Context, name::AbstractString) where {T}
        sort = Sort{T}(ctx)
        sym = ccall((:Z3_mk_string_symbol, libz3), cz3.symbol, (cz3.context, cz3.string), ctx, name)
        new(ASTRefCount(ctx, ccall((:Z3_mk_const, libz3), cz3.ast, (cz3.context, cz3.symbol, cz3.sort), ctx, sym, sort)))
    end

    Variable{T}(ast::ASTRefCount) where {T} = new{T}(ast)
end
ast(v::Variable) = v.ast

struct Expr{T} <: Value{T}
    ast::ASTRefCount

    function Expr{T}(ctx::Context, pointer::cz3.ast) where {T}
        new(ASTRefCount(ctx, pointer))
    end
end
ast(e::Expr) = e.ast

struct Constant{T} <: Value{T}
    ast::ASTRefCount

    function Constant{T}(ctx::Context, pointer::cz3.ast) where {T}
        new(ASTRefCount(ctx, pointer))
    end

    function Constant{Integer}(ctx::Context, value::Integer)
        sort = Sort{Integer}(ctx)
        new(ASTRefCount(ctx, ccall((:Z3_mk_int, libz3), cz3.ast, (cz3.context, Cint, cz3.sort), ctx, value, sort)))
    end
end
ast(c::Constant) = c.ast

Base.cconvert(::Type{Ptr{cz3.ast}}, a::NTuple{N, cz3.ast}) where {T, N} = Base.RefValue(a)
Base.unsafe_convert(::Type{Ptr{cz3.ast}}, a::Base.RefValue{NTuple{N, cz3.ast}}) where {N} = Ptr{cz3.ast}(Base.unsafe_convert(Ptr{NTuple{N, cz3.ast}}, a))


function constraint!(solver::Solver, condition::Value{Bool})
    push!(solver.scopes[end], condition)
    ccall((:Z3_solver_assert, libz3), Cvoid, (cz3.context, cz3.solver, cz3.ast), context(solver), solver, condition)
end

function check(solver::Solver)
    lbool_result = ccall((:Z3_solver_check, libz3), cz3.lbool, (cz3.context, cz3.solver), context(solver), solver)
    if (lbool_result == cz3.Z3_L_FALSE)
        return false
    elseif (lbool_result == cz3.Z3_L_TRUE)
        return true
    else
        return nothing
    end
end

function model(solver::Solver)
    ptr = ccall((:Z3_solver_get_model, libz3), cz3.model, (cz3.context, cz3.solver), context(solver), solver)
    if ptr != C_NULL
        return Model(context(solver), ptr)
    else
        error("No model available.")
    end
end

function evaluate(model::Model, val::Value{T}, model_completion::Bool = true) where {T}
    result = Ref{cz3.ast}()
    @assert ccall((:Z3_model_eval, libz3), Bool, (cz3.context, cz3.model, cz3.ast, Bool, Ref{cz3.ast}), context(val), model, val, model_completion, result)
    Expr{T}(context(val), result[])
end

function Base.Int(model::Model, val::Value{Integer})
    expr = evaluate(model, val, true)
    result = Ref{Cint}()
    @assert ccall((:Z3_get_numeral_int, libz3), Bool, (cz3.context, cz3.ast, Ref{Cint}), context(val), expr, result)
    result[]
end

struct FunctionDeclaration{T} <: AST
    ast::ASTRefCount
end
ast(func::FunctionDeclaration) = func.ast

function (func::FunctionDeclaration{T})(args::Value...) where {T}
    ctx = context(func)
    for arg in args
        @assert context(arg) == ctx
    end
    pointers = Base.unsafe_convert.(cz3.ast, args)
    Expr{T}(ctx,
        ccall((:Z3_mk_app, libz3),
              cz3.ast,
              (cz3.context, cz3.func_decl, Cuint, Ptr{cz3.ast}),
              ctx, func, length(args), pointers))
end

function constant_declaration(model::Model, index::Integer)
    FunctionDeclaration{Any}(ASTRefCount(context(model),
        ccall((:Z3_model_get_const_decl, libz3),
            cz3.func_decl,
            (cz3.context, cz3.model, Cuint),
            context(model), model, index - 1)))
end

function constant_interpretation(model::Model, declaration::FunctionDeclaration)
    ast = ccall((:Z3_model_get_const_interp, libz3),
            cz3.ast,
            (cz3.context, cz3.model, cz3.func_decl),
            context(model), model, declaration)
    Expr{Any}(context(model), ast)
end

function num_constants(model::Model)
    Int(ccall((:Z3_model_get_num_consts, libz3), Cuint, (cz3.context, cz3.model), context(model), model))
end

function exclude_current_interpretation!(solver, model::Model)
    ctx = context(solver)
    assignments = map(1:num_constants(model)) do i
        declaration = constant_declaration(model, i)
        interpretation = constant_interpretation(model, declaration)

        declaration() == interpretation
    end
    constraint!(solver, !(and(assignments...)))
end

function kind(ast::AST)
    sort_ptr = ccall((:Z3_get_sort, libz3), cz3.sort,
        (cz3.context, cz3.ast),
        context(ast), ast)
    ccall((:Z3_get_sort_kind, libz3), cz3.sort_kind,
        (cz3.context, cz3.sort),
        context(ast), sort_ptr)
end

function push_scope!(solver::Solver)
    push!(solver.scopes, Vector{AST}())
    ccall((:Z3_solver_push, libz3), Cvoid,
          (cz3.context, cz3.solver),
          context(solver), solver)
end

pop_scope!(solver::Solver) = pop_scopes!(solver, 1)

function pop_scopes!(solver::Solver, num_scopes::Integer=1)
    @assert num_scopes <= length(solver.scopes) - 1
    ccall((:Z3_solver_pop, libz3), Cvoid,
          (cz3.context, cz3.solver, Cuint),
          context(solver), solver, num_scopes)
    for i in 1:num_scopes
        pop!(solver.scopes)
    end
end

function each_solution(func, solver::Solver)
    push_scope!(solver)
    try
        while check(solver)
            m = model(solver)
            func(m)
            exclude_current_interpretation!(solver, m)
        end
    finally
        pop_scope!(solver)
    end
end

function num_solutions(solver::Solver)
    count = Ref(0)
    each_solution(solver) do model
        count[] += 1
    end
    count[]
end

include("relations.jl")

end # module
