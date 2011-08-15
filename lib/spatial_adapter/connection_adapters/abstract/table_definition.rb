module SpatialAdapter
  module ConnectionAdapters
    module TableDefinition
      extend ActiveSupport::Concern

      included do
        SpatialAdapter::GEOMETRY_DATA_TYPES.keys.each do |column_type|
          class_eval <<-EOV
            def #{column_type}(*args)
              options = args.extract_options!
              column_names = args

              column_names.each { |name| column(name, '#{column_type}', options) }
            end
          EOV
        end
      end
    end
  end
end
