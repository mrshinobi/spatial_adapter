module SpatialAdapter
  module ConnectionAdapters
    module IndexDefinition
      extend ActiveSupport::Concern

      included do
        attr_accessor :spatial
      end

      def initialize(table, name, unique, columns, spatial = false)
        super(table, name, unique, columns)
        @spatial = spatial
      end
    end
  end
end
