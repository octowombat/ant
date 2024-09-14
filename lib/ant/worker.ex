defmodule Ant.Worker do
  use GenServer
  require Logger

  defstruct [:id, :worker_module, :args, :status, :attempts, :errors, :opts]

  @type t :: %Ant.Worker{
          id: non_neg_integer(),
          worker_module: module(),
          args: map(),
          status: :queued | :running | :completed | :failed | :retrying | :cancelled,
          args: map(),
          attempts: non_neg_integer(),
          errors: [map()],
          opts: keyword()
        }

  @callback perform(worker :: Ant.Worker.t()) :: :ok | {:ok, any()} | {:error, any()}
  @callback calculate_delay(worker :: Ant.Worker.t()) :: non_neg_integer()
  @optional_callbacks calculate_delay: 1

  @max_attempts 3
  @default_retry_delay 10_000

  defmacro __using__(_opts) do
    quote do
      @behaviour Ant.Worker

      def build(args, opts \\ []) do
        %Ant.Worker{
          worker_module: __MODULE__,
          args: args,
          status: :queued,
          attempts: 0,
          errors: [],
          opts: opts
        }
      end
    end
  end

  # Client API
  def start_link(worker) do
    GenServer.start_link(__MODULE__, worker)
  end

  def perform(worker_pid) do
    GenServer.cast(worker_pid, :perform)
  end

  # Server Callbacks
  def init(worker) do
    state = %{
      worker: worker
    }

    {:ok, state}
  end

  def handle_cast(:perform, state) do
    worker = state.worker

    {:ok, worker} =
      Ant.Workers.update_worker(worker.id, %{status: :running, attempts: worker.attempts + 1})

    state = Map.put(state, :worker, worker)

    try do
      worker
      |> worker.worker_module.perform()
      |> handle_result(state)
    rescue
      exception ->
        handle_exception(exception, __STACKTRACE__, state)
    end
  end

  def handle_info(:retry, state) do
    handle_cast(:perform, state)
  end

  defp handle_result(:ok, state) do
    Logger.debug("handle_result: OK")

    {:ok, worker} = Ant.Workers.update_worker(state.worker.id, %{status: :completed})
    {:stop, :normal, Map.put(state, :worker, worker)}
  end

  defp handle_result({:ok, _result}, state) do
    Logger.debug("handle_result: OK")

    {:ok, worker} = Ant.Workers.update_worker(state.worker.id, %{status: :completed})
    {:stop, :normal, Map.put(state, :worker, worker)}
  end

  # When result is returned, but is not :ok or {:ok, _result}
  # it is considered an error.
  # If the number of attempts is less than the maximum allowed,
  # the worker will be retried.
  # Otherwise, the worker will be stopped.
  #
  defp handle_result(error_result, state) do
    worker = state.worker

    error = %{
      attempt: worker.attempts,
      error: "Expected :ok or {:ok, _result}, but got #{inspect(error_result)}",
      stack_trace: nil,
      attempted_at: DateTime.utc_now()
    }

    errors = [error | worker.errors]

    if worker.attempts < @max_attempts do
      Logger.debug("handle_result: ERROR. Retrying.")

      {:ok, worker} =
        Ant.Workers.update_worker(state.worker.id, %{status: :retrying, errors: errors})

      state
      |> Map.put(:worker, worker)
      |> retry()
    else
      Logger.debug("handle_result: ERROR. Max attempts reached.")

      {:ok, worker} =
        Ant.Workers.update_worker(state.worker.id, %{status: :failed, errors: errors})

      {:stop, :normal, Map.put(state, :worker, worker)}
    end
  end

  defp handle_exception(exception, stack_trace, state) do
    worker = state.worker
    attempts = worker.attempts

    error = %{
      attempt: attempts,
      error: exception.message,
      stack_trace: Exception.format_stacktrace(stack_trace),
      attempted_at: DateTime.utc_now()
    }

    errors = [error | worker.errors]

    if attempts < @max_attempts do
      Logger.debug("handle_exception: Retrying.")

      {:ok, worker} = Ant.Workers.update_worker(worker.id, %{status: :failed, errors: errors})

      state
      |> Map.put(:worker, worker)
      |> retry()
    else
      Logger.debug("handle_exception: Max attempts reached.")

      {:ok, worker} = Ant.Workers.update_worker(worker.id, %{status: :failed, errors: errors})
      {:stop, :normal, Map.put(state, :worker, worker)}
    end
  end

  def terminate(reason, state) do
    IO.puts("GenServer is terminating.")
    IO.inspect(reason)
    IO.inspect(state)

    :ok
  end

  defp retry(state) do
    {:ok, worker} = Ant.Workers.update_worker(state.worker.id, %{status: :retrying})
    Process.send_after(self(), :retry, calculate_delay(worker))

    {:noreply, Map.put(state, :worker, worker)}
  end

  defp calculate_delay(worker) do
    if function_exported?(worker.worker_module, :calculate_delay, 1) do
      worker.worker_module.calculate_delay(worker)
    else
      @default_retry_delay * worker.attempts
    end
  end
end
