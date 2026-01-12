defmodule DdbmDiscord.Commands.TokenAdmin do
  @moduledoc """
  Handles the /token-admin command for administrators.
  """

  alias Ddbm.Tokens
  alias DdbmDiscord.Helpers.Interaction, as: Helper

  def execute(interaction) do
    case Helper.get_subcommand(interaction) do
      "list" -> list_transactions(interaction)
      _ -> Helper.reply_ephemeral(interaction, "Unknown subcommand.")
    end
  end

  defp list_transactions(interaction) do
    target_user_id = Helper.get_subcommand_option(interaction, "user")

    if target_user_id do
      transactions =
        target_user_id
        |> to_string()
        |> Tokens.get_transactions_by_user()
        |> Enum.take(20)

      if Enum.empty?(transactions) do
        Helper.reply_ephemeral(interaction, "Tokens Log:\nNo transactions found for user.")
      else
        lines =
          transactions
          |> Enum.map(fn t ->
            date = Calendar.strftime(t.inserted_at, "%Y/%m/%d %I:%M:%S %p")
            "[#{date}] <@#{t.sender_user_id}> => #{t.amount} #{t.token} => <@#{t.user_id}>"
          end)

        result = "Tokens Log:\n" <> Enum.join(lines, "\n")
        Helper.reply_ephemeral(interaction, result)
      end
    else
      Helper.reply_ephemeral(interaction, "Please specify a user.")
    end
  end
end
