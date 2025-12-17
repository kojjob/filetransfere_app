defmodule FiletransferCore.Waitlist.WaitlistEntry do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "waitlist_entries" do
    field(:email, :string)
    field(:name, :string)
    field(:use_case, :string)
    field(:source, :string, default: "landing_page")
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:notified_at, :utc_datetime)
    field(:converted_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(waitlist_entry, attrs) do
    waitlist_entry
    |> cast(attrs, [:email, :name, :use_case, :source, :ip_address, :user_agent])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> unique_constraint(:email)
  end
end
