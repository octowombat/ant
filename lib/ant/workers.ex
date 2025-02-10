defmodule Ant.Workers do
  alias Ant.Repo

  @spec create_worker(Ant.Worker.t()) :: {:ok, Ant.Worker.t()}
  def create_worker(%Ant.Worker{} = worker) do
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

  @spec update_worker(non_neg_integer(), map()) :: {:ok, Ant.Worker.t()} | {:error, atom()}
  def update_worker(id, params) when is_integer(id) and id >= 0 and is_map(params) do
    Repo.update(:ant_workers, id, params)
  end

  @spec list_workers(map()) :: {:ok, [Ant.Worker.t()]}
  def list_workers(clauses) when is_map(clauses), do: {:ok, Repo.filter(:ant_workers, clauses)}

  @spec list_retrying_workers(map(), DateTime.t()) :: {:ok, [Ant.Worker.t()]}
  def list_retrying_workers(clauses, %DateTime{} = date_time \\ DateTime.utc_now())
      when is_map(clauses) do
    with {:ok, workers} <- list_workers(Map.put(clauses, :status, :retrying)) do
      retry_workers =
        workers
        |> Enum.reject(&(DateTime.compare(&1.scheduled_at, date_time) == :gt))
        |> Enum.sort_by(& &1.scheduled_at, DateTime)

      {:ok, retry_workers}
    end
  end

  @spec list_scheduled_workers(map(), DateTime.t()) :: {:ok, [Ant.Worker.t()]}
  def list_scheduled_workers(clauses, %DateTime{} = date_time \\ DateTime.utc_now())
      when is_map(clauses) do
    with {:ok, workers} <- list_workers(Map.put(clauses, :status, :scheduled)) do
      scheduled_workers =
        workers
        |> Enum.reject(&(DateTime.compare(&1.scheduled_at, date_time) == :gt))
        |> Enum.sort_by(& &1.scheduled_at, DateTime)

      {:ok, scheduled_workers}
    end
  end

  @spec list_workers() :: {:ok, [Ant.Worker.t()]}
  def list_workers, do: {:ok, Repo.all(:ant_workers)}

  @spec get_worker(non_neg_integer()) :: {:ok, Ant.Worker.t()} | {:error, atom()}
  def get_worker(id) when is_integer(id) and id >= 0, do: Repo.get(:ant_workers, id)

  @spec delete_worker(Ant.Worker.t()) :: :ok
  def delete_worker(%Ant.Worker{} = worker), do: Repo.delete(:ant_workers, worker.id)
end
