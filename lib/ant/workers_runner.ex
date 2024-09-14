defmodule Ant.WorkersRunner do
  use GenServer
  require Logger

  alias Ant.Workers

  @check_interval :timer.seconds(5)

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    check_interval = Keyword.get(opts, :check_interval, @check_interval)

    {:ok, %{check_interval: check_interval}, {:continue, :run_pending_workers}}
  end

  @impl true
  # After application start make sure to run not only enqueued workers but also running and retrying.
  # This prevents the situation when the application is restarted and the workers that were not completed
  # are not picked up by the WorkersRunner.
  #
  def handle_continue(:run_pending_workers, state) do
    Logger.debug("Checking pending workers")

    with {:ok, enqueued_workers} <- Workers.list_workers(:enqueued),
         {:ok, running_workers} <- Workers.list_workers(:running),
         {:ok, retrying_workers} <- Workers.list_workers(:retrying) do
      workers = enqueued_workers ++ running_workers ++ retrying_workers

      Enum.each(workers, &run_worker/1)
    end

    schedule_check(state.check_interval)

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_enqueued_workers, state) do
    with {:ok, enqueued_workers} <- Workers.list_workers(:enqueued) do
      Enum.each(enqueued_workers, &run_worker/1)
    end

    schedule_check(state.check_interval)

    {:noreply, state}
  end

  # Helper Functions

  defp schedule_check(check_interval) do
    Process.send_after(self(), :check_enqueued_workers, check_interval)
  end

  defp run_worker(worker) do
    child_spec = Supervisor.child_spec({Ant.Worker, worker}, restart: :transient)
    {:ok, pid} = DynamicSupervisor.start_child(Ant.WorkersSupervisor, child_spec)

    Ant.Worker.perform(pid)
  end
end
