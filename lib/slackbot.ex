defmodule SlackBot do
  use Application
  use DefBot

  heard "temperature (.*)", tokens do
    IO.puts Enum.at(tokens, 0)
    result = room_temperature Enum.at(tokens, 1)

    if(Enum.empty? result) do
      "Not found"
    else
      temperature_message Enum.at(result, 0)
    end
  end

  heard "list rooms", tokens do
    "Rooms available: " <> Enum.join(rooms, ", ")
  end

  def start do
    start_link(Application.get_env(:slackbot, :key))
  end

  def dbprops do
    %{}
  end

  def room_temperature room do
    {:ok, result} = ElixirCouchDb.get dbprops, "stasis", "_design/temperatures/_view/by_room", %{group: true}
    Enum.filter(result["rows"], fn row -> row["key"] == room end)
  end

  def rooms do
    {:ok, result} = ElixirCouchDb.serverConnection
    |> Couchex.open_db("stasis")
    |> Tuple.to_list
    |> Enum.at(1)
    |> IO.inspect
    |> Couchex.fetch_view({"temperatures", "list_all"})

    Enum.each(result, &IO.inspect/1)
#{:ok, result} = ElixirCouchDb.get dbprops, "stasis", "_design/temperatures/_view/by_room", %{group: true}
#   Enum.reduce(result["rows"], [], fn row, acc -> acc ++ [row["key"]] end)
  end

  def temperature_message temp do
    "The #{temp["value"]["room"]} temperature is #{temp["value"]["t"]}C with humidity of #{temp["value"]["h"]}%"
  end
end
