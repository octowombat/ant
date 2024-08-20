defmodule Ant.Worker do
  use GenServer
  require Logger

  defstruct [:worker_module, :args, :opts]

  @type t :: %Ant.Worker{
          worker_module: module(),
          args: map(),
          opts: keyword()
        }

  @callback perform(worker :: Ant.Worker.t()) :: :ok | {:ok, any()} | {:error, any()}

  @max_attempts 3
  @default_retry_delay 5_000

  defmacro __using__(_opts) do
    quote do
      @behaviour Ant.Worker

      def build(args, opts \\ []) do
        %Ant.Worker{
          worker_module: __MODULE__,
          args: args,
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
      worker: worker,
      status: :running,
      attempts: 0,
      errors: []
    }

    {:ok, state}
  end

  def handle_cast(:perform, state) do
    worker = state.worker
    state = Map.put(state, :attempts, state.attempts + 1)
    Logger.debug("Handling call to get_state. Current state: #{inspect(state)}")

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

    {:stop, :normal, Map.put(state, :status, :succeeded)}
  end

  defp handle_result({:ok, _result}, state) do
    Logger.debug("handle_result: OK")

    {:stop, :normal, Map.put(state, :status, :succeeded)}
  end

  # When result is returned, but is not :ok or {:ok, _result}
  # it is considered an error.
  # If the number of attempts is less than the maximum allowed,
  # the worker will be retried.
  # Otherwise, the worker will be stopped.
  #
  defp handle_result(_error, %{attempts: attempts} = state) do
    if attempts <= @max_attempts do
      Logger.debug("handle_result: ERROR. Retrying.")

      retry(state)
    else
      Logger.debug("handle_result: ERROR. Max attempts reached.")

      {:stop, :normal, Map.put(state, :status, :failed)}
    end
  end

  defp handle_exception(exception, stack_trace, state) do
    attempts = state.attempts

    error = %{
      attempt: attempts,
      error: exception.message,
      stack_trace: Exception.format_stacktrace(stack_trace),
      attempted_at: DateTime.utc_now()
    }

    state = Map.put(state, :errors, [error | state.errors])

    if attempts <= @max_attempts do
      Logger.debug("handle_exception: Retrying.")

      retry(state)
    else
      Logger.debug("handle_exception: Max attempts reached.")

      {:stop, :abnormal, Map.put(state, :status, :failed)}
    end
  end

  def terminate(reason, state) do
    IO.puts("GenServer is terminating.")
    IO.inspect(reason)
    IO.inspect(state)

    :ok
  end

  defp retry(state) do
    Process.send_after(self(), :retry, calculate_delay(state.attempts))

    {:noreply, Map.put(state, :status, :retrying)}
  end

  defp calculate_delay(attempts), do: @default_retry_delay * attempts
end
