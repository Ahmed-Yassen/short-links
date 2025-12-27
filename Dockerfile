# syntax = docker/dockerfile:1

# 1. Base Image: Use the Ruby version matching your Gemfile
ARG RUBY_VERSION=3.2.2
FROM ruby:$RUBY_VERSION-slim

# 2. Install System Dependencies
# libpq-dev: Required for PostgreSQL
# build-essential: Required to compile Ruby gems
# curl: Useful for health checks
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 3. Setup Working Directory
WORKDIR /rails

# 4. Install Gems
# Copy Gemfile first to leverage Docker cache
COPY Gemfile Gemfile.lock ./
RUN bundle install

# 5. Copy Application Code
COPY . .

# 6. Add Entrypoint Script
# Fixes "server.pid already exists" issues
COPY bin/docker-entrypoint /rails/bin/
RUN chmod +x /rails/bin/docker-entrypoint

# 7. Start Server
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]