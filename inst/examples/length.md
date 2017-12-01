
Many of R's built-in functions and functions in contributed packages call C
routines in order to improve efficiency or make use of external libraries. We
would like to be able to infer type information for these functions the same
way we can infer type information for pure R code.

Built-in functions typically call routines through `.Primitive` and
`.Internal`, while packages (plus a few built-in functions) call routines
through `.C`, `.Call`, and `.External`.

As an example, we can study the `length()` function, which uses `.Primitive()`.
The `length()` function is a useful first example because its type signature is 
simple: $$length: \forall a. a \to Integer$$. In other words, the `length()`
function has only 1 parameter, which is not optional, and it always returns a
scalar integer.

The `.Primitive()` function takes the name of a primitive as its only argument.
The interpreter looks up this name in a table, `R_FunTab`, defined at
`src/main/names.c`. The table maps primitive names to routines. From the table,
we can see that the `"length"` primitive corresponds to the `do_length`
routine.

The `do_length` routine, defined in `src/main/array.c` is:

```c
SEXP attribute_hidden do_length(SEXP call, SEXP op, SEXP args, SEXP rho)
{
    checkArity(op, args);
    check1arg(args, call, "x");

    SEXP x = CAR(args), ans;

    if (isObject(x) &&
      DispatchOrEval(call, op, "length", args, rho, &ans, 0, 1)) {
	      if (length(ans) == 1 && TYPEOF(ans) == REALSXP) {
	          double d = REAL(ans)[0];
	          if (R_FINITE(d) && d >= 0. && d <= INT_MAX && floor(d) == d) {
                      PROTECT(ans);
                      ans = coerceVector(ans, INTSXP);
                      UNPROTECT(1);
                      return(ans);
                  }
	      }
	      return(ans);
    }


#ifdef LONG_VECTOR_SUPPORT
    // or use IS_LONG_VEC
    R_xlen_t len = xlength(x);
    if (len > INT_MAX) return ScalarReal((double) len);
#endif
    return ScalarInteger(length(x));
}
```

Primitive routines such as this one have a standard signature. Their name
always begins with `do_`, they always return a `SEXP`, and they always have the
argument list `(SEXP call, SEXP op, SEXP args, SEXP env)`. These arguments are:

* `call`:
* `op`: The offset pointer
* `args`: The argument list
* `env`:

Let's examine this function line-by-line to determine how inference might work.
The first two lines are sanity checks. The `checkArity()` macro calls
`Rf_checkArityCall()`. This routine checks that the call has the correct number
of arguments. The `check1arg()` macro is an alias for the routine
`Rf_check1arg()`, which checks that in a call with one argument, the argument
has the correct name. The next line defines a `SEXP` `x` to hold the first
argument in the argument list and a `SEXP` `ans` to hold the result. The
if-statement uses the `isObject()` macro to check whether the argument has a
class set. When the argument does have a class set, then the if-statement uses
`DispatchOrEval()` to attempt calling its "length" method. The result is saved
into `ans` and returned. If the result is an integer-valued numeric scalar, it
is converted to an integer before being returned. Next, if R is compiled with
long vector support, the length may be too large to fit in an integer, so the
code uses two lines to check for this. The call to `xlength()` is similar to
the call to `length()` on the last line, but handles long vectors correctly.
The inline function `length()` is defined by:

```c
INLINE_FUN R_len_t length(SEXP s)
{
    switch (TYPEOF(s)) {
    case NILSXP:
	return 0;
    case LGLSXP:
    case INTSXP:
    case REALSXP:
    case CPLXSXP:
    case STRSXP:
    case CHARSXP:
    case VECSXP:
    case EXPRSXP:
    case RAWSXP:
	return LENGTH(s);
    case LISTSXP:
    case LANGSXP:
    case DOTSXP:
    {
	int i = 0;
	while (s != NULL && s != R_NilValue) {
	    i++;
	    s = CDR(s);
	}
	return i;
    }
    case ENVSXP:
	return Rf_envlength(s);
    default:
	return 1;
    }
}
```
