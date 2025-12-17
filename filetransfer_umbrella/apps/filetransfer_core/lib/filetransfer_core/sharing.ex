defmodule FiletransferCore.Sharing do
  @moduledoc """
  The Sharing context for managing file share links.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Sharing.ShareLink

  @token_length 32

  def create_share_link(transfer, user, opts \\ []) do
    password = Keyword.get(opts, :password)
    expires_in = Keyword.get(opts, :expires_in, 7 * 24 * 3600)
    max_downloads = Keyword.get(opts, :max_downloads)

    attrs = %{
      token: generate_token(),
      transfer_id: transfer.id,
      user_id: user.id,
      expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second),
      max_downloads: max_downloads,
      password_hash: hash_password(password)
    }

    %ShareLink{}
    |> ShareLink.changeset(attrs)
    |> Repo.insert()
  end

  def get_share_link_by_token(token) do
    Repo.get_by(ShareLink, token: token)
    |> Repo.preload(:transfer)
  end

  def get_share_link!(id) do
    Repo.get!(ShareLink, id)
    |> Repo.preload(:transfer)
  end

  def list_user_share_links(user_id) do
    from(s in ShareLink,
      where: s.user_id == ^user_id,
      order_by: [desc: s.inserted_at],
      preload: [:transfer]
    )
    |> Repo.all()
  end

  def validate_share_link(token, password \\ nil) do
    case get_share_link_by_token(token) do
      nil -> {:error, :not_found}
      share_link ->
        cond do
          not share_link.is_active -> {:error, :link_disabled}
          expired?(share_link) -> {:error, :link_expired}
          download_limit_exceeded?(share_link) -> {:error, :download_limit_exceeded}
          password_required?(share_link) and not verify_password(share_link, password) -> {:error, :invalid_password}
          true -> {:ok, share_link}
        end
    end
  end

  def record_download(share_link) do
    share_link
    |> ShareLink.changeset(%{download_count: share_link.download_count + 1})
    |> Repo.update()
  end

  def update_share_link(share_link, attrs) do
    attrs = if Map.has_key?(attrs, :password) do
      Map.put(attrs, :password_hash, hash_password(attrs.password)) |> Map.delete(:password)
    else
      attrs
    end

    share_link |> ShareLink.changeset(attrs) |> Repo.update()
  end

  def delete_share_link(share_link), do: Repo.delete(share_link)

  def share_url(share_link, base_url \\ "https://zipshare.io") do
    "#{base_url}/s/#{share_link.token}"
  end

  def password_required?(share_link), do: share_link.password_hash != nil

  defp generate_token do
    :crypto.strong_rand_bytes(@token_length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, @token_length)
  end

  defp hash_password(nil), do: nil
  defp hash_password(password), do: Bcrypt.hash_pwd_salt(password)

  defp verify_password(_share_link, nil), do: false
  defp verify_password(share_link, password), do: Bcrypt.verify_pass(password, share_link.password_hash)

  defp expired?(%{expires_at: nil}), do: false
  defp expired?(%{expires_at: expires_at}), do: DateTime.compare(expires_at, DateTime.utc_now()) == :lt

  defp download_limit_exceeded?(%{max_downloads: nil}), do: false
  defp download_limit_exceeded?(%{max_downloads: max, download_count: count}), do: count >= max
end
