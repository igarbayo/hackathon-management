# Shared result of minting a token (PAT or integration): the plain value only
# exists here, once (RNF-SEC-002).
module Tokens
  MintResult = Struct.new(:raw_token, :record, keyword_init: true)
end
