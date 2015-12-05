defmodule Feedme.Mixfile do
  use Mix.Project

  def project do
    [app: :feedme,
     version: "0.0.1",
     elixir: "~> 1.0",
     description: "Elixir RSS/Atom parser built on erlang's xmerl xml parser",
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :tzdata, :fast_xml]]
  end

  # Describe Hex.pm package
  def package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/umurgdk/elixir-feedme"}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:mix_test_watch, "~> 0.2", only: :test},
      {:mock, "~> 0.1.1", only: :test},
      {:timex, "~> 1.0.0-rc3"},
      {:fast_xml, "~> 1.1"}
    ]
  end
end
