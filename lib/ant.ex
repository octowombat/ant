defmodule Ant do
  @moduledoc """
  Documentation for `Ant`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Ant.hello()
      :world

  """
  def perform(worker) do
    # starts a new worker process
    # performs task with the given argument (and clause in the future).
    # if tasks finishes successfully, stops the process.

    {:ok, _} = Ant.Workers.create_worker(worker)
  end
end
