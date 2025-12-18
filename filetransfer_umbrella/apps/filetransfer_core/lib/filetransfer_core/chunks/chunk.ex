defmodule FiletransferCore.Chunks.Chunk do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chunks" do
    field(:chunk_index, :integer)
    field(:chunk_size, :integer)
    field(:bytes_uploaded, :integer, default: 0)
    field(:status, :string, default: "pending")
    field(:storage_path, :string)
    field(:checksum, :string)
    field(:uploaded_at, :utc_datetime)

    belongs_to(:transfer, FiletransferCore.Transfers.Transfer)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [
      :chunk_index,
      :chunk_size,
      :bytes_uploaded,
      :status,
      :storage_path,
      :checksum,
      :uploaded_at,
      :transfer_id
    ])
    |> validate_required([:chunk_index, :chunk_size, :transfer_id])
    |> validate_inclusion(:status, ["pending", "uploading", "completed", "failed"])
    |> unique_constraint([:transfer_id, :chunk_index])
  end
end


