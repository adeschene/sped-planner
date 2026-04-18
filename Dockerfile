FROM ruby:3.2-slim

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    libyaml-dev \
    git \
    pkg-config

WORKDIR /app

RUN bundle config set --local without 'development test'

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# 1. Remove Windows line endings (\r) from all binaries
RUN sed -i 's/\r$//' bin/*

# 2. Specifically fix the ruby.exe path in the rails stub
RUN sed -i '1s/ruby.exe/ruby/' bin/rails

RUN chmod +x bin/*

ENV RAILS_ENV=production

# Rails 7.1+ built-in dummy key flag for asset compilation
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
