defmodule NewRelic.Absinthe.Middleware do
  @deprecated "Absinthe is now auto-instrumented via `telemetry`, please remove manual instrumentation."
  def call(resolution, _config) do
    resolution
  end
end
