defmodule DdbmDiscord.Commands.Token do
  @moduledoc """
  Handles the /token command with check and leaderboard subcommands.
  """

  alias Ddbm.Tokens
  alias Ddbm.Tokens.Token
  alias DdbmDiscord.Helpers.Interaction, as: Helper

  @gold_color 0xFFD700

  def execute(interaction) do
    case Helper.get_subcommand(interaction) do
      "check" -> check(interaction)
      "leaderboard" -> leaderboard(interaction)
      _ -> Helper.reply_ephemeral(interaction, "Unknown subcommand.")
    end
  end

  defp check(interaction) do
    user_id = to_string(interaction.member.user_id)
    balances = Tokens.get_user_balances(user_id)

    results =
      Token.all()
      |> Enum.map(fn token ->
        amount = Map.get(balances, token.id, 0)
        "You have #{amount} #{Token.display_name(token, amount)}."
      end)
      |> Enum.join("\n")

    Helper.reply_ephemeral(interaction, results)
  end

  defp leaderboard(interaction) do
    target_token = Helper.get_subcommand_option(interaction, "token")

    embed =
      if target_token do
        single_token_leaderboard(target_token)
      else
        all_tokens_leaderboard()
      end

    Helper.reply_ephemeral_embed(interaction, embed)
  end

  defp all_tokens_leaderboard do
    fields =
      Token.all()
      |> Enum.flat_map(fn token ->
        totals = Tokens.get_token_totals(token.id)

        if Enum.any?(totals) do
          [
            %{name: "\u200B", value: token.name, inline: false}
            | leaderboard_fields(totals, 3)
          ]
        else
          []
        end
      end)

    %{
      title: "Token Leaderboard",
      color: @gold_color,
      fields: fields
    }
  end

  defp single_token_leaderboard(token_id) do
    token = Token.get(token_id)
    totals = Tokens.get_token_totals(token_id)

    title =
      token.name
      |> String.replace(" token", "")

    %{
      title: "#{title} Leaderboard",
      color: @gold_color,
      fields: leaderboard_fields(totals, 10)
    }
  end

  defp leaderboard_fields(totals, limit) do
    entries = Enum.take(totals, limit)

    positions =
      entries
      |> Enum.with_index(1)
      |> Enum.map(fn {_, idx} -> "#{idx}" end)
      |> Enum.join("\n")

    names =
      entries
      |> Enum.map(fn {user_id, _total} -> "<@#{user_id}>" end)
      |> Enum.join("\n")

    token_totals =
      entries
      |> Enum.map(fn {_user_id, total} -> "#{total}" end)
      |> Enum.join("\n")

    [
      %{name: "#", value: positions, inline: true},
      %{name: "Name", value: names, inline: true},
      %{name: "Tokens", value: token_totals, inline: true}
    ]
  end
end
