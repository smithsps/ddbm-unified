defmodule Ddbm.Tokens.Token do
  @moduledoc """
  Defines token types and their rate limits.
  """

  defstruct [:id, :name, :plural, :limits]

  @type limit :: %{daily: non_neg_integer() | nil, weekly: non_neg_integer() | nil}
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          plural: String.t(),
          limits: limit()
        }

  @doc """
  Returns all defined tokens.
  """
  @spec all() :: [t()]
  def all do
    [
      %__MODULE__{
        id: "carry",
        name: "⚔️ Carry token",
        plural: "⚔️ Carry tokens",
        limits: %{daily: 3, weekly: nil}
      },
      %__MODULE__{
        id: "leader",
        name: "👑 Leader token",
        plural: "👑 Leader tokens",
        limits: %{daily: 1, weekly: 3}
      },
      %__MODULE__{
        id: "streamer",
        name: "📺 Streamer token",
        plural: "📺 Streamer tokens",
        limits: %{daily: 3, weekly: nil}
      },
      %__MODULE__{
        id: "toxic",
        name: "☣ Toxic token",
        plural: "☣ Toxic tokens",
        limits: %{daily: 1, weekly: 3}
      }
    ]
  end

  @doc """
  Returns a token by its ID, or nil if not found.
  """
  @spec get(String.t()) :: t() | nil
  def get(id) do
    Enum.find(all(), &(&1.id == id))
  end

  @doc """
  Returns the display name for the given amount.
  """
  @spec display_name(t(), integer()) :: String.t()
  def display_name(token, 1), do: token.name
  def display_name(token, _amount), do: token.plural

  @doc """
  Returns token choices for Discord command options.
  Format: [{name, value}, ...]
  """
  @spec choices() :: [{String.t(), String.t()}]
  def choices do
    Enum.map(all(), &{&1.name, &1.id})
  end
end
