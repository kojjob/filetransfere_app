defmodule FiletransferCore.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(user project_owner)

  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:password, :string, virtual: true)
    field(:hashed_password, :string)
    field(:role, :string, default: "user")
    field(:subscription_tier, :string, default: "free")
    field(:stripe_customer_id, :string)
    field(:stripe_subscription_id, :string)
    field(:monthly_transfer_limit, :integer, default: 5_368_709_120)
    field(:max_file_size, :integer, default: 2_147_483_648)
    field(:api_calls_limit, :integer, default: 0)
    field(:api_calls_used, :integer, default: 0)
    field(:confirmed_at, :naive_datetime)
    field(:reset_password_token, :string)
    field(:reset_password_sent_at, :naive_datetime)

    has_many(:transfers, FiletransferCore.Transfers.Transfer)
    has_many(:share_links, FiletransferCore.Sharing.ShareLink)
    has_many(:api_keys, FiletransferCore.Api.ApiKey)
    has_many(:usage_stats, FiletransferCore.Usage.UsageStat)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :subscription_tier,
      :monthly_transfer_limit,
      :max_file_size,
      :api_calls_limit
    ])
    |> validate_required([:email])
    |> validate_email()
    |> unique_constraint(:email)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :subscription_tier,
      :monthly_transfer_limit,
      :max_file_size,
      :api_calls_limit,
      :password
    ])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password()
    |> unique_constraint(:email)
    |> put_hashed_password()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
  end

  defp put_hashed_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))

      _ ->
        changeset
    end
  end

  def verify_password(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def verify_password(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Changeset for updating user role. Only project owners can promote/demote users.
  """
  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, @roles)
  end

  @doc """
  Checks if a user has the project_owner role.
  """
  def project_owner?(%__MODULE__{role: "project_owner"}), do: true
  def project_owner?(_), do: false

  @doc """
  Returns the list of valid roles.
  """
  def roles, do: @roles
end
