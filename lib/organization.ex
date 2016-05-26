defmodule ErlMeter.Organization do
  @derive {Poison.Encoder, except: [:id]}
  defstruct [:name, :primary_contact, :id]

end
