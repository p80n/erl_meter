defmodule ErlMeter.Organization do
  @derive [Poison.Encoder]
  defstruct [:name, :primary_contact, :id]

end
