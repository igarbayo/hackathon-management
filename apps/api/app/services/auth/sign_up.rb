module Auth
  class SignUp
    # Mismo límite que el login (RNF-SEC-005): la spec no daba un número
    # propio para signup, y es el mismo vector de abuso (creación masiva de
    # cuentas) que el de fuerza bruta en login.
    LIMIT = 10
    PERIOD = 15.minutes

    def self.call(email:, name:, password:, ip:)
      RateLimiter.check!("signup:ip:#{ip}", limit: LIMIT, period: PERIOD)

      User.create!(email: email, name: name, password: password)
    end
  end
end
