defmodule Padawan.Cache do
  @cache :padawan

  Cachex.__info__(:functions)
  |> Enum.each(fn {func, arity} ->
    if func != :child_spec do
      args = Macro.generate_arguments(arity - 1, __MODULE__)
      def unquote(func)(unquote_splicing(args)), do: apply(Cachex, unquote(func), [@cache | unquote(args)])
    end
  end)
end
