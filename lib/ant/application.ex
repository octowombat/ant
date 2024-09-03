defmodule Ant.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    start_database()

    children = [
      Ant.WorkersRunner,
      {DynamicSupervisor, name: Ant.WorkersSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Ant.Supervisor]
    Supervisor.start_link(children, opts)
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
