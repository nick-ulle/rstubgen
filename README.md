# rstubgen

__rstubgen__ is a package that explores the feasibility of using the
__[RCIndex][]__ package to automatically generate type signatures (called
"stubs") for R code that calls C functions.

The current focus is on functions built into GNU R, particularly primitives.
However, the scope of this package will probably expand to include generating
stubs for user packages as well.

[RCIndex]: https://github.com/omegahat/RClangSimple
