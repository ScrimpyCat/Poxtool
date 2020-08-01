defmodule PoxTool.Voxel do
    @spec to_poxel(Vox.Data.t) :: PoxTool.Poxel.t
    def to_poxel(voxel) do
        %PoxTool.Poxel{
            front: Vox.transform(voxel, :left, :top, :front) |> Vox.model(0) |> get_face,
            back: Vox.transform(voxel, :right, :top, :back) |> Vox.model(0) |> get_face,
            left: Vox.transform(voxel, :back, :top, :left) |> Vox.model(0) |> get_face,
            right: Vox.transform(voxel, :front, :top, :right) |> Vox.model(0) |> get_face,
            bottom: Vox.transform(voxel, :left, :front, :bottom) |> Vox.model(0) |> get_face,
            top: Vox.transform(voxel, :left, :back, :top) |> Vox.model(0) |> get_face
        }
    end

    defp get_face(model = %{ size: { width, height, depth } }) do
        Enum.map(1..height, &get_row(model, width, depth, &1 - 1))
    end

    defp get_row(model, width, depth, n) do
        Enum.map(1..width, &get_depth(model, depth, &1 - 1, n))
    end

    defp get_depth(model, depth, x, y, z \\ 0, poxels \\ [])
    defp get_depth(_, depth, _, _, z, poxels) when z >= depth , do: Enum.reverse(poxels)
    defp get_depth(model, depth, x, y, z, [poxel = { { p, nil }, c = { r, g, b, a }, m }|poxels]) do
        poxels = case Vox.Model.voxel!(model, x, y, z) do
            nil -> [{ { p, z - p }, c, m }|poxels]
            %{ colour: %{ r: ^r, g: ^g, b: ^b, a: ^a }, material: %{ type: ^m } } -> [poxel|poxels]
            voxel -> [{ { z, nil }, colour(voxel), material(voxel) }, { { p, z - p }, c, m }|poxels]
        end

        get_depth(model, depth, x, y, z + 1, poxels)
    end
    defp get_depth(model, depth, x, y, z, poxels) do
        poxels = case Vox.Model.voxel!(model, x, y, z) do
            nil -> poxels
            voxel -> [{ { z, nil }, colour(voxel), material(voxel) }|poxels]
        end

        get_depth(model, depth, x, y, z + 1, poxels)
    end

    defp colour(%{ colour: %{ r: r, g: g, b: b, a: a } }), do: { r, g, b, a }

    defp material(%{ material: %{ type: type } }), do: type
end
