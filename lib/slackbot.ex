defmodule SlackBot do
  use Application
  use DefBot

  heard "temperature", tokens do
    IO.puts Enum.at(tokens, 0)
    temperature_message ""
  end

  heard "list rooms", tokens do
    "Rooms available: " <> Enum.join(rooms, ", ")
  end

  def start do
    start_link(Application.get_env(:slackbot, :key))
  end

  def rooms do
    ElixirCouchDb.serverConnection
    |> open_db("stasis")
    |> then(&fetch_view(&1, {"locations", "rooms"}, [:group]))
    |> then(&decode_room_names(&1))
    |> return
  end

  def temperature_message temp do
    ElixirCouchDb.serverConnection
    |> open_db("stasis")
    |> then(&fetch_view(&1, {"temperatures", "list_all"}))
    |> then(&decode_temperature_rows(&1))
    |> then(&Enum.sort(&1, fn a, b -> compare_by_time(a, b) end))
    |> then(&Enum.reduce(&1, %{}, fn x, acc ->
      case acc[x.r] do
        nil -> Map.put(acc, x.r, "#{x.time} #{x.r} #{x.h}% #{x.t}C")
        _ -> acc
      end
    end))
    |> then(&Map.to_list(&1))
    |> then(&Enum.map(&1, fn x -> elem(x, 1) end))
    |> IO.inspect
    |> then(&Enum.join(&1, "\n"))
    |> IO.inspect

  end

  defp compare_by_time(a, b) do
    a.time >= b.time
  end

  defp fetch_view(db, view, opts \\ []) do
    Couchex.fetch_view(db, view, opts)
  end

  defp open_db(server, db) do
    Couchex.open_db(server, db)
  end

  defp decode_room_names(rooms) do
    Enum.reduce(rooms, [], fn({[{_, k}, v]}, acc) ->
      [k | acc]
    end)
  end

  def decode_temperature_rows rows do
    {:ok,
      Enum.reduce(rows, [], fn {[_, _, {_, {[{_, t}, {_, h}, {_, r}, {_, time}]}}]}, acc ->
        [%{r: r, h: h, t: t, time: time} | acc]
      end)
    }
  end

  defp then(data, func) do
    try do
      case data do
        {:ok, result} -> func.(result)
        {:error, _} -> data
        _ -> func.(data)
      end
    rescue
      _ -> {:error, "Nope"}
    end
  end

  defp return(data) do
    case data do
      {:ok, val} -> val
      {:error, message} -> message
      _ -> data
    end
  end
end
