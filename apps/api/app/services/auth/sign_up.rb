module Auth
  class SignUp
    # Same limit as login (RNF-SEC-005): the spec gave no specific number for
    # signup, and it is the same abuse vector (mass account creation) as login
    # brute force.
    LIMIT = 10
    PERIOD = 15.minutes

    def self.call(email:, name:, password:, ip:)
      RateLimiter.check!("signup:ip:#{ip}", limit: LIMIT, period: PERIOD)

      User.create!(email: email, name: name, password: password)
    end
  end
end
