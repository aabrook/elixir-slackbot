defmodule SlackBot do
  use Application
  use Slack

  def start do
    start_link(Application.get_env(:slackbot, :key))
  end

  def dbprops do
    ElixirCouchDb.connection %{protocol: Application.get_env(:slackbot, :couchdb_protocol), host: Application.get_env(:slackbot, :couchdb_host), port: Application.get_env(:slackbot, :couchdb_port)}
  end

  def room_temperature room do
    {:ok, result} = ElixirCouchDb.get dbprops, "temperatures", "_design/temperatures/_view/by_room", %{group: true}
    Enum.filter(result["rows"], fn row -> row["key"] == room end)
  end

  def rooms do
    {:ok, result} = ElixirCouchDb.get dbprops, "temperatures", "_design/temperatures/_view/by_room", %{group: true}
    Enum.reduce(result["rows"], [], fn row, acc -> acc ++ [row["key"]] end)
  end

  def temperature_message temp do
    "The temperature is " <> temp["value"]["t"] <> "C with humidity of " <> temp["value"]["h"] <> "%"
  end

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    hears(message, slack)
  end
  def handle_message(_,_), do: :ok

  def handle_info({:message, text, channel}, slack) do
    IO.puts "Sending your message, captain!"

    send_message(text, channel, slack)

    {:ok, slack}
  end
  def handle_info(_, _), do: :ok

  def hears(message, slack) do
    hears = [
      %{regex: ~r/temperature (.*)/, cb: fn tokens, msg, slack ->
        IO.puts Enum.at(tokens, 0)
        result = room_temperature Enum.at(tokens, 1)
        if Enum.empty? result do
          send_message("Not found", message.channel, slack)
        else
          [t] = result
          send_message(temperature_message(t), message.channel, slack)
        end
      end},
      %{regex: ~r/list rooms/, cb: fn tokens, msg, slack ->
        result = Enum.join(rooms, ", ")
        send_message("Rooms available: " <> result, message.channel, slack)
      end},
      %{regex: ~r/^hello (.*)/i, cb: fn tokens, msg, slack -> send_message("Why hello " <> Enum.at(tokens, 1), message.channel, slack) end},
      %{regex: ~r/^sup$/i, cb: fn tokens, msg, slack -> send_message("Not much. Sup wit u?", message.channel, slack) end},
      %{regex: ~r/^sup (.*)/i, cb: fn tokens, msg, slack -> send_message("Not much " <> Enum.at(tokens, 1) <> ". Sup wit u", message.channel, slack) end}
    ]
  
    Enum.each(hears, fn(x) ->
      if Regex.match?(x[:regex], message[:text]) do
        x[:cb].(Regex.run(x[:regex], message[:text]), message, slack)
      end
    end)
  end
end
