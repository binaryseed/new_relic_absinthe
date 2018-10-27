defmodule NewRelic.Absinthe.Middleware do
  @behaviour Absinthe.Middleware

  @impl Absinthe.Middleware
  def call(%{middleware: [{Absinthe.Middleware.MapGet, _field}]} = res, _config) do
    res
  end

  def call(res, _config) do
    start_time = System.system_time()
    start_time_mono = System.monotonic_time()

    %{
      res
      | middleware: res.middleware ++ [{{__MODULE__, :complete}, {start_time, start_time_mono}}]
    }
  end

  def complete(%{state: :resolved} = res, {start_time, start_time_mono}) do
    end_time_mono = System.monotonic_time()

    # TODO: only do once:
    operation = List.last(res.path)

    NewRelic.add_attributes(
      operation: operation.type,
      operation_name: operation.name,
      framework_name: "/Absinthe/#{inspect(res.schema)}/#{operation.type}/#{operation.name}"
    )

    path = Absinthe.Resolution.path(res) |> Enum.join("->")
    return_type = Absinthe.Type.name(res.definition.schema_node.type, res.schema)
    args = res.arguments |> Map.to_list()

    NewRelic.Tracer.Report.call(
      {res.schema, path, args},
      return_type |> String.to_atom(),
      self(),
      {start_time, start_time_mono, end_time_mono}
    )

    # TODO: Track logical nesting?

    res
  end
end
