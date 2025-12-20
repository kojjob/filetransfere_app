defmodule FiletransferCore.Usage.UsageStat do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "usage_stats" do
    field(:month, :integer)
    field(:year, :integer)
    field(:bytes_transferred, :integer, default: 0)
    field(:files_transferred, :integer, default: 0)
    field(:api_calls, :integer, default: 0)

    belongs_to(:user, FiletransferCore.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(usage_stat, attrs) do
    usage_stat
    |> cast(attrs, [
      :month,
      :year,
      :bytes_transferred,
      :files_transferred,
      :api_calls,
      :user_id
    ])
    |> validate_required([:month, :year, :user_id])
    |> validate_inclusion(:month, 1..12)
    |> validate_number(:year, greater_than: 2020)
    |> unique_constraint([:user_id, :year, :month])
  end
end


