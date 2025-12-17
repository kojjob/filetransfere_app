defmodule FiletransferCore.Transfers do
  @moduledoc """
  The Transfers context for managing file transfers.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Transfers.Transfer
  alias FiletransferCore.Chunks.Chunk

  # 5MB default
  @chunk_size 5_242_880

  @doc """
  Returns the list of transfers for a user.
  """
  def list_transfers(user_id) do
    from(t in Transfer,
      where: t.user_id == ^user_id,
      order_by: [desc: t.inserted_at],
      preload: [:chunks]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single transfer.
  """
  def get_transfer!(id), do: Repo.get!(Transfer, id) |> Repo.preload(:chunks)

  @doc """
  Gets a transfer by ID and user ID (for authorization).
  """
  def get_user_transfer(user_id, transfer_id) do
    Repo.get_by(Transfer, id: transfer_id, user_id: user_id)
    |> Repo.preload(:chunks)
  end

  @doc """
  Creates a new transfer.
  """
  def create_transfer(attrs \\ %{}) do
    file_size = Map.get(attrs, :file_size, 0)
    total_chunks = calculate_total_chunks(file_size, Map.get(attrs, :chunk_size, @chunk_size))

    attrs
    |> Map.put(:total_chunks, total_chunks)
    |> Map.put(:chunk_size, Map.get(attrs, :chunk_size, @chunk_size))
    |> Map.put(:status, "pending")
    |> Map.put(:started_at, DateTime.utc_now())
    |> then(fn attrs ->
      %Transfer{}
      |> Transfer.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, transfer} ->
          create_chunks_for_transfer(transfer)
          {:ok, Repo.preload(transfer, :chunks)}

        error ->
          error
      end
    end)
  end

  @doc """
  Updates a transfer.
  """
  def update_transfer(%Transfer{} = transfer, attrs) do
    transfer
    |> Transfer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a transfer.
  """
  def delete_transfer(%Transfer{} = transfer) do
    Repo.delete(transfer)
  end

  @doc """
  Updates transfer progress when a chunk is uploaded.
  """
  def update_chunk_progress(transfer_id, chunk_index, bytes_uploaded) do
    transfer = get_transfer!(transfer_id)

    # Update chunk status
    chunk = Enum.find(transfer.chunks, &(&1.chunk_index == chunk_index))

    if chunk do
      Chunk.changeset(chunk, %{
        bytes_uploaded: bytes_uploaded,
        status: if(bytes_uploaded >= chunk.chunk_size, do: "completed", else: "uploading")
      })
      |> Repo.update()
    end

    # Calculate overall progress
    completed_chunks = Enum.count(transfer.chunks, &(&1.status == "completed"))
    total_bytes = Enum.sum(Enum.map(transfer.chunks, & &1.bytes_uploaded))

    update_transfer(transfer, %{
      uploaded_chunks: completed_chunks,
      bytes_uploaded: total_bytes,
      status: if(completed_chunks == transfer.total_chunks, do: "completed", else: "uploading")
    })
  end

  @doc """
  Marks a transfer as completed.
  """
  def complete_transfer(%Transfer{} = transfer, storage_path) do
    update_transfer(transfer, %{
      status: "completed",
      storage_path: storage_path,
      completed_at: DateTime.utc_now()
    })
  end

  @doc """
  Marks a transfer as failed.
  """
  def fail_transfer(%Transfer{} = transfer, error_message) do
    update_transfer(transfer, %{
      status: "failed",
      error_message: error_message
    })
  end

  @doc """
  Gets incomplete chunks for a transfer (for resume).
  """
  def get_incomplete_chunks(transfer_id) do
    from(c in Chunk,
      where: c.transfer_id == ^transfer_id and c.status != "completed",
      order_by: c.chunk_index
    )
    |> Repo.all()
  end

  defp calculate_total_chunks(file_size, chunk_size) when file_size > 0 do
    div(file_size, chunk_size) + if rem(file_size, chunk_size) > 0, do: 1, else: 0
  end

  defp calculate_total_chunks(_, _), do: 0

  defp create_chunks_for_transfer(%Transfer{} = transfer) do
    Enum.each(0..(transfer.total_chunks - 1), fn index ->
      %Chunk{}
      |> Chunk.changeset(%{
        transfer_id: transfer.id,
        chunk_index: index,
        chunk_size:
          if(index == transfer.total_chunks - 1,
            do: rem(transfer.file_size, transfer.chunk_size),
            else: transfer.chunk_size
          ),
        status: "pending"
      })
      |> Repo.insert!()
    end)
  end
end
