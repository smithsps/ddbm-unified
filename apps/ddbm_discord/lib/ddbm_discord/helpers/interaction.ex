defmodule DdbmDiscord.Helpers.Interaction do
  @moduledoc """
  Helper functions for Discord interactions.
  """

  alias Nostrum.Api.Interaction

  @ephemeral_flag 64

  @doc """
  Replies to an interaction with an ephemeral message.
  """
  def reply_ephemeral(interaction, content) do
    Interaction.create_response(interaction, %{
      type: 4,
      data: %{
        content: content,
        flags: @ephemeral_flag
      }
    })
  end

  @doc """
  Replies to an interaction with an ephemeral embed.
  """
  def reply_ephemeral_embed(interaction, embed) do
    Interaction.create_response(interaction, %{
      type: 4,
      data: %{
        embeds: [embed],
        flags: @ephemeral_flag
      }
    })
  end

  @doc """
  Replies to an interaction with a public message.
  """
  def reply_public(interaction, content) do
    Interaction.create_response(interaction, %{
      type: 4,
      data: %{
        content: content
      }
    })
  end

  @doc """
  Sends a message to the configured bot notification channel.
  """
  def notify_bot_channel(_guild_id, content) do
    channel_id = Application.get_env(:ddbm_discord, :bot_channel_id)

    if channel_id do
      Nostrum.Api.Message.create(channel_id, content: content)
    else
      {:error, :no_bot_channel_configured}
    end
  end

  @doc """
  Extracts an option value from interaction data by name.
  """
  def get_option(interaction, name) do
    options = interaction.data.options || []

    case Enum.find(options, &(&1.name == name)) do
      nil -> nil
      option -> option.value
    end
  end

  @doc """
  Extracts a resolved user from interaction data.
  """
  def get_resolved_user(interaction, user_id) do
    case interaction.data.resolved do
      %{users: users} when is_map(users) ->
        Map.get(users, user_id)

      _ ->
        nil
    end
  end

  @doc """
  Gets the subcommand name from interaction options.
  """
  def get_subcommand(interaction) do
    case interaction.data.options do
      [%{type: 1, name: name} | _] -> name
      _ -> nil
    end
  end

  @doc """
  Gets options from within a subcommand.
  """
  def get_subcommand_options(interaction) do
    case interaction.data.options do
      [%{type: 1, options: options}] when is_list(options) -> options
      _ -> []
    end
  end

  @doc """
  Gets a specific option from subcommand options.
  """
  def get_subcommand_option(interaction, name) do
    options = get_subcommand_options(interaction)

    case Enum.find(options, &(&1.name == name)) do
      nil -> nil
      option -> option.value
    end
  end
end
