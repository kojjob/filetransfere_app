defmodule FiletransferCore.Sharing.ShareLink do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "share_links" do
    field(:token, :string)
    field(:password_hash, :string)
    field(:expires_at, :utc_datetime)
    field(:max_downloads, :integer)
    field(:download_count, :integer, default: 0)
    field(:is_active, :boolean, default: true)

    belongs_to(:transfer, FiletransferCore.Transfers.Transfer)
    belongs_to(:user, FiletransferCore.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(share_link, attrs) do
    share_link
    |> cast(attrs, [
      :token,
      :password_hash,
      :expires_at,
      :max_downloads,
      :download_count,
      :is_active,
      :transfer_id,
      :user_id
    ])
    |> validate_required([:token, :transfer_id, :user_id])
    |> unique_constraint(:token)
    |> validate_expiration()
  end

  defp validate_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        changeset

      expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          add_error(changeset, :expires_at, "must be in the future")
        else
          changeset
        end
    end
  end
end
