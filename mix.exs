defmodule CowboyTelemetry.MixProject do
  use Mix.Project

  def project() do
    [
      app: :cowboy_telemetry,
      version: "1.0.0",
      language: :erlang,
      deps: [
        {:cowboy, github: "wojtekmach/cowboy", branch: "wm-elixir-run"},
        {:telemetry, github: "wojtekmach/telemetry", branch: "wm-elixir-run"}
      ]
    ]
  end
end
