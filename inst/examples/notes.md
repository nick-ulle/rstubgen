The goal is to examine how difficult it is to generate typed function
signatures for base R functions from the underlying C code. We call these
"stubs" since they can be written as a stub of a regular function definition.
That is, a function definition with no body. For instance, the stub for the
`length()` function (using the __types__ syntax) is:

```r
length = function(x =? Any) {} ? Integer
```

There are many functions where the return type is value-dependent. For
instance,

```r
ifelse = function(test =? Vec[Logical], yes =? Any, no =? Any) {} ? Vec[Any]
```
The example
```r
ifelse(c(1, 1) > 1, 0, "a")
# 0 0
ifelse(c(-1, 1) > 1, 0, "a")
# "a" "0"
```
shows that we cannot be any more specific about the return type unless we use
run-time values. In general, we cannot type these functions accurately
(although callers may implicitly assert the expected return type through
usage).

So as a first objective, we need to figure out how many functions in base R are
problematic. That is, functions whose return type depends on the value of their
input. Note that functions whose return type depends on the type of their input
are not problematic.

We can get a list of all primitive functions in __base__ with
```r
objs = ls("package:base")
is_primitive = sapply(objs, function(x) is.primitive(get(x)))
objs[is_primitive]
#  [1] "-"               ":"               "!"               "!="
#  [5] "("               "["               "[["              "[[<-"
#  [9] "[<-"             "{"               "@"               "@<-"
# [13] "*"               "/"               "&"               "&&"
# [17] "%*%"             "%/%"             "%%"              "^"
# [21] "+"               "<"               "<-"              "<<-"
# [25] "<="              "="               "=="              ">"
# [29] ">="              "|"               "||"              "~"
# [33] "$"               "$<-"             "abs"             "acos"
# [37] "acosh"           "all"             "any"             "anyNA"
# [41] "Arg"             "as.call"         "as.character"    "as.complex"
# [45] "as.double"       "as.environment"  "as.integer"      "as.logical"
# [49] "as.numeric"      "as.raw"          "asin"            "asinh"
# [53] "atan"            "atanh"           "attr"            "attr<-"
# [57] "attributes"      "attributes<-"    "baseenv"         "break"
# [61] "browser"         "c"               "call"            "ceiling"
# [65] "class"           "class<-"         "Conj"            "cos"
# [69] "cosh"            "cospi"           "cummax"          "cummin"
# [73] "cumprod"         "cumsum"          "digamma"         "dim"
# [77] "dim<-"           "dimnames"        "dimnames<-"      "emptyenv"
# [81] "enc2native"      "enc2utf8"        "environment<-"   "exp"
# [85] "expm1"           "expression"      "floor"           "for"
# [89] "forceAndCall"    "function"        "gamma"           "gc.time"
# [93] "globalenv"       "if"              "Im"              "interactive"
# [97] "invisible"       "is.array"        "is.atomic"       "is.call"
#[101] "is.character"    "is.complex"      "is.double"       "is.environment"
#[105] "is.expression"   "is.finite"       "is.function"     "is.infinite"
#[109] "is.integer"      "is.language"     "is.list"         "is.logical"
#[113] "is.matrix"       "is.na"           "is.name"         "is.nan"
#[117] "is.null"         "is.numeric"      "is.object"       "is.pairlist"
#[121] "is.raw"          "is.recursive"    "is.single"       "is.symbol"
#[125] "isS4"            "lazyLoadDBfetch" "length"          "length<-"
#[129] "levels<-"        "lgamma"          "list"            "log"
#[133] "log10"           "log1p"           "log2"            "max"
#[137] "min"             "missing"         "Mod"             "names"
#[141] "names<-"         "nargs"           "next"            "nzchar"
#[145] "oldClass"        "oldClass<-"      "on.exit"         "pos.to.env"
#[149] "proc.time"       "prod"            "quote"           "range"
#[153] "Re"              "rep"             "repeat"          "retracemem"
#[157] "return"          "round"           "seq_along"       "seq_len"
#[161] "seq.int"         "sign"            "signif"          "sin"
#[165] "sinh"            "sinpi"           "sqrt"            "standardGeneric"
#[169] "storage.mode<-"  "substitute"      "sum"             "switch"
#[173] "tan"             "tanh"            "tanpi"           "tracemem"
#[177] "trigamma"        "trunc"           "unclass"         "untracemem"
#[181] "UseMethod"       "while"           "xtfrm"
```
So there are 183 primitive functions in R 3.4.1. Some of these are immediately
easy to type. For instance, functions whose names start with `is.` always
return a logical value. We can also eliminate assignment, control flow, and
other "functions" that behave like keywords. The `any()`, `all()`, `missing()`,
and `anyNA()` functions always return logical values. The `baseenv()`,
`emptyenv()`, `environment()`, and `globalenv()` functions always return an
environment. The `Re()`, `Mod()`, `sign()` always return a numeric (possibly
vector). The `call()` function always returns a language object. The `nargs()`
and `length()` functions always return integers. Functions whose names start
with `as.` always return the described type. The `class()`, `typeof()`, and
`mode()` functions always return a string (possibly vector). The `~` always
produces a formula (language object). The `expression()` function always
produces an expression. The `proc.time()` and `gc.time()` functions always
returns a numeric.

