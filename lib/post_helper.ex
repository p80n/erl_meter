defmodule ErlMeter.PostHelper do

  def api_base do
    "#{Application.get_env(:erl_meter, :protocol)}://#{Application.get_env(:erl_meter, :host)}:#{Application.get_env(:erl_meter, :port)}/api/v1"
  end

  def post(endpoint, struct) do
    url = "#{api_base}/#{endpoint}"
    IO.puts url
    {:ok, body} = Poison.encode(struct)
    headers = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
     case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        "Not found :("
     {:ok, %HTTPoison.Response{status_code: 422, body: body }} ->
        "422: #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        reason
    end
  end

end
