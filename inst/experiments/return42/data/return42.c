#include <R.h>
#include <Rinternals.h>

SEXP return42() {
  return ScalarInteger(42);
}
