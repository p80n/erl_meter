defmodule ErlMeter.Infrastructure do
  @derive {Poison.Encoder, except: [:id]}
  defstruct [:organization_id, :name, :id]

end
