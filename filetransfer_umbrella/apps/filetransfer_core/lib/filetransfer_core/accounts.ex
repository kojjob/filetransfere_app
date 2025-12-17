defmodule FiletransferCore.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Accounts.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user. Raises if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user. Returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.verify_password(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        {:error, :not_found}
    end
  end

  @doc """
  Confirms a user's email.
  """
  def confirm_user(%User{} = user) do
    update_user(user, %{confirmed_at: NaiveDateTime.utc_now()})
  end

  @doc """
  Updates user subscription tier and limits.
  """
  def update_subscription(user, tier) do
    limits = subscription_limits(tier)

    update_user(user, Map.merge(%{subscription_tier: tier}, limits))
  end

  defp subscription_limits("free") do
    %{
      # 5GB
      monthly_transfer_limit: 5_368_709_120,
      # 2GB
      max_file_size: 2_147_483_648,
      api_calls_limit: 0
    }
  end

  defp subscription_limits("pro") do
    %{
      # 100GB
      monthly_transfer_limit: 107_374_182_400,
      # 10GB
      max_file_size: 10_737_418_240,
      api_calls_limit: 1_000
    }
  end

  defp subscription_limits("business") do
    %{
      # 500GB
      monthly_transfer_limit: 536_870_912_000,
      # 50GB
      max_file_size: 53_687_091_200,
      api_calls_limit: :unlimited
    }
  end

  defp subscription_limits("enterprise") do
    %{
      monthly_transfer_limit: :unlimited,
      max_file_size: :unlimited,
      api_calls_limit: :unlimited
    }
  end
end
