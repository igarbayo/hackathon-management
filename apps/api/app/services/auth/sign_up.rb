module Auth
  class SignUp
    def self.call(email:, name:, password:)
      User.create!(email: email, name: name, password: password)
    end
  end
end
