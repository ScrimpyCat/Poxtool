defmodule PoxTool.Mixfile do
    use Mix.Project

    def project do
        [
            app: :poxtool,
            description: "A utility for working with Poxels",
            version: "0.1.0",
            elixir: "~> 1.7",
            start_permanent: Mix.env == :prod,
            deps: deps(),
            package: package(),
            escript: escript(),
            dialyzer: [plt_add_deps: :transitive]
        ]
    end

    # Run "mix help compile.app" to learn about applications.
    def application do
        [extra_applications: [:logger]]
    end

    # Run "mix help deps" to learn about dependencies.
    defp deps do
        [
            { :vox, github: "ScrimpyCat/Vox" },
            { :png, "~> 0.2.1" },
            { :itsy, "~> 0.0.4" },
            { :simple_markdown, "~> 0.6" },
            { :simple_markdown_extension_cli, "~> 0.1.3" },
            { :ex_doc, "~> 0.18", only: :dev }
        ]
    end

    defp package do
        [
            maintainers: ["Stefan Johnson"],
            licenses: ["BSD 2-Clause"],
            links: %{ "GitHub" => "https://github.com/ScrimpyCat/Poxtool" }
        ]
    end

    defp escript do
        [
            main_module: PoxTool.CLI,
            strip_beam: false
        ]
    end
end
