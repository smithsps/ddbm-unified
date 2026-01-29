defmodule DdbmDiscord.Commands do
  @moduledoc """
  Defines Discord slash commands for the bot.
  """

  alias Ddbm.Tokens.Token

  @doc """
  Returns all command definitions to register with Discord.
  """
  def all do
    [
      give_command(),
      token_command(),
      token_admin_command(),
      register_command(),
      unregister_command()
    ]
  end

  defp give_command do
    %{
      name: "give",
      description: "Gift a token to a user.",
      options: [
        %{
          type: 6,
          name: "user",
          description: "The user receiving the token.",
          required: true
        },
        %{
          type: 3,
          name: "token",
          description: "The token type you're giving.",
          required: true,
          choices: token_choices()
        }
      ]
    }
  end

  defp token_command do
    %{
      name: "token",
      description: "Give and receive tokens from others.",
      options: [
        %{
          type: 1,
          name: "check",
          description: "Check how many tokens you have."
        },
        %{
          type: 1,
          name: "leaderboard",
          description: "See the leaders of each token.",
          options: [
            %{
              type: 3,
              name: "token",
              description: "Filter by token type.",
              required: false,
              choices: token_choices()
            }
          ]
        }
      ]
    }
  end

  defp token_admin_command do
    %{
      name: "token-admin",
      description: "Manage tokens for other users.",
      default_member_permissions: "8",
      options: [
        %{
          type: 1,
          name: "list",
          description: "List recent token transactions.",
          options: [
            %{
              type: 6,
              name: "user",
              description: "The user to view.",
              required: true
            }
          ]
        }
      ]
    }
  end

  defp register_command do
    %{
      name: "register",
      description: "Register to get bot notifications."
    }
  end

  defp unregister_command do
    %{
      name: "unregister",
      description: "Remove yourself from bot notifications."
    }
  end

  defp token_choices do
    Token.all()
    |> Enum.map(fn token ->
      %{name: "#{token.icon} #{token.name}", value: token.id}
    end)
  end
end
