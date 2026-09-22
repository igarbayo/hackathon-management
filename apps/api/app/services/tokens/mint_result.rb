# Resultado compartido de mintear un token (PAT o de integración): el valor
# en claro solo existe aquí, una vez (RNF-SEC-002).
module Tokens
  MintResult = Struct.new(:raw_token, :record, keyword_init: true)
end
