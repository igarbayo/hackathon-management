FROM ruby:3.3

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3001

CMD ["bin/rails", "server", "-p", "3001", "-b", "0.0.0.0"]
