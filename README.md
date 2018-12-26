# New Relic Absinthe

This package adds `Absinthe` specific instrumentation on top of the new_relic_agent package. You may use all the built-in capabilities of the New Relic Agent!

Check out the agent for more:

* https://github.com/newrelic/elixir_agent
* https://hexdocs.pm/new_relic_agent

## Installation

Install the [Hex package](https://hex.pm/packages/new_relic_absinthe)

```elixir
defp deps do
  [
    {:new_relic_absinthe, "~> 0.1"},
    {:absinthe, "~> 1.4"},
    {:plug_cowboy, "~> 2.0"}
  ]
end
```

## Configuration

* You must configure `new_relic_agent` to authenticate to New Relic. Please see: https://github.com/newrelic/elixir_agent/#configuration

## Instrumentation

* Add the middleware

Define a custom middleware stack to install the instrumentation

```elixir
def middleware(middleware, _field, _object) do
  [NewRelic.Absinthe.Middleware] ++ middleware
end
```

#### Tips

* Use GraphQL's `OperationName`

Transaction grouping is difficult with GraphQL since all queries go to one endpoint. Setting an Operation Name in your query enables improved Transaction grouping

```graphql
query MyOperationName {
  user {
    id
  }
}
```

* Prefer named to anonymous resolvers for better span reporting:

When you name your resolver, it makes your span names much more readable.

```elixir
resolve {MyMod, :function}
resolve &MyMod.function/3
```

Instead of:

```elixir
resolve fn args, res ->
  MyMod.function(args, res)
end
```

Anonymous functions in Elixir do have a name, but they look like this: `-__absinthe_type__/1-fun-1-`
