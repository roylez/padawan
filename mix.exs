defmodule Padawan.MixProject do
  use Mix.Project

  def project do
    [
      app: :padawan,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [exclude: Luerl]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Padawan.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cachex, "~> 3.3"},
      {:tesla, "~> 1.4.0"},
      {:jason, ">= 1.0.0"},
      {:hackney, "~> 1.17"},
      {:websockex, "~> 0.4"},
      {:luerl, git: "https://github.com/rvirding/luerl", branch: "develop"},
    ]
  end
end
