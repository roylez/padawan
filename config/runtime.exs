import Config

config :padawan, :mattermost,
api_url: URI.merge(System.get_env("MATTERMOST_API_URL"), "/api/v4") |> URI.to_string(),
token:   System.get_env("MATTERMOST_TOKEN")

config :padawan,
  channels: System.get_env("PADAWAN_CHANNELS")
