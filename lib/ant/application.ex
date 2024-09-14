defmodule Ant.Application do
  @moduledoc false

  use Application

  @mix_env Mix.env()

  @impl true
  def start(_type, _args) do
    start_database()

    opts = [strategy: :one_for_one, name: Ant.Supervisor]
    Supervisor.start_link(children(@mix_env), opts)
  end

  def children(:test) do
    # For test env does not start Ant.WorkersRunner GenServer
    # because it automatically pick ups workers from the database and runs them,
    # changing their state.
    # It affects the tests that rely on the state of the workers.
    # Ant.WorkersRunner should be started and stopped manually where needed.
    #
    [
      {DynamicSupervisor, name: Ant.WorkersSupervisor, strategy: :one_for_one}
    ]
  end

  def children(_env) do
    [
      Ant.WorkersRunner,
      {DynamicSupervisor, name: Ant.WorkersSupervisor, strategy: :one_for_one}
    ]
  end

  defp start_database do
    unless :mnesia.system_info(:schema_location) do
      :ok = :mnesia.create_schema([node()])
    end

    :ok = :mnesia.start()

    # unless :mnesia.table_info(:ant_workers, :attributes) do
    :mnesia.create_table(:ant_workers,
      attributes: [:id, :worker_module, :status, :args, :attempts, :errors, :opts]
      # disc_copies: [node()]
    )

    # end
  end
end
