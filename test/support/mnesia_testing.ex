defmodule MnesiaTesting do
  defmacro __using__(_opts) do
    quote do
      setup_all do
        MnesiaTesting.prepare()

        :ok
      end

      setup do
        on_exit(fn -> MnesiaTesting.clear_db() end)

        :ok
      end
    end
  end

  def prepare do
    :ok = :mnesia.start()

    unless :mnesia.table_info(:ant_workers, :attributes) do
      :mnesia.create_table(:ant_workers,
        attributes: [:id, :worker_module, :status, :args, :attempts, :errors, :opts]
      )

      :mnesia.wait_for_tables([:ant_workers], 5000)
    end

    clear_db()
  end

  def clear_db() do
    :mnesia.clear_table(:ant_workers)
  end
end
