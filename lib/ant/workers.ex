defmodule Ant.Workers do
  alias Ant.Repo

  @spec create_worker(Ant.Worker.t()) :: :ok
  def create_worker(worker) do
    params = %{
      worker_module: worker.worker_module,
      status: :enqueued,
      attempts: 0,
      args: worker.args,
      errors: [],
      opts: []
    }

    Repo.insert(:ant_workers, params)
  end

  def update_worker(id, params), do: Repo.update(:ant_workers, id, params)

  def list_workers(status), do: {:ok, Repo.filter(:ant_workers, %{status: status})}

  def list_workers(), do: {:ok, Repo.all(:ant_workers)}

  def get_worker(id), do: Repo.get(:ant_workers, id)
end
