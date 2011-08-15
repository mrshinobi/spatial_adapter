module SpatialAdapter
  module ConnectionAdapters
    class PostgresqlTableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
      attr_reader :geom_columns

      def column(name, type, options = {})
        unless (SpatialAdapter::GEOMETRY_DATA_TYPES[type.to_sym].nil? or
                (options[:create_using_addgeometrycolumn] == false))

          column = self[name] || PostgresqlColumnDefinition.new(@base, name, type)
          column.null = options[:null]
          column.srid = options[:srid] || -1
          column.with_z = options[:with_z] || false
          column.with_m = options[:with_m] || false
          column.geographic = options[:geographic] || false

          if column.geographic
            @columns << column unless @columns.include? column
          else
            # Hold this column for later
            @geom_columns ||= []
            @geom_columns << column
          end
          self
        else
          super
        end
      end
    end
  end
end
