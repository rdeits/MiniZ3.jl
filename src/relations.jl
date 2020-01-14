
function Base.:<(x::Value{Integer}, y::Value{Integer})
    @assert context(x) === context(y)
    Expr{Bool}(context(x), ccall((:Z3_mk_lt, libz3), cz3.ast, (cz3.context, cz3.ast, cz3.ast), context(x), x, y))
end

function Base.:>(x::Value{Integer}, y::Value{Integer})
    @assert context(x) === context(y)
    Expr{Bool}(context(x), ccall((:Z3_mk_gt, libz3), cz3.ast, (cz3.context, cz3.ast, cz3.ast), context(x), x, y))
end

function Base.xor(b1::Value{Bool}, b2::Value{Bool})
    @assert context(b1) === context(b2)
    Expr{Bool}(context(b1), ccall((:Z3_mk_xor, libz3), cz3.ast, (cz3.context, cz3.ast, cz3.ast), context(b1), b1, b2))
end

function Base.:(==)(x::Value{T}, y::Value{T}) where {T}
    @assert context(x) === context(y)
    Expr{Bool}(context(x), ccall((:Z3_mk_eq, libz3), cz3.ast, (cz3.context, cz3.ast, cz3.ast), context(x), x, y))
end

function Base.:!(x::Value{Bool})
    Expr{Bool}(context(x), ccall((:Z3_mk_not, libz3), cz3.ast, (cz3.context, cz3.ast), context(x), x))
end

function common_context(x::AST...)
    ctx = context(first(x))
    for element in x
        @assert context(element) == ctx
    end
    ctx
end

function and(vals::Value{Bool}...)
    ctx = common_context(vals...)
    pointers = Base.unsafe_convert.(cz3.ast, vals)
    Expr{Bool}(ctx,
        ccall((:Z3_mk_and, libz3),
              cz3.ast,
              (cz3.context, Cuint, Ptr{cz3.ast}),
              ctx, length(vals), pointers))
end

function or(vals::Value{Bool}...)
    ctx = common_context(vals...)
    pointers = Base.unsafe_convert.(cz3.ast, vals)
    Expr{Bool}(ctx,
        ccall((:Z3_mk_or, libz3),
              cz3.ast,
              (cz3.context, Cuint, Ptr{cz3.ast}),
              ctx, length(vals), pointers))
end

function distinct(vals::Value{T}...) where {T}
    ctx = common_context(vals...)
    pointers = Base.unsafe_convert.(cz3.ast, vals)
    Expr{Bool}(ctx,
        ccall((:Z3_mk_distinct, libz3),
              cz3.ast,
              (cz3.context, Cuint, Ptr{cz3.ast}),
              ctx, length(vals), pointers))
end

function Base.:+(vals::Value{Integer}...)
    ctx = context(first(vals))
    for val in vals
        @assert context(val) === ctx
    end
    pointers = Base.unsafe_convert.(cz3.ast, vals)
    Expr{Integer}(ctx, ccall((:Z3_mk_add, libz3), cz3.ast, (cz3.context, Cuint, Ptr{cz3.ast}), ctx, length(vals), pointers))
end
