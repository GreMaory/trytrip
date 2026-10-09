# syntax=docker/dockerfile:1
# Development image (production uses ../Dockerfile).
# Keep RUBY_VERSION in sync with .ruby-version and BUNDLER_VERSION with Gemfile.lock.
ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim

ARG BUNDLER_VERSION=4.0.11

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libpq-dev postgresql-client build-essential git curl libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH="/usr/local/bundle" \
    RAILS_ENV=development

RUN gem install bundler -v "${BUNDLER_VERSION}"

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
