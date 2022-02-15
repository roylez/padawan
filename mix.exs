defmodule Padawan.MixProject do
  use Mix.Project

  def project do
    [
      app: :padawan,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [exclude: Luerl],
      releases: releases(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Padawan.Application, []}
    ]
  end

  defp releases do
    [
      padawan: [
        steps: [&copy_files/1, :assemble]
      ]
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

  @overlay_files ~w(lua)

  # copy to rel/overlays/
  defp copy_files(rel) do
    IO.puts "* copying extra files into release ..."
    for file <- @overlay_files do
      IO.puts "* ........................ #{file}"
      File.cp_r!(file, "rel/overlays/" <> file)
    end
    rel
  end
end
