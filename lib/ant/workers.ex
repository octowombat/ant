defmodule Ant.Workers do
  alias Ant.Repo

  @spec create_worker(Ant.Worker.t()) :: :ok
  def create_worker(worker) do
    params = %{
      worker_module: worker.worker_module,
      status: :enqueued,
      attempts: 0,
      queue_name: worker.queue_name,
      args: worker.args,
      scheduled_at: worker.scheduled_at,
      errors: [],
      opts: worker.opts
    }

    Repo.insert(:ant_workers, params)
  end

  @spec update_worker(integer(), map()) :: {:ok, Ant.Worker.t()} | {:error, atom()}
  def update_worker(id, params), do: Repo.update(:ant_workers, id, params)

  @spec list_workers(map()) :: {:ok, [Ant.Worker.t()]}
  def list_workers(clauses), do: {:ok, Repo.filter(:ant_workers, clauses)}

  def list_retrying_workers(clauses, date_time \\ DateTime.utc_now()) do
    with {:ok, workers} <- list_workers(Map.put(clauses, :status, :retrying)) do
      retry_workers =
        workers
        |> Enum.reject(&(DateTime.compare(&1.scheduled_at, date_time) == :gt))
        |> Enum.sort_by(& &1.scheduled_at, DateTime)

      {:ok, retry_workers}
    end
  end

  def list_scheduled_workers(clauses, date_time \\ DateTime.utc_now()) do
    with {:ok, workers} <- list_workers(Map.put(clauses, :status, :scheduled)) do
      scheduled_workers =
        workers
        |> Enum.reject(&(DateTime.compare(&1.scheduled_at, date_time) == :gt))
        |> Enum.sort_by(& &1.scheduled_at, DateTime)

      {:ok, scheduled_workers}
    end
  end

  @spec list_workers() :: {:ok, [Ant.Worker.t()]}
  def list_workers(), do: {:ok, Repo.all(:ant_workers)}

  @spec get_worker(integer()) :: {:ok, Ant.Worker.t()} | {:error, atom()}
  def get_worker(id), do: Repo.get(:ant_workers, id)

  @spec delete_worker(Ant.Worker.t()) :: :ok
  def delete_worker(worker), do: Repo.delete(:ant_workers, worker.id)
end
