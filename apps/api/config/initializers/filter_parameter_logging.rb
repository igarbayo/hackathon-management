# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information. See the ActiveSupport::ParameterFilter
# documentation for supported notations and behaviors. RNF-SEC-009 (09-privacidad-seguridad.md): tokens,
# cookies, passwords, prompts and Idempotency-Key never go to the logs.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :prompt, :authorization, :idempotency_key
]
