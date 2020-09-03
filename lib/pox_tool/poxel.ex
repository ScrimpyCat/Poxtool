defmodule PoxTool.Poxel do
    defstruct [
        front: [],
        back: [],
        left: [],
        right: [],
        bottom: [],
        top: []
    ]

    @type colour :: { red :: float, green :: float, blue :: float, alpha :: float }
    @type material :: atom
    @type depth_range :: { non_neg_integer, pos_integer | nil }
    @type chunk :: { depth_range, colour, material }
    @type row :: [chunk]
    @type face :: [row]
    @type t :: %__MODULE__{
        front: face,
        back: face,
        left: face,
        right: face,
        bottom: face,
        top: face
    }
    @type palette :: %{ colour => non_neg_integer }

    @spec size(t) :: { width :: non_neg_integer, height :: non_neg_integer, depth :: non_neg_integer }
    def size(%{ front: front, left: left }) do
        { w, h } = face_size(front)
        { d, ^h } = face_size(left)
        { w, h, d }
    end

    @spec face_size(face) :: { width :: non_neg_integer, height :: non_neg_integer }
    def face_size([]), do: { 0, 0 }
    def face_size(face = [row|_]), do: { Enum.count(row), Enum.count(face) }

    @spec palette(t, map) :: palette
    def palette(poxel, palette \\ %{}) do
        poxel
        |> Map.from_struct
        |> Enum.reduce(%{}, fn { _, face }, palette ->
            face_palette(face, palette)
        end)
    end

    @spec face_palette(face, map) :: palette
    def face_palette(face, palette \\ %{}) do
        face_map(face, palette, &(&1), fn result, _ -> result end, &(&1), fn { _, colour, _ }, acc ->
            Map.put_new(acc, colour, map_size(acc))
        end)
    end

    @spec face_map(face, any, (acc :: any -> any), (result :: any, acc :: any -> any), (acc :: any -> any), (chunk, acc :: any -> any)) :: any
    def face_map(face, acc, row_init, row_merge, seg_init, seg_map) do
        Enum.reduce(face, acc, fn row, acc ->
            Enum.reduce(row, row_init.(acc), fn segment, acc ->
                row_merge.(Enum.reduce(segment, seg_init.(acc), seg_map), acc)
            end)
        end)
    end
end
