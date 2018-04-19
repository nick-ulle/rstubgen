
## This is an experiment in using RCIndex to collect information about a C
## routine called from R with `.Call()`.
## 
## The C code is in the file `return42.c`, which defines one routine,
## `return42()`. The `return42()` routine uses the R API to return the integer
## 42 as an R INTSXP. The code is:
## 
## ```c
## #include <R.h>
## #include <Rinternals.h>
## 
## SEXP return42() {
##   return ScalarInteger(42);
## }
## ```
## 
## The primary complication in this code is that `ScalarInteger` is a macro
## that calls the routine `Rf_ScalarInteger()`. The `Rf_ScalarInteger()`
## routine is defined as the inline routine `ScalarInteger()` in
## `Rinlinedfuns.h`. The code for this is:
## 
## ```c
## INLINE_FUN SEXP ScalarInteger(int x)
## {
##     SEXP ans = allocVector(INTSXP, 1);
##     SET_SCALAR_IVAL(ans, x);
##     return ans;
## }
## ```
## 
## As a consequence, we will have to work with multiple translation units even
## to get information about the relatively simple `return42()` routine.
## 
## We can use `createTU()` in RCIndex to create a translation unit for the
## `return42.c` file. We must set the `include =` parameter so that RCIndex can
## find the R header files.

library("RCIndex")

R_SOURCES = "../../../../r-source/src"
R_HEADERS = file.path(R_SOURCES, "include")

includes = c(R_HEADERS, "/usr/include/linux")
#includes = R_HEADERS

idx = createIndex()
tu = createTU("data/return42.c", includes = includes, idx = idx)

## Once we have the translation unit, we can get the list of routines with
## `getRoutines()`:

routines = getRoutines(tu)

## Now let's examine the body of the `return42()` routine. We could use the
## code in `return42()` to determine its return type.

ret42 = routines[["return42"]]

## We can access the body of the routine with `getChildren()` (but strangely,
## not the `children()` function). If we were processing the routine
## non-interactively, we would use `visitCursor()` instead. Later, we will
## discuss a strategy for using `visitCursor()` to extract the information we
## need.
## 
## The second child is the body of the function. Its children are the
## statements in the function; in this example, there is only one, a return
## statement.

bod = getChildren(ret42)[[2]]
ret = children(bod)[[1]]

## Since __libclang__ runs the preprocessor, the `ScalarInteger` macro is
## translated into a call to `Rf_ScalarInteger()`. this call to
## `Rf_ScalarInteger()` is the only child of the return statement. We can
## access this call the same way we have accessed other children so far. The
## call contains a reference to the definition of the routine being called. We
## can get this with `getCursorReferenced()`.

call = children(ret)[[1]]
fn = getCursorReferenced(call)

## This gives us a reference to the declaration of `Rf_ScalarInteger()`.
## However, this seems to be the header declaration and does not give us the
## definition. So we need to figure out how to get at the definition.
## 
## There is a `getCursorDefinition()` function in RCIndex, but for `fn` this
## returns `CXCursor_FirstInvalid`.

fn_name = getName(fn)

## How can we link the name `Rf_ScalarInteger` to the inline function
## `ScalarInteger`?

header = file.path(R_SOURCES, "include/Rinlinedfuns.h")
tu2 = createTU(header, includes = includes, idx = idx)

r_api = getRoutines(tu2)

scalar_int = r_api[["ScalarInteger"]]

ret_ty = scalar_int@returnType
type = getTypeKind(ret_ty)

## Strategy to get TUs for all R sources?
##
## How to search in a different TU? How to find the right TU? Can we search the
## Index?
##
## What's going on with the inline functions (again)? R_NO_REMAP
##
## Why do inline function return types come out as int?

