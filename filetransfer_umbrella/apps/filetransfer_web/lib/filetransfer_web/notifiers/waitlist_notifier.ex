defmodule FiletransferWeb.Notifiers.WaitlistNotifier do
  @moduledoc """
  Email notifications for waitlist signups.

  Sends welcome emails when users join the waitlist.
  """

  import Swoosh.Email

  alias FiletransferWeb.Mailer

  @from_email "ZipShare <hello@zipshare.io>"
  @reply_to "support@zipshare.io"

  @doc """
  Delivers a welcome email to a new waitlist signup.

  ## Examples

      iex> deliver_welcome_email(%WaitlistEntry{email: "user@example.com", name: "John"})
      {:ok, %Swoosh.Email{}}

  """
  def deliver_welcome_email(%{email: email, name: name} = _waitlist_entry) do
    display_name = name || "there"

    email =
      new()
      |> to(email)
      |> from(@from_email)
      |> reply_to(@reply_to)
      |> subject("You're on the ZipShare waitlist!")
      |> html_body(welcome_html(display_name))
      |> text_body(welcome_text(display_name))

    Mailer.deliver(email)
  end

  defp welcome_html(name) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #6366f1; margin: 0; font-size: 32px;">ZipShare</h1>
        <p style="color: #64748b; margin-top: 5px;">Lightning-fast file transfers</p>
      </div>

      <div style="background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%); border-radius: 12px; padding: 30px; color: white; text-align: center; margin-bottom: 30px;">
        <h2 style="margin: 0 0 10px 0; font-size: 24px;">Hey #{name}!</h2>
        <p style="margin: 0; font-size: 18px; opacity: 0.95;">You're officially on the waitlist.</p>
      </div>

      <div style="background: #f8fafc; border-radius: 12px; padding: 25px; margin-bottom: 30px;">
        <h3 style="color: #1e293b; margin: 0 0 15px 0;">What's coming your way:</h3>
        <ul style="margin: 0; padding-left: 20px; color: #475569;">
          <li style="margin-bottom: 10px;"><strong>10GB+ file transfers</strong> - No more splitting files</li>
          <li style="margin-bottom: 10px;"><strong>End-to-end encryption</strong> - Your files, your privacy</li>
          <li style="margin-bottom: 10px;"><strong>Resumable uploads</strong> - Never lose progress</li>
          <li style="margin-bottom: 10px;"><strong>Real-time progress</strong> - Watch your files fly</li>
        </ul>
      </div>

      <div style="text-align: center; margin-bottom: 30px;">
        <p style="color: #64748b; margin-bottom: 15px;">We'll notify you as soon as ZipShare launches. Stay tuned!</p>
        <a href="https://zipshare.io" style="display: inline-block; background: #6366f1; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600;">Visit ZipShare</a>
      </div>

      <div style="border-top: 1px solid #e2e8f0; padding-top: 20px; text-align: center; color: #94a3b8; font-size: 14px;">
        <p style="margin: 0 0 10px 0;">
          Questions? Just reply to this email - we'd love to hear from you.
        </p>
        <p style="margin: 0;">
          ZipShare | Fast, secure file transfers
        </p>
      </div>
    </body>
    </html>
    """
  end

  defp welcome_text(name) do
    """
    Hey #{name}!

    You're officially on the ZipShare waitlist.

    What's coming your way:
    - 10GB+ file transfers - No more splitting files
    - End-to-end encryption - Your files, your privacy
    - Resumable uploads - Never lose progress
    - Real-time progress - Watch your files fly

    We'll notify you as soon as ZipShare launches. Stay tuned!

    Visit us: https://zipshare.io

    Questions? Just reply to this email - we'd love to hear from you.

    ZipShare | Fast, secure file transfers
    """
  end
end
