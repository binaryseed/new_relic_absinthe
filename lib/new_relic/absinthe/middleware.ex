defmodule NewRelic.Absinthe.Middleware do
  @behaviour Absinthe.Middleware

  @impl Absinthe.Middleware

  def call(%{middleware: [{{Absinthe.Resolution, :call}, resolver_fn} | _]} = res, _config) do
    start_time = System.system_time()
    start_time_mono = System.monotonic_time()

    {span, parent_span} =
      NewRelic.DistributedTrace.set_current_span(
        label: Absinthe.Resolution.path(res),
        ref: make_ref()
      )

    %{
      res
      | middleware:
          res.middleware ++
            [
              {{__MODULE__, :complete},
               [
                 resolver_mfa: resolver_mfa(resolver_fn),
                 start_time: start_time,
                 start_time_mono: start_time_mono,
                 span: span,
                 parent_span: parent_span
               ]}
            ]
    }
  end

  def call(res, _config), do: res

  def complete(%{state: :resolved} = res,
        resolver_mfa: {resolver_mod, resolver_fun, resolver_arity},
        start_time: start_time,
        start_time_mono: start_time_mono,
        span: span,
        parent_span: parent_span
      ) do
    end_time_mono = System.monotonic_time()
    path = Absinthe.Resolution.path(res) |> Enum.join(".")
    return_type = Absinthe.Type.name(res.definition.schema_node.type, res.schema)
    args = res.arguments |> Map.to_list()

    duration_ms =
      System.convert_time_unit(end_time_mono - start_time_mono, :native, :milliseconds)

    # TODO: only do once:
    # TODO: handle without operation.name
    operation = List.last(res.path)

    NewRelic.add_attributes(
      operation: operation.type,
      operation_name: operation.name,
      framework_name: "/Absinthe/#{inspect(res.schema)}/#{operation.type}/#{operation.name}"
    )

    NewRelic.DistributedTrace.reset_span(previous: parent_span)

    attributes = %{
      "absinthe.schema": inspect(res.schema),
      "absinthe.type": return_type,
      "absinthe.field_name": res.definition.name,
      "absinthe.path": path,
      "absinthe.parent_type": res.parent_type.name,
      args: inspect(args)
    }

    NewRelic.Transaction.Reporter.add_trace_segment(%{
      primary_name: "#{inspect(resolver_mod)}.#{resolver_fun}",
      secondary_name: "#{inspect(res.schema)}.#{path}",
      attributes: attributes,
      pid: inspect(self()),
      id: span,
      parent_id: parent_span || :root,
      start_time: start_time,
      start_time_mono: start_time_mono,
      end_time_mono: end_time_mono
    })

    NewRelic.report_span(
      timestamp_ms: System.convert_time_unit(start_time, :native, :milliseconds),
      duration_s: duration_ms / 1000,
      name: "#{inspect(resolver_mod)}.#{resolver_fun}/#{resolver_arity}",
      edge: [span: span, parent: parent_span || :root],
      category: "generic",
      attributes: Map.merge(NewRelic.DistributedTrace.get_span_attrs(), attributes)
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

  defp resolver_mfa({mod, fun}), do: {mod, fun, 3}

  defp resolver_mfa(fun) when is_function(fun) do
    info = Function.info(fun)
    {info[:module], info[:name], info[:arity]}
  end
end
