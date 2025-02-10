defmodule Ant.MixProject do
  use Mix.Project

  def project do
    [
      app: :ant,
      package: package(),
      name: "Ant",
      description: "Background job processing library for Elixir focused on simplicity",
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [
          :ex_unit,
          :mix
        ],
        plt_add_deps: :apps_direct,
        plt_file: {:no_warn, "priv/plts/ant.plt"},
        plt_local_path: "priv/plts/ant.plt",
        plt_core_path: "priv/plts/core"
      ],
      version: "0.0.4",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Ant.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mimic, "~> 1.10", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/MikeAndrianov/ant"}
    ]
  end
end
