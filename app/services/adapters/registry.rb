module Adapters
  class Registry
    def self.for(connection)
      case connection.adapter
      when 'fake' then FakeNapCatAdapter.new(connection)
      when 'real' then RealNapCatAdapter.new(connection)
      else raise ArgumentError, "Unknown adapter #{connection.adapter}"
      end
    end
  end
end
