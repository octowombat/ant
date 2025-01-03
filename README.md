# Ant

Background job processing library for Elixir focused on simplicity. It uses Mnesia, which comes out of the box with the Elixir ecosystem, as a storage solution for jobs.

## Getting Started

Add `ant` to your list of dependencies in `mix.exs` and run `mix deps.get` to install it:

```elixir
def deps do
  [
    {:ant, "~> 0.0.1"}
  ]
end
```

Define a worker module with `perform` function. Argument is a map. Try to use simple argument values: strings, atoms, numbers, etc.

```elixir
defmodule MyWorker do
  use Ant.Worker

  def perform(%{first: first, "second" => second} = _args) do
    # some logic

    # has to return :ok or {:ok, result}
    # to be considered successful
    :ok
  end
end
```

Create a job to be processed asynchronously:

```elixir
{:ok, worker} = MyWorker.perform_async(%{first: "first", second: 2})
```

Note that the function to create a job is named `perform_async` and not `perform`. It returns a tuple with `:ok` and a worker struct.

## Configuration

You can configure the library to make it more suitable for your use case.

### Queues

By default `ant` uses only one queue `default`, that allows to concurrently process up to 5 jobs. Check interval for new jobs is 5 seconds.

You can define your own queues in `config.exs` file:

```elixir
config :ant,
  queues: [
    high_priority: [ # queue name
      concurrency: 10, # how many jobs can be processed simultaneously
      check_interval: 1000 # how often to check for new jobs in milliseconds
    ],
    low_priority: [
      concurrency: 1
    ]
  ]
```
Setting queue for a worker:

```elixir
defmodule MyWorker do
  use Ant.Worker, queue: :high_priority

  def perform(args) do
    # ...
  end
end
```
If `queue` is not set explicitly in the worker definition, the first queue from the configuration list is used.

### Retries

By default `ant` doesn't retry failed jobs. If you want to retry a failed job, set `max_attempts` in the worker definition:

```elixir
defmodule MyWorker do
  use Ant.Worker, max_attempts: 3

  def perform(args) do
    # ...
  end
end
```

Each subsequent attempt is delayed by 10 seconds more than the previous one. To change this behavior, implement `calculate_delay` function in the worker:

```elixir
defmodule MyWorker do
  use Ant.Worker, max_attempts: 3

  def perform(args) do
    # ...
  end

  def calculate_delay(worker), do: 10_000 # 10 seconds between each attempt
end
```

### Database

By default `ant` uses Mnesia with in-memory (`:ram_copies`) persistence strategy. To store jobs on a disk, please use one of the following strategies: `:disc_copies` or `:disc_only_copies`.

For `:disc_copies` and `:disc_only_copies` it's also possible to set custom path to the directory for storing database files using `persistence_dir` option in the configuration.

```elixir
config :ant,
  database: [
    persistence_strategy: :disc_copies,
    persistence_dir:
      "HOME"
      |> System.get_env()
      |> Path.join(["/sandbox", "/ant_sandbox", "/mnesia_db"])
      |> String.to_charlist()
  ]
```

Workers are stored in the database for 2 weeks. You can change this by setting `ttl` option:

```elixir
config :ant,
  database: [
    ttl: :timer.hours(24 * 7)
  ]
```

For storing data about workers indefinitely, set `ttl` to `:infinity`:

```elixir
config :ant,
  database: [
    ttl: :infinity
  ]
```

## Operations with Workers

1. `Ant.Workers.list_workers()` - returns a list of all workers
2. `Ant.Workers.get_worker(id)` - returns a worker by id
3. `Ant.Workers.delete_worker(worker)` - deletes a worker. It's not recommended to use this function directly.