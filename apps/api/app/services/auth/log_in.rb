module Auth
  class LogIn
    LIMIT = 10
    PERIOD = 15.minutes

    class InvalidCredentials < StandardError; end

    def self.call(email:, password:, ip:)
      normalized_email = email.to_s.downcase.strip

      RateLimiter.check!("login:ip:#{ip}", limit: LIMIT, period: PERIOD)
      RateLimiter.check!("login:email:#{normalized_email}", limit: LIMIT, period: PERIOD)

      user = User.where(email: normalized_email).first
      raise InvalidCredentials unless user&.authenticate(password)

      user
    end
  end
end
