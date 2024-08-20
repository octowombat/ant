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

    child_spec = Supervisor.child_spec({Ant.Worker, worker}, restart: :transient)
    {:ok, pid} = DynamicSupervisor.start_child(Ant.WorkersSupervisor, child_spec)

    Ant.Worker.perform(pid)
  end
end
