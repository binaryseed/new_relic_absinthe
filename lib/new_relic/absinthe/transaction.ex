defmodule NewRelic.Absinthe.Transaction do
  defmacro __using__(_) do
    quote do
      plug(NewRelic.Transaction.Plug)
      plug(NewRelic.DistributedTrace.Plug)
    end
  end
end
