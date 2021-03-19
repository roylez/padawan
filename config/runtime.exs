import Config

config :logger, :console,
metadata: [:channel],
level: :debug,
handle_sasl_reports: config_env() == :dev
