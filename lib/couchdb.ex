defmodule ElixirCouchDb do

  def connection opts \\ %{} do
    options = Map.merge(%{
                          protocol: Application.get_env(:slackbot,:couchdb_protocol),
                          host:     Application.get_env(:slackbot,:couchdb_host),
                          port: Application.get_env(:slackbot,:couchdb_port),
                          cache: nil,
                          timeout: 5000,
                          auth: nil
                        }, opts)

    baseUrl = "#{options[:protocol]}://#{options[:host]}:#{options[:port]}"
    Map.merge(options, %{baseUrl: baseUrl})
  end

  def default_auth do
    [
      {:basic_auth, {
        Application.get_env(:slackbot,:couchdb_username),
        Application.get_env(:slackbot,:couchdb_password)
      }}
    ]
  end

  def serverConnection opts \\ %{} do
    opts
    |> connection
    |> Map.fetch!(:baseUrl)
    |> Couchex.server_connection(default_auth)
  end

  def getRequest options, target, query do
    HTTPotion.get options.baseUrl <> "/" <> target, query: query
  end

  def postRequest options, target, query do
    HTTPotion.post options.baseUrl <> "/" <> target, query: query
  end

  def deleteRequest options, target, query do
    HTTPotion.post options.baseUrl <> "/" <> target, query: query
  end

  def putRequest options, target, query do
    HTTPotion.post options.baseUrl <> "/" <> target, query: query
  end

  def listDatabases options do
    parseResult(getRequest options, "_all_dbs", %{})
  end

  def get options, dbname, uri, query do
    parseResult(getRequest options, dbname <> "/" <> uri, query)
  end

  def create options, dbname do
    parseResult(putRequest options, dbname, %{})
  end

  def drop options, dbname do
    parseResult(deleteRequest options, dbname, %{})
  end

  def insert options, dbname, data do
    parseResult(postRequest options, dbname, data)
  end

  def update options, dbname, data do
    if (!data[:_id] || !data[:_rev]) do
      {:error, %{ message: "An _id and _rev must b provided" } }
    else
      parseResult(putRequest options, dbname <> "/" <> data[:_id], data)
    end
  end

  def del options, dbname, data do
    if (!data[:_id] || !data[:_rev]) do
      {:error, %{ message: "An _id and _rev must b provided" } }
    else
      parseResult(deleteRequest options, dbname <> "/" <> data[:_id], %{rev: data[:_rev]})
    end
  end

  def parseResult result do
    (result.status_code == 200 && successMessage result) || errorMessage result
  end

  def errorMessage result do
    {:error, %{status_code: result.status_code,
      message: result.message}}
  end

  def successMessage result do
    {:ok, Poison.decode! result.body}
  end

end
