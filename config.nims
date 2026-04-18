# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  switch("define", "ssl")
  include "nimble.paths"

# end Nimble config
