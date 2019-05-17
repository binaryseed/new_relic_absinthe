defmodule NewRelicAbsinthe.MixProject do
  use Mix.Project

  def project do
    [
      app: :new_relic_absinthe,
      description: "New Relic Instrumentation adapter for Absinthe",
      version: "0.0.2",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      name: "New Relic Absinthe",
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Vince Foley"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/binaryseed/new_relic_absinthe"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:new_relic_agent, "~> 1.4"},
      {:absinthe, "~> 1.4"},
      {:absinthe_plug, "~> 1.4", only: :test}
    ]
  end
end
