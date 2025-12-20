defmodule FiletransferCore.Api.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_keys" do
    field(:key_hash, :string)
    field(:key_prefix, :string)
    field(:name, :string)
    field(:last_used_at, :utc_datetime)
    field(:is_active, :boolean, default: true)
    field(:rate_limit, :integer, default: 1000)

    belongs_to(:user, FiletransferCore.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [
      :key_hash,
      :key_prefix,
      :name,
      :last_used_at,
      :is_active,
      :rate_limit,
      :user_id
    ])
    |> validate_required([:key_hash, :key_prefix, :user_id])
    |> unique_constraint(:key_hash)
  end
end


