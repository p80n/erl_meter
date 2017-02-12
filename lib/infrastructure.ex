defmodule ErlMeter.Infrastructure do
  @derive [Poison.Encoder]
  defstruct [:organization_id, :name, :id]

end
