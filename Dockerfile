ARG APP=padawan
ARG ELIXIR=1.11.1
ARG ERLANG=22.3.4.7
ARG ALPINE=3.12

FROM hexpm/elixir:${ELIXIR}-erlang-${ERLANG}-alpine-${ALPINE}.0 as builder

RUN apk update
RUN apk add build-base git libtool autoconf automake
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

WORKDIR /app
ENV MIX_ENV=prod
ADD . .

RUN mix deps.get
RUN mix release

# ==============================================

FROM alpine:${ALPINE}

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

RUN apk update --no-cache && \
    apk add --no-cache bash libssl1.1 ncurses-libs

WORKDIR /app

RUN addgroup -S ${APP} && adduser -S ${APP} -G ${APP} -h /app
USER ${APP}

COPY --chown=${APP}:${APP} --from=builder /app/_build/prod/rel/${APP} .

CMD ["./bin/${APP}", "start" ]
