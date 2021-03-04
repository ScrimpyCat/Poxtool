defmodule PoxTool.CLI do
    @moduledoc """
      PoxTool is a utility for working with poxels.

      usage:
        poxtool [command] [args]

      Commands:
      * `create` - Create a poxel.
      * `help` - Prints this message and exits.

      ### create
        poxtool create [options] FILE

      Options:
      * `--voxel`, `-v FILE` - Create from voxel input.
      * `--depth`, `-d PRECISION MODE` - Set the depth precision and mode. Defaults to finding the first usable size and mode.
      * `--depth-bits`, `-db PRECISION` - Set the depth precision. Defaults to finding the first usable size.
      * `--depth-mode`, `-dm MODES` - Set the depth mode (comma separated list of numbers). Defaults to finding the first usable mode.
      * `--size`, `-s WIDTH HEIGHT DEPTH` - Set the size of the poxel data.
      * `--shared-palette`, `-sp BOOL` - Set whether the palette should be shared or not. Defaults to finding finding the best choice.
      * `--shared-depth`, `-sd BOOL` - Set whether the depth maps should be shared or not. Defaults to finding finding the best choice.
      * `--shared-colour`, `-sc BOOL` - Set whether the colour maps should be shared or not. Defaults to finding finding the best choice.
      * `--palette`, `-p BOOL` - Set whether the colour map should use a palette or not. Defaults to finding finding the best choice.
    """

    def main(args \\ [])
    def main(["help"|_]), do: help()
    def main(["create"|args]), do: create(args)
    def main(_), do: help()

    def create(args, opts \\ [])
    def create([cmd, file|args], opts) when cmd in ["-v", "--voxel"], do: create(args, [{ :source, { :voxel, file } }|opts])
    def create([cmd, model|args], opts) when cmd in ["-m", "--model"], do: create(args, [{ :model, to_integer(model) }|opts])
    def create([cmd, precision, mode|args], opts) when cmd in ["-d", "--depth"], do: create(args, [{ :depth_bits, to_integer(precision) }, { :depth_mode, to_integer(mode) }|opts])
    def create([cmd, precision|args], opts) when cmd in ["-db", "--depth-bits"], do: create(args, [{ :depth_bits, to_integer(precision) }|opts])
    def create([cmd, mode|args], opts) when cmd in ["-dm", "--depth-mode"], do: create(args, [{ :depth_mode, to_integer_list(mode) }|opts])
    def create([cmd, width, height, depth|args], opts) when cmd in ["-s", "--size"], do: create(args, [{ :size, { to_integer(width), to_integer(height), to_integer(depth) } }|opts])
    def create([cmd, shared|args], opts) when cmd in ["-sp", "--shared-palette"], do: create(args, [{ :shared_palette, to_boolean(shared) }|opts])
    def create([cmd, shared|args], opts) when cmd in ["-sd", "--shared-depth"], do: create(args, [{ :shared_depth, to_boolean(shared) }|opts])
    def create([cmd, shared|args], opts) when cmd in ["-sc", "--shared-colour"], do: create(args, [{ :shared_colour, to_boolean(shared) }|opts])
    def create([cmd, palette|args], opts) when cmd in ["-p", "--palette"], do: create(args, [{ :palette, to_boolean(palette) }|opts])
    def create([file], opts) do
        case opts[:source] do
            { :voxel, file } ->
                file
                |> File.read!
                |> Vox.new
                |> Vox.transform(:left, :bottom, :front)
                |> PoxTool.Voxel.to_poxel(opts)
            nil ->
                { w, h, d } = opts[:size] || { 64, 64, 64 }
                face_front = Enum.map(1..h, fn _ -> Enum.map(1..w, fn _ -> [{ { 1, nil }, { 0.0, 0.0, 0.0, 1.0 }, :diffuse }] end) end)
                face_left = Enum.map(1..h, fn _ -> Enum.map(1..d, fn _ -> [{ { 1, nil }, { 0.0, 0.0, 0.0, 1.0 }, :diffuse }] end) end)
                face_bottom = Enum.map(1..d, fn _ -> Enum.map(1..w, fn _ -> [{ { 1, nil }, { 0.0, 0.0, 0.0, 1.0 }, :diffuse }] end) end)
                %PoxTool.Poxel{
                    front: face_front,
                    back: face_front,
                    left: face_left,
                    right: face_left,
                    bottom: face_bottom,
                    top: face_bottom
                }
        end
        |> PoxTool.create(file, opts)
    end
    def create(_, _), do: help()

    defp help(), do: get_docs() |> SimpleMarkdown.convert(render: &SimpleMarkdownExtensionCLI.Formatter.format/1) |> IO.puts

    defp get_docs() do
        if Version.match?(System.version, "> 1.7.0") do
            { :docs_v1, _, :elixir, "text/markdown", %{ "en" => doc }, _, _ } = Code.fetch_docs(__MODULE__)
            doc
        else
            { _, doc } = Code.get_docs(__MODULE__, :moduledoc)
            doc
        end
    end

    defp to_boolean(value) when value in ["true", "TRUE", "1", "yes", "YES", "y", "Y"], do: true
    defp to_boolean(_), do: false

    defp to_integer(value) do
        { value, _ } = Integer.parse(value)
        value
    end

    defp to_integer_list(value), do: value |> String.split(",") |> Enum.map(&to_integer/1)
end
