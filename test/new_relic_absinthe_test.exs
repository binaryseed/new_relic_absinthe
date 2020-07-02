defmodule NewRelicAbsintheTest do
  use ExUnit.Case

  alias NewRelic.Harvest.Collector

  # Wire up and instrument our GraphQL Schema
  defmodule TestSchema do
    use Absinthe.Schema

    def middleware(middleware, _field, _object) do
      [NewRelic.Absinthe.Middleware, NewRelicAbsintheTest.FakeMiddleware] ++ middleware
    end

    query do
      field :hello, :string do
        resolve &TestSchema.hello_world/3
      end
    end

    def hello_world(_, _, _), do: {:ok, "World"}
  end

  # Wire up and instrument our Plug
  defmodule TestPlug do
    use Plug.Builder
    use NewRelic.Transaction

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      json_decoder: Jason

    plug Absinthe.Plug, schema: TestSchema, json_codec: Jason
  end

  # Start up our HTTP server
  @port 8881
  setup_all do
    start_supervised({Plug.Cowboy, [scheme: :http, plug: TestPlug, options: [port: @port]]})
    :ok
  end

  # Configure the Agent to be enabled
  setup do
    System.put_env("NEW_RELIC_APP_NAME", "TestApp")
    System.put_env("NEW_RELIC_HARVEST_ENABLED", "true")
    System.put_env("NEW_RELIC_LICENSE_KEY", "foo")

    on_exit(fn ->
      System.delete_env("NEW_RELIC_APP_NAME")
      System.delete_env("NEW_RELIC_HARVEST_ENABLED")
      System.delete_env("NEW_RELIC_LICENSE_KEY")
    end)

    :ok
  end

  test "Report expected events!" do
    restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
    restart_harvest_cycle(Collector.SpanEvent.HarvestCycle)

    data = query("query HelloWorld { hello }")
    assert data["hello"] == "World"

    [[_, tx_event]] = gather_harvest(Collector.TransactionEvent.Harvester)

    assert tx_event[:path] == "/graphql"
    assert tx_event[:"absinthe.operation_name"] == "HelloWorld"

    spans = gather_harvest(Collector.SpanEvent.Harvester)

    [resolver_event, _, _] =
      Enum.find(spans, fn [%{name: name}, _, _] ->
        name == "NewRelicAbsintheTest.TestSchema.hello_world/3"
      end)

    assert resolver_event[:"absinthe.schema"] == "NewRelicAbsintheTest.TestSchema"
    assert resolver_event[:"absinthe.type"] == "String"
    assert resolver_event[:traceId] == tx_event[:traceId]
  end

  defp query(query) do
    {:ok, %{body: body}} =
      http_request(
        "http://localhost:#{@port}/graphql",
        Jason.encode!(%{query: query})
      )

    body
    |> Jason.decode!()
    |> Map.fetch!("data")
  end

  defp restart_harvest_cycle(harvest_cycle) do
    GenServer.call(harvest_cycle, :restart)
  end

  defp gather_harvest(harvester) do
    Process.sleep(300)
    harvester.gather_harvest
  end

  def http_request(url, body) do
    request = {'#{url}', [], 'application/json', body}

    with {:ok, {{_, status_code, _}, _headers, body}} <-
           :httpc.request(:post, request, [], []) do
      {:ok, %{status_code: status_code, body: to_string(body)}}
    end
  end
end
