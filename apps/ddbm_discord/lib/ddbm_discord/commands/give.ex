defmodule DdbmDiscord.Commands.Give do
  @moduledoc """
  Handles the /give command for gifting tokens to users.
  """

  require Logger

  alias Ddbm.Tokens
  alias Ddbm.Tokens.Token
  alias DdbmDiscord.Helpers.Interaction, as: Helper

  def execute(interaction) do
    sender_id = to_string(interaction.member.user_id)
    target_user_id = Helper.get_option(interaction, "user")
    token_id = Helper.get_option(interaction, "token")

    cond do
      to_string(target_user_id) == sender_id ->
        Helper.reply_ephemeral(interaction, "You cannot give a token to yourself!")

      true ->
        give_token(interaction, sender_id, to_string(target_user_id), token_id)
    end
  end

  defp give_token(interaction, sender_id, target_user_id, token_id) do
    token = Token.get(token_id)

    if token do
      case Tokens.check_rate_limit(sender_id, token_id) do
        {:ok, :allowed} ->
          create_transaction(interaction, sender_id, target_user_id, token)

        {:error, :daily_limit, current, limit} ->
          Helper.reply_ephemeral(
            interaction,
            "You have already given your maximum of #{token.plural} today. (#{current}/#{limit})"
          )

        {:error, :weekly_limit, current, limit} ->
          Helper.reply_ephemeral(
            interaction,
            "You have already given your maximum of #{token.plural} this week. (#{current}/#{limit})"
          )

        {:error, :invalid_token} ->
          Helper.reply_ephemeral(interaction, "Invalid token type.")
      end
    else
      Logger.error("Invalid token type: #{token_id}")
      Helper.reply_ephemeral(interaction, "Invalid token type.")
    end
  end

  defp create_transaction(interaction, sender_id, target_user_id, token) do
    attrs = %{
      user_id: target_user_id,
      sender_user_id: sender_id,
      token: token.id,
      amount: 1,
      source: "SlashCommandGiveToken"
    }

    case Tokens.create_transaction(attrs) do
      {:ok, _transaction} ->
        Logger.info("Token given: #{sender_id} -> #{target_user_id} (#{token.id})")

        Helper.reply_ephemeral(
          interaction,
          "Gave a #{token.name} to <@#{target_user_id}>"
        )

        # Notify the bot channel
        Helper.notify_bot_channel(
          interaction.guild_id,
          "<@#{sender_id}> gave <@#{target_user_id}> a #{token.name}!"
        )

      {:error, changeset} ->
        Logger.error("Failed to create transaction: #{inspect(changeset)}")
        Helper.reply_ephemeral(interaction, "There was an unexpected error and your token was not given.")
    end
  end
end
