defmodule Ant.WorkersRunner do
  use GenServer
  require Logger

  alias Ant.Workers

  @check_interval :timer.seconds(5)

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(state) do
    schedule_check()

    {:ok, state}
  end

  @impl true
  def handle_info(:check_workers, state) do
    check_workers()

    schedule_check()
    {:noreply, state}
  end

  # Helper Functions

  defp schedule_check do
    Process.send_after(self(), :check_workers, @check_interval)
  end

  defp check_workers do
    # TODO: make sure first in -- first out for processing
    case Workers.list_workers(:enqueued) do
      {:ok, workers} when workers != [] ->
        workers
        |> Stream.each(&run_worker/1)
        |> Stream.run()

      _ ->
        :ok
    end
  end

  defp run_worker(worker) do
    child_spec = Supervisor.child_spec({Ant.Worker, worker}, restart: :transient)
    {:ok, pid} = DynamicSupervisor.start_child(Ant.WorkersSupervisor, child_spec)

    Ant.Worker.perform(pid)
  end
end
