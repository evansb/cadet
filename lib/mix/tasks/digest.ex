defmodule Mix.Tasks.Cadet.Digest do
  @moduledoc """
    Build and digest frontend assets.
  """
  use Mix.Task

  def run(args) do
    Dotenv.load!()
    Mix.Shell.IO.cmd("cd frontend && npm run build")
    :ok = Mix.Tasks.Phx.Digest.run(args)
  end
end
