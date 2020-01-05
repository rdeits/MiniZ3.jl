module Z3

using z3_jll
include("cz3.jl")

macro z3_finalizer(obj, function_name::Symbol)
    quote
        finalizer($(esc(obj))) do x
            ccall(($(QuoteNode(function_name)), libz3), Cvoid, (Ptr{Cvoid},), x)
            x.pointer = Cvoid
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
    printf("Z3 internal error: $error")
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

    function Solver(ctx::Context)
        obj = new(ctx, ccall((:Z3_mk_solver, libz3), cz3.solver, (cz3.context,), ctx))
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

abstract type AST end
Base.unsafe_convert(::Type{cz3.ast}, a::AST) = Base.unsafe_convert(cz3.ast, ast(a))
context(a::AST) = context(ast(a))

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

struct Sort{T} <: AST
    ast::ASTRefCount

    function Sort{Bool}(ctx::Context)
        new(ASTRefCount(ctx, ccall((:Z3_mk_bool_sort, libz3),
            cz3.ast, (cz3.context,), ctx)))
    end
end
ast(s::Sort) = s.ast

abstract type Value{T} <: AST end

struct Variable{T} <: Value{T}
    ast::ASTRefCount

    function Variable{T}(ctx::Context, name::AbstractString) where {T}
        sort = Sort{T}(ctx)
        sym = ccall((:Z3_mk_string_symbol, libz3), cz3.symbol, (cz3.context, cz3.string), ctx, name)
        new(ASTRefCount(ctx, ccall((:Z3_mk_const, libz3), cz3.ast, (cz3.context, cz3.symbol, cz3.sort), ctx, sym, sort)))
    end
end
ast(v::Variable) = v.ast

struct Expr{T} <: Value{T}
    ast::ASTRefCount

    function Expr{T}(ctx::Context, pointer::cz3.ast) where {T}
        new(ASTRefCount(ctx, pointer))
    end
end
ast(e::Expr) = e.ast

function Base.xor(b1::Value{Bool}, b2::Value{Bool})
    @assert context(b1) === context(b2)
    Expr{Bool}(context(b1), ccall((:Z3_mk_xor, libz3), cz3.ast, (cz3.context, cz3.ast, cz3.ast), context(b1), b1, b2))
end

function constraint!(solver::Solver, condition::Value{Bool})
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

end # module
