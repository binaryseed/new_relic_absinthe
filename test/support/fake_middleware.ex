defmodule NewRelicAbsintheTest.FakeMiddleware do
  @behaviour Absinthe.Middleware

  @impl Absinthe.Middleware

  def call(res, _config) do
    res
  end
end
