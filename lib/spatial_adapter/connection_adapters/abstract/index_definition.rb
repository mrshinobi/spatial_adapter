module SpatialAdapter
  module ConnectionAdapters
    module IndexDefinition
      extend ActiveSupport::Concern

      included do
        attr_accessor :spatial
        alias_method_chain :initialize, :spatial_support
      end

      def initialize_with_spatial_support(table, name, unique, columns, spatial = false)
        initialize_without_spatial_support(table, name, unique, columns)
        @spatial = spatial
      end
    end
  end
end
