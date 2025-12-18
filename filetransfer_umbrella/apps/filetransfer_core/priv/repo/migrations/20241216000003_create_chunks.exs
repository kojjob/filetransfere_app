defmodule FiletransferCore.Repo.Migrations.CreateChunks do
  use Ecto.Migration

  def change do
    create table(:chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :transfer_id, references(:transfers, type: :binary_id, on_delete: :delete_all), null: false
      add :chunk_index, :integer, null: false
      add :chunk_size, :integer, null: false
      add :bytes_uploaded, :integer, default: 0, null: false
      add :status, :string, default: "pending", null: false # pending, uploading, completed, failed
      add :storage_path, :string
      add :checksum, :string
      add :uploaded_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chunks, [:transfer_id, :chunk_index])
    create index(:chunks, [:transfer_id, :status])
  end
end


