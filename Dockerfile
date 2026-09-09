FROM ruby:3.3-slim-bookworm AS base
WORKDIR /app
ENV BUNDLE_PATH=/usr/local/bundle BUNDLE_FROZEN=true
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 libvips42 fonts-wqy-microhei ca-certificates curl && rm -rf /var/lib/apt/lists/*

FROM base AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libyaml-dev pkg-config git && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.20 --no-document && bundle install --jobs 4 --retry 3
COPY . .
RUN bundle exec rails assets:precompile

FROM base
RUN groupadd --gid 1000 museum && useradd --uid 1000 --gid 1000 --create-home museum
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=museum:museum /app /app
RUN chmod +x /app/bin/* && mkdir -p /app/storage/media /app/tmp/pids /app/log && chown -R museum:museum /app/storage /app/tmp /app/log
USER museum
EXPOSE 3000
ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