```
None / Null
# "<-"              "<<-"             "="
# "break"           "if"              "function"        "next"
# "UseMethod"       "while"           "repeat"          "return"
# "for"             "standardGeneric"
# "browser"         "on.exit"

Logical
#                   "all"             "any"             "anyNA"
#                   "is.array"        "is.atomic"       "is.call"
# "is.character"    "is.complex"      "is.double"       "is.environment"
# "is.expression"   "is.finite"       "is.function"     "is.infinite"
# "is.integer"      "is.language"     "is.list"         "is.logical"
# "is.matrix"       "is.na"           "is.name"         "is.nan"
# "is.null"         "is.numeric"      "is.object"       "is.pairlist"
# "is.raw"          "is.recursive"    "is.single"       "is.symbol"
# "isS4"            "missing"         "interactive"
# "!"               "!="              "&"               "&&"
# "<"               "<="              "=="              ">"
# ">="              "|"               "||"
# "nzchar"

Integer
# "length"          "nargs"           "seq_len"         "seq_along"
# "xtfrm"

Numeric
# "Re"              "Mod"             "sign"
# "proc.time"       "gc.time"
# "%/%"             "%%"

Environment
# "baseenv"         "emptyenv"        "globalenv"       "pos.to.env"

Language
# "expression"      "call"            "~"

String
# "class"           "enc2native"      "enc2utf8"

Same Type
# "as.call"         "as.character"    "as.complex"
# "as.double"       "as.environment"  "as.integer"      "as.logical"
# "as.numeric"      "as.raw"          

Number (depends on input types)
# "-"               ":"               "*"               "/"
# "+"               "abs"             "acos"            "acosh"
# "Arg"             "asin"            "asinh"           "atan"
# "atanh"           "Conj"            "cos"             "cosh"
# "cospi"           "cummax"          "cummin"          "cumprod"
# "cumsum"          "digamma"         "^"               "ceiling"
# "exp"             "expm1"           "floor"           "gamma"
# "Im"              "lgamma"          "log"             "log10"
# "log1p"           "log2"            "sin"             "sinh"
# "sinpi"           "sqrt"            
# "tan"             "tanh"            "tanpi"           "trigamma"
# "round"           "signif"          "trunc"
# "seq.int"

Matrix
# "%*%"

Pass-through
# "("               "{"               "invisible"
# "rep"             "forceAndCall"

RHS Pass-through
# "@<-"             "[[<-"            "[<-"             "$<-"
# "attr<-"          "environment<-"   "length<-"        "levels<-"
# "attributes<-"    "class<-"         "dim<-"           "dimnames<-"
# "names<-"         "oldClass<-"      "storage.mode<-"  

Optional String
# "dimnames"        "names"           "oldClass"
# "tracemem"        "retracemem"      "untracemem"

Optional Integer
# "dim"

Upcast Inputs
# "c"

Polymorphic (with -Inf/Inf for NULL)
# "range"           "max"             "min"
# "prod"            "sum"

Essentially Type-dependent
# "["               "[["              "@"               "$"
# "list"            "switch"

Unknown / Complicated
# "attr"            "attributes"      "lazyLoadDBfetch"
# "unclass"         "quote"           "substitute"
```
So now the question is how many base R functions actually use the 6 functions
that are difficult to type (or `.C`, `.Call`, `.Internal`).
