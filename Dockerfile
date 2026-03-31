# syntax = docker/dockerfile:1

# 1. Base image with Ruby
ARG RUBY_VERSION=3.2.2
FROM ruby:$RUBY_VERSION-slim as base

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libvips postgresql-client nodejs npm \
    shared-mime-info libsqlite3-dev && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. Build stage (Install gems and assets)
FROM base as build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    pkg-config \
    python3 \
    python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

# This forces every Ruby process to require the logger automatically
ENV RUBYOPT="-rlogger -rpsych"

# Tells Node 18 to allow the legacy hashing algorithms Webpacker 5 needs
ENV NODE_OPTIONS=--openssl-legacy-provider

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# 3. Final production image
FROM base

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Create a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000

# Start the server by default, binding to all interfaces
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
