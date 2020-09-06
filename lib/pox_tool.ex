defmodule PoxTool do
    defmodule Options do
        defstruct [
            palette: 256,
            depth: { [0, 1, 2, 3, 4, 5, 6, 7], 128 }

        ]

        @type palette_size :: 4 | 16 | 256
        @type depth_mode :: 0..7
        @type depth_bits :: 32 | 128
        @type t :: %__MODULE__{
            palette: nil | palette_size,
            depth: { [depth_mode], depth_bits }
        }
    end

    @type packed_pixel :: { depth :: binary, colour :: binary }
    @type packed_row :: [packed_pixel]
    @type packed_face :: [packed_row]
    @type face :: :left | :right | :bottom | :top | :front | :back

    @spec all_faces(value :: term) :: [{ face, value :: term }]
    def all_faces(value), do: [left: value, right: value, bottom: value, top: value, front: value, back: value]

    @spec pack(PoxTool.Poxel.t, keyword(PoxTool.Options.t)) :: [{ face, packed_face }]
    def pack(poxel = %PoxTool.Poxel{}, opts \\ []), do: Map.from_struct(poxel) |> Enum.map(fn { name, face } -> { name, prepare_face(face, opts[:palette] || %{}) } end) |> pack_face([{ :size, PoxTool.Poxel.size(poxel) }|opts])

    @tab "    "
    def save(packed_poxel, { width, height, depth }, path, palettes \\ []) do
        File.mkdir(path)
        poxel_name = path |> Path.basename |> Path.rootname

        palettes = case palettes do
            nil -> []
            palettes when is_list(palettes) ->
                Enum.map(palettes, fn { name, { palette, size } } ->
                    palette_name = [poxel_name, ?-, to_string(name), "-palette"]
                    palette_dir = [to_string(name), "-palette.png"]
                    save_palette(palette, path, palette_dir, size)

                    { name, { palette_name, palette_dir } }
                end)
            { palette, size } ->
                palette_name = [poxel_name, "-palette"]
                palette_dir = ["palette.png"]
                save_palette(palette, path, palette_dir, size)

                all_faces({ palette_name, palette_dir })
        end

        blob = [
            ~s[(poxel "], poxel_name, ~s["\n],
            @tab, ~s[(size: ], to_string(width), ?\s, to_string(height), ?\s, to_string(depth), ~s[)\n],
            Enum.reduce(packed_poxel, [], fn { name, face }, acc ->
                blob = [save_face(face, path, name, poxel_name), @tab, ")\n"]

                blob = case palettes[name] do
                    nil -> blob
                    { palette_name, palette_dir } -> [[@tab, @tab, ~s[(palette: (texture "], palette_name, ~s[" :nearest (dir: "], palette_dir, ~s[") (stream: "palette")))\n]]|blob]
                end

                [[@tab, ?(, to_string(name), ":\n"|blob]|acc]
            end),
            ?)
        ]

        File.write!(Path.join(path, poxel_name <> ".poxel"), blob)
    end

    defp save_palette(palette, path, palette_dir, size) do
        count = map_size(palette)
        fill = (size - count) * 8 * 4

        file = File.open!(Path.join(path, palette_dir), [:write])
        png = :png.create(%{ size: { size, 1 }, mode: { :rgba, 8 }, file: file })
        :png.append(png, { :row, (palette |> Enum.sort(fn { _, a }, { _, b } -> a < b end) |> Enum.map(fn { { r, g, b, a }, _ } -> <<round(r * 255) :: size(8), round(g * 255) :: size(8), round(b * 255) :: size(8), round(a * 255) :: size(8)>> end) |> Enum.into(<<>>)) <> <<0 :: size(fill)>> })
        :ok = :png.close(png)
        :ok = File.close(file)
    end

    defp save_face(face, path, name, poxel_name) do
        size = PoxTool.Poxel.face_size(face)

        { depth_bits, colour_bits } = packed_bit_size(face)
        depth_format = pixel_format(depth_bits)
        colour_format = pixel_format(depth_bits)

        file = File.open!(Path.join(path, "#{name}-depth.png"), [:write])
        png = :png.create(%{ size: size, mode: depth_format, file: file })
        Enum.each(face, fn row ->
            :png.append(png, { :row, Enum.map(row, &elem(&1, 0)) |> Enum.into(<<>>) })
        end)
        :ok = :png.close(png)
        :ok = File.close(file)

        file = File.open!(Path.join(path, "#{name}-colour.png"), [:write])
        png = :png.create(%{ size: size, mode: colour_format, file: file })
        Enum.each(face, fn row ->
            :png.append(png, { :row, Enum.map(row, &elem(&1, 1)) |> Enum.into(<<>>) })
        end)
        :ok = :png.close(png)
        :ok = File.close(file)

        [
            [@tab, @tab, ~s[(depth: (texture "], poxel_name, ?-, to_string(name), ~s[-depth" :nearest (dir: "], to_string(name), ~s[-depth.png") (stream: "depth32")))\n]],
            [@tab, @tab, ~s[(colour: (texture "], poxel_name, ?-, to_string(name), ~s[-colour" :nearest (dir: "], to_string(name), ~s[-colour.png") (stream: "colour], to_string(colour_bits), ~s[")))\n]]
        ]
    end

    defp pixel_format(8), do: { :grayscale, 8 }
    defp pixel_format(32), do: { :rgba, 8 }
    defp pixel_format(64), do: { :rgba, 16 }
    defp pixel_format(128), do: { :rgba, 32 }

    defp packed_bit_size([]), do: { 0, 0 }
    defp packed_bit_size([[{ depth, colour }|_]|t]), do: { bit_size(depth), bit_size(colour) }
    defp packed_bit_size([_|t]), do: packed_bit_size(t)

    defp pack_face(faces, opts, packed \\ [])
    defp pack_face([{ name, { palette, max_blocks, max_depth, rows } }|faces], opts, packed) do
        options = opts[name] || %PoxTool.Options{}
        size = case { name, opts[:size] } do
            { face, { x, _, _ } } when face in [:left, :right]  -> x
            { face, { _, y, _ } } when face in [:bottom, :top]  -> y
            { face, { _, _, z } } when face in [:front, :back]  -> z
        end
        rows = Enum.map(rows, fn row ->
            Enum.map(row, fn segments ->
                { depth, colour } = pack_pixel(options.palette, segments, options.depth, size)
                { _, size } = options.depth

                { pad(depth, size), pack_palette(colour, size) |> pad(size) }
            end)
        end)

        pack_face(faces, opts, [{ name, rows }|packed])
    end
    defp pack_face([], _, packed), do: packed

    defp pack_depth_header(transparent, mode \\ 0), do: <<if(transparent, do: 1, else: 0) :: size(1), mode :: size(3), 0 :: size(4)>>

    defp pack_depth32_single(depth), do: <<depth :: little-size(24)>>

    defp pack_depth_accum(pixel, size, palette, acc \\ { <<>>, <<>> }, n \\ 0)
    defp pack_depth_accum([{ { depth, length }, index, _ }|segments], size, palette, { dacc, pacc }, n) when (depth - n) <= 0xf and length <= 0xf do
        pack_depth_accum(segments, size, palette, { <<dacc :: bitstring, (depth - n) :: size(4), length :: size(4)>>, <<pacc :: bitstring, pack_palette_index(index, palette) :: bitstring>> }, depth + length)
    end
    defp pack_depth_accum([{ { depth, nil }, index, material }], size, palette, acc, n), do: pack_depth_accum([{ { depth, size - depth }, index, material }], size, palette, acc, n)
    defp pack_depth_accum([], _, _, acc, _), do: acc
    #TODO: handle when length > 0xf (breaks it up over multiple chunks)

    defp pack_depth_blocks(pixel, size, palette, acc \\ { <<>>, <<>> }, n \\ 0)
    defp pack_depth_blocks([{ { _, 0 }, _, _ }|segments], size, palette, acc, n) do
        pack_depth_blocks(segments, size, palette, acc, n)
    end
    defp pack_depth_blocks([{ { depth, nil }, index, material }], size, palette, acc, n) when depth <= n do
        pack_depth_blocks([{ { depth, size - n }, index, material }], size, palette, acc, n)
    end
    defp pack_depth_blocks([{ { depth, length }, index, material }|segments], size, palette, { dacc, pacc }, n) when depth <= n do
        pack_depth_blocks([{ { depth + 1, length - 1 }, index, material }|segments], size, palette, { <<dacc :: bitstring, 1 :: size(1)>>, <<pacc :: bitstring, pack_palette_index(index, palette) :: bitstring>> }, n + 1)
    end
    defp pack_depth_blocks(segments = [_|_], size, palette, { dacc, pacc }, n) when n < size do
        pack_depth_blocks(segments, size, palette, { <<dacc :: bitstring, 0 :: size(1)>>, <<pacc :: bitstring, pack_palette_index(0, palette) :: bitstring>> }, n + 1)
    end
    defp pack_depth_blocks([], size, palette, acc, _), do: acc

    defp pack_palette_index(index, size) when index < size do
        bits = size |> Itsy.Bit.mask_lower_power_of_2 |> Itsy.Bit.count
        <<index :: size(bits)>>
    end

    defp pack_palette(palette, size) when bit_size(palette) < size, do: palette
    defp pack_palette(palette, size) do
        <<sequence :: bitstring-size(size), excess :: bitstring>> = palette
        true = packed_palette_repeats?(sequence, excess) # TODO: throw custom exception

        sequence
    end

    defp packed_palette_repeats?(sequence, palette) do
        size = bit_size(sequence)
        case palette do
            <<^sequence :: bitstring-size(size), excess :: bitstring>> -> packed_palette_repeats?(sequence, excess)
            palette when bit_size(palette) < bit_size(sequence) ->
                size = bit_size(palette)
                case sequence do
                    <<^palette :: bitstring-size(size), _ :: bitstring>> -> true
                    _ -> false
                end
            _ -> false
        end
    end

    defp pad(bits, size, fill \\ 0) do
        size = size - bit_size(bits)
        <<bits :: bitstring, fill :: size(size)>>
    end

    defp pack_pixel(_, [], { _, 32 }, _) do
        { <<pack_depth_header(true) :: bitstring, pack_depth32_single(0) :: bitstring>>, <<>> }
    end
    defp pack_pixel(palette, [{ { depth, nil }, index, _ }], { [mode|modes], 32 }, _) when mode in [0, 3] and depth <= 0xffffff do
        { <<pack_depth_header(false, mode) :: bitstring, pack_depth32_single(depth) :: bitstring>>, pack_palette_index(index, palette) }
    end
    defp pack_pixel(palette, pixel, { [mode|modes], bits }, size) when mode in [1, 4] do
        { depth, colour } = pack_depth_accum(pixel, size, palette)
        if bit_size(depth) <= (bits - 8) do
            { <<pack_depth_header(false, mode) :: bitstring, depth :: bitstring>>, colour }
        else
            pack_pixel(palette, pixel, { modes, bits }, size)
        end
    end
    defp pack_pixel(palette, pixel, { [mode|modes], bits }, size) when mode in [2, 5] do
        { depth, colour } = pack_depth_blocks(pixel, size, palette)
        if bit_size(depth) <= (bits - 8) do
            { <<pack_depth_header(false, mode) :: bitstring, depth :: bitstring>>, colour }
        else
            pack_pixel(palette, pixel, { modes, bits }, size)
        end
    end
    defp pack_pixel(palette, pixels, { [_|modes], bits }, size), do: pack_pixel(palette, pixels, { modes, bits }, size)

    def prepare_face(face, palette \\ %{}) do
        { palette, max_blocks, max_depth, row, rows, _ } = PoxTool.Poxel.face_map(face, { palette, 0, 0, [], [], 0 }, fn
            acc = { _, _, _, _, _, 0 } -> acc
            { palette, n, d, row, rows, c } -> { palette, n, d, [], [Enum.reverse(row)|rows], c }
        end, fn { palette, indexes }, { _, n, d, row, rows, c } ->
            d = case indexes do
                [{ { s, nil }, _, _ }|_] -> max(d, s)
                [{ { s, l }, _, _ }|_] -> max(d, s + l)
                _ -> d
            end
            indexes = Enum.reverse(indexes)
            { palette, max(MapSet.new(indexes) |> MapSet.size, n), d, [indexes|row], rows, c + 1 }
        end, fn { palette, _, _, _, _, _ } -> { palette, [] } end, fn { range, colour, material }, { palette, indexes } ->
            palette = Map.put_new(palette, colour, map_size(palette))
            { palette, [{ range, palette[colour], material }|indexes] }
        end)

        { palette, max_blocks, max_depth, Enum.reverse([Enum.reverse(row)|rows]) }
    end

    defp get_palette(poxel, face, shared, palette \\ nil)
    defp get_palette(poxel, face, _, nil), do: PoxTool.Poxel.prepare_face(poxel[face])
    defp get_palette(poxel, face, false, _), do: PoxTool.Poxel.prepare_face(poxel[face])
    defp get_palette(poxel, face, _, palette) do
        case PoxTool.Poxel.prepare_face(poxel[face], palette) do
            palette when map_size(palette) <= 256 -> palette
            _ -> PoxTool.Poxel.prepare_face(poxel[face])
        end
    end

    defp max_segments(faces, max \\ 0)
    defp max_segments([{ _, { _, segments, _, _ } }|faces], max), do: max_segments(faces, max(max, segments))
    defp max_segments([], max), do: max

    defp max_palettes(faces, max \\ 0)
    defp max_palettes([{ _, { palette, _, _, _ } }|faces], max), do: max_palettes(faces, map_size(palette))
    defp max_palettes([], max), do: max

    defp max_shared_palettes(faces, merged \\ %{})
    defp max_shared_palettes([{ _, { palette, _, _, _ } }|faces], merged), do: max_shared_palettes(faces, Map.merge(merged, palette))
    defp max_shared_palettes([], merged), do: map_size(merged)

    defp exceeds_palette_limit?([{ _, { palette, _, _, _ } }|_]) when map_size(palette) > 256, do: true
    defp exceeds_palette_limit?([_|faces]), do: exceeds_palette_limit?(faces)
    defp exceeds_palette_limit?([]), do: false

    defp exceeds_depth_limit?([{ _, { _, segments, depth, _ } }|faces], 32, 0) when (segments <= 1) and (depth <= 0xffffff), do: exceeds_depth_limit?(faces, 32, 0)
    defp exceeds_depth_limit?([{ _, { _, segments, depth, _ } }|faces], 32, 1) when (segments <= 3) and (depth <= 90), do: exceeds_depth_limit?(faces, 32, 1)
    defp exceeds_depth_limit?([{ _, { _, segments, depth, _ } }|faces], 32, 2) when (segments <= 24) and (depth <= 24), do: exceeds_depth_limit?(faces, 32, 2)
    # defp exceeds_depth_limit?([{ _, { _, segments, depth, _ } }|faces], 128, 0) when (segments <= 1) and (depth <= 0xffffff), do: exceeds_depth_limit?(faces, 128, 0)
    # defp exceeds_depth_limit?([{ _, { _, segments, depth, _ } }|faces], 128, 1) when (segments <= 3) and (depth <= 90), do: exceeds_depth_limit?(faces, 128, 1)
    # defp exceeds_depth_limit?([{ _, { _, segments, depth, _ } }|faces], 128, 2) when (segments <= 24) and (depth <= 24), do: exceeds_depth_limit?(faces, 128, 2)
    defp exceeds_depth_limit?([], _, _), do: false
    defp exceeds_depth_limit?(faces, bits, mode) when mode in [3, 4, 5], do: exceeds_depth_limit?(faces, bits, mode - 3)
    defp exceeds_depth_limit?(_, _, mode) when mode in [6, 7], do: false
    defp exceeds_depth_limit?(faces, bits, nil), do: exceeds_depth_limit?(faces, bits, Enum.to_list(0..7))
    defp exceeds_depth_limit?(faces, bits, modes) when is_list(modes), do: Enum.all?(modes, &exceeds_depth_limit?(faces, bits, &1))
    defp exceeds_depth_limit?(_, _, _), do: true
end
