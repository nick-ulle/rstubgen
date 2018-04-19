
if (!is.loaded("return42"))
  dyn.load("return42.so")

return42 = function() {
  .Call("return42")
}
