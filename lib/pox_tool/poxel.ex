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
end
