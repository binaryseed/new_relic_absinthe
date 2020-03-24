defmodule NewRelic.Absinthe.Middleware do
  @behaviour Absinthe.Middleware

  @impl Absinthe.Middleware

  def call(%{middleware: middleware} = res, _config) do
    res_middleware =
      middleware |> Enum.find(&match?({{Absinthe.Resolution, :call}, _resolver_fn}, &1))

    if res_middleware do
      {_, resolver_fn} = res_middleware
      instrument(res, resolver_fn)
    else
      res
    end
  end

  def call(res, _config), do: res

  defp instrument(res, resolver_fn) do
    start_time = System.system_time()
    start_time_mono = System.monotonic_time()

    instrument_operation(res.acc[__MODULE__], res)

    %{
      res
      | acc: Map.put_new(res.acc, __MODULE__, :instrumented_operation),
        middleware:
          res.middleware ++
            [
              {{__MODULE__, :complete},
               [
                 resolver_mfa: resolver_mfa(resolver_fn),
                 start_time: start_time,
                 start_time_mono: start_time_mono
               ]}
            ]
    }
  end

  def complete(%{state: :resolved} = res,
        resolver_mfa: {resolver_mod, resolver_fun, resolver_arity},
        start_time: start_time,
        start_time_mono: start_time_mono
      ) do
    end_time_mono = System.monotonic_time()
    path = Absinthe.Resolution.path(res) |> Enum.join(".")
    type = Absinthe.Type.name(res.definition.schema_node.type, res.schema)
    args = res.arguments |> Map.to_list()
    span = {Absinthe.Resolution.path(res), make_ref()}

    duration_ms = System.convert_time_unit(end_time_mono - start_time_mono, :native, :millisecond)

    attributes = %{
      "absinthe.instrumentation": "resolver_function",
      "absinthe.schema": inspect(res.schema),
      "absinthe.type": type,
      "absinthe.field_name": res.definition.name,
      "absinthe.query_path": path,
      "absinthe.parent_type": res.parent_type.name,
      args: inspect(args)
    }

    NewRelic.Transaction.Reporter.add_trace_segment(%{
      primary_name: "#{inspect(resolver_mod)}.#{resolver_fun}",
      secondary_name: "#{inspect(res.schema)}.#{path}",
      attributes: attributes,
      pid: inspect(self()),
      id: span,
      parent_id: :root,
      start_time: start_time,
      start_time_mono: start_time_mono,
      end_time_mono: end_time_mono
    })

    NewRelic.report_span(
      timestamp_ms: System.convert_time_unit(start_time, :native, :millisecond),
      duration_s: duration_ms / 1000,
      name: "#{inspect(resolver_mod)}.#{resolver_fun}/#{resolver_arity}",
      edge: [span: span, parent: :root],
      category: "generic",
      attributes: attributes
    )

    NewRelic.report_aggregate(
      %{
        name: :AbsintheResolverTrace,
        resolver: "#{inspect(resolver_mod)}.#{resolver_fun}/#{resolver_arity}"
      },
      %{duration_ms: duration_ms, call_count: 1}
    )

    res
  end

  defp instrument_operation(:instrumented_operation, _res), do: :ignore

  defp instrument_operation(_, res) do
    operation = List.last(res.path)

    framework_name =
      case operation.name do
        nil -> "/Absinthe/#{inspect(res.schema)}/#{operation.type}"
        name -> "/Absinthe/#{inspect(res.schema)}/#{operation.type}/#{name}"
      end

    NewRelic.add_attributes(
      "absinthe.schema": inspect(res.schema),
      "absinthe.query_complexity": operation.complexity,
      "absinthe.operation_type": operation.type,
      "absinthe.operation_name": operation.name,
      framework_name: framework_name
    )
  end

  defp resolver_mfa({mod, fun}), do: {mod, fun, 3}

  defp resolver_mfa(fun) when is_function(fun) do
    info = Function.info(fun)
    {info[:module], info[:name], info[:arity]}
  end
end
