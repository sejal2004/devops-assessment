# syntax=docker/dockerfile:1
#########################
# 1️⃣  Build stage
#########################
FROM ruby:3.2.3-alpine AS build

# ── system deps ──────────────────────────────
RUN apk add --no-cache \
      build-base postgresql-client postgresql-dev \
      nodejs yarn tzdata bash

WORKDIR /app

# ── gems ─────────────────────────────────────
COPY Gemfile Gemfile.lock ./
ENV BUNDLE_WITHOUT="development test"
RUN bundle install --jobs 4 --retry 3

# ── js deps (if any) ────────────────────────
COPY package.json yarn.lock* ./
RUN [ -f package.json ] && yarn install --frozen-lockfile || true

# ── app source ──────────────────────────────
COPY . .

# ── assets (Sprockets) ──────────────────────
ARG SECRET_KEY_BASE=dummy1234567890dummy1234567890dummy1234567890dummy1234567890abc
ENV RAILS_ENV=production SECRET_KEY_BASE=$SECRET_KEY_BASE
RUN bundle exec rails assets:precompile

# ── make sure assets are really under public/ ─
RUN test -d public/assets || mkdir -p public/assets

#########################
# 2️⃣  Runtime stage
#########################
FROM ruby:3.2.3-alpine AS runtime
RUN apk add --no-cache postgresql-client tzdata bash

WORKDIR /app

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true

EXPOSE 3000
CMD ["bash","-c","rm -f tmp/pids/server.pid && bundle exec puma -C config/puma.rb"]
