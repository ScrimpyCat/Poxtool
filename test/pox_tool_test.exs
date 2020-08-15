defmodule PoxToolTest do
    use ExUnit.Case
    doctest PoxTool

    defp pack_depth_header(transparent, mode), do: <<if(transparent, do: 1, else: 0) :: size(1), mode :: size(3), 0 :: size(4)>>

    defp accum(offset, size), do: <<offset :: size(4), size :: size(4)>>

    defp blocks(blocks, bits \\ <<>>)
    defp blocks([0|t], bits), do: blocks(t, <<bits :: bitstring, 0 :: size(1)>>)
    defp blocks([1|t], bits), do: blocks(t, <<bits :: bitstring, 1 :: size(1)>>)
    defp blocks([], bits), do: bits

    describe "packing" do
        test "empty" do
            assert [top: [[]], right: [[]], left: [[]], front: [[]], bottom: [[]], back: [[]]] == PoxTool.pack(%PoxTool.Poxel{})
        end

        test "mode 0" do
            options = PoxTool.all_faces(%PoxTool.Options{
                depth: { [0], 32 },
                palette: 256
            })

            opaque_header = pack_depth_header(false, 0)
            transparent_header = pack_depth_header(true, 0)

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 0, nil }, { 0, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            data = [[{ <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }]]
            assert PoxTool.all_faces(data) |> Enum.sort == [{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options) |> Enum.sort

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            data = [[{ <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }]]
            assert PoxTool.all_faces(data) |> Enum.sort == [{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options) |> Enum.sort

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 10, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            data = [[{ <<opaque_header :: bitstring, 10 :: little-size(24)>>, <<0, 0, 0, 0>> }]]
            assert PoxTool.all_faces(data) |> Enum.sort == [{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options) |> Enum.sort

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 0xffffff, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            data = [[{ <<opaque_header :: bitstring, 0xffffff :: little-size(24)>>, <<0, 0, 0, 0>> }]]
            assert PoxTool.all_faces(data) |> Enum.sort == [{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options) |> Enum.sort

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 0x1000000, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            assert catch_error([{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options))

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 0, 1 }, { 1, 0, 0, 0 }, nil },
                        { { 1, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            assert catch_error([{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options))

            face = [ #rows
                [ #pixels
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ],
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ],
                [ #pixels
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ],
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            data = [
                [{ <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }, { <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }],
                [{ <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }, { <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }]
            ]
            assert PoxTool.all_faces(data) |> Enum.sort == [{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options) |> Enum.sort

            face = [ #rows
                [ #pixels
                    [ #segments
                    ],
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ],
                [ #pixels
                    [ #segments
                        { { 0, nil }, { 1, 0, 0, 0 }, nil }
                    ],
                    [ #segments
                        { { 20, nil }, { 1, 0, 0, 0 }, nil }
                    ]
                ]
            ]
            data = [
                [{ <<transparent_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }, { <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }],
                [{ <<opaque_header :: bitstring, 0 :: little-size(24)>>, <<0, 0, 0, 0>> }, { <<opaque_header :: bitstring, 20 :: little-size(24)>>, <<0, 0, 0, 0>> }]
            ]
            assert PoxTool.all_faces(data) |> Enum.sort == [{ :__struct__, PoxTool.Poxel }|PoxTool.all_faces(face)] |> Map.new |> PoxTool.pack(options) |> Enum.sort
        end
    end
end
