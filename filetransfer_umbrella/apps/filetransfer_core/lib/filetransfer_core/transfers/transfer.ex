defmodule FiletransferCore.Transfers.Transfer do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfers" do
    field(:status, :string, default: "pending")
    field(:file_name, :string)
    field(:file_size, :integer)
    field(:file_type, :string)
    field(:chunk_size, :integer, default: 5_242_880)
    field(:total_chunks, :integer)
    field(:uploaded_chunks, :integer, default: 0)
    field(:bytes_uploaded, :integer, default: 0)
    field(:storage_path, :string)
    field(:storage_provider, :string, default: "s3")
    field(:encryption_key, :string)
    field(:metadata, :map, default: %{})
    field(:error_message, :string)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    belongs_to(:user, FiletransferCore.Accounts.User)
    has_many(:chunks, FiletransferCore.Chunks.Chunk)
    has_many(:share_links, FiletransferCore.Sharing.ShareLink)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [
      :status,
      :file_name,
      :file_size,
      :file_type,
      :chunk_size,
      :total_chunks,
      :uploaded_chunks,
      :bytes_uploaded,
      :storage_path,
      :storage_provider,
      :encryption_key,
      :metadata,
      :error_message,
      :started_at,
      :completed_at,
      :user_id
    ])
    |> validate_required([:file_name, :file_size, :total_chunks, :user_id])
    |> validate_inclusion(:status, [
      "pending",
      "uploading",
      "processing",
      "completed",
      "failed",
      "cancelled"
    ])
    |> calculate_progress()
  end

  defp calculate_progress(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{bytes_uploaded: bytes, file_size: size}}
      when bytes > 0 and size > 0 ->
        progress = Float.round(bytes / size * 100, 2)

        put_change(
          changeset,
          :metadata,
          Map.put(changeset.data.metadata || %{}, "progress", progress)
        )

      _ ->
        changeset
    end
  end
end


