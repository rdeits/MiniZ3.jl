module cz3

const config = Ptr{Cvoid}
const string = Cstring

@enum(error_code,
     Z3_OK,
     Z3_SORT_ERROR,
     Z3_IOB,
     Z3_INVALID_ARG,
     Z3_PARSER_ERROR,
     Z3_NO_PARSER,
     Z3_INVALID_PATTERN,
     Z3_MEMOUT_FAIL,
     Z3_FILE_ACCESS_ERROR,
     Z3_INTERNAL_FATAL,
     Z3_INVALID_USAGE,
     Z3_DEC_REF_ERROR,
     Z3_EXCEPTION)

@enum(lbool,
      Z3_L_FALSE = -1,
      Z3_L_UNDEF = 0,
      Z3_L_TRUE = 1)

@enum(sort_kind,
     Z3_UNINTERPRETED_SORT,
     Z3_BOOL_SORT,
     Z3_INT_SORT,
     Z3_REAL_SORT,
     Z3_BV_SORT,
     Z3_ARRAY_SORT,
     Z3_DATATYPE_SORT,
     Z3_RELATION_SORT,
     Z3_FINITE_DOMAIN_SORT,
     Z3_FLOATING_POINT_SORT,
     Z3_ROUNDING_MODE_SORT,
     Z3_SEQ_SORT,
     Z3_RE_SORT,
     Z3_UNKNOWN_SORT = 1000)


const context = Ptr{Cvoid}
const ast = Ptr{Cvoid}
const sort = Ptr{Cvoid}
const symbol = Ptr{Cvoid}
const solver = Ptr{Cvoid}
const model = Ptr{Cvoid}
const func_decl = Ptr{Cvoid}
const sort = Ptr{Cvoid}

end