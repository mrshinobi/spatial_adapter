module SpatialAdapter
  module ConnectionAdapters
    class PostgresqlColumnDefinition < ActiveRecord::ConnectionAdapters::ColumnDefinition
      attr_accessor :table_name, :srid, :with_z, :with_m, :geographic
      attr_reader :spatial

      def initialize(base = nil, name = nil, type=nil, limit=nil, default=nil, null=nil, srid=-1, with_z=false, with_m=false, geographic=false)
        super(base, name, type, limit, default, null)
        @table_name = nil
        @spatial = true
        @srid = srid
        @with_z = with_z
        @with_m = with_m
        @geographic = geographic
      end
      
      def sql_type
        if geographic
          type_sql = SpatialAdapter::GEOMETRY_DATA_TYPES[type.to_sym][:name]
          type_sql += "Z" if with_z
          type_sql += "M" if with_m
          # SRID is not yet supported (defaults to 4326)
          #type_sql += ", #{srid}" if (srid && srid != -1)
          type_sql = "geography(#{type_sql})"
          type_sql
        else
          super
        end
      end
      
      def to_sql
        if spatial && !geographic
          type_sql = SpatialAdapter::GEOMETRY_DATA_TYPES[type.to_sym][:name]
          type_sql += "M" if with_m and !with_z
          dimension =
            if with_m and with_z
              4
            elsif with_m or with_z
              3
            else
              2
            end
        
          column_sql = "SELECT AddGeometryColumn('#{table_name}','#{name}',#{srid},'#{type_sql}',#{dimension})"
          column_sql += ";ALTER TABLE #{table_name} ALTER #{name} SET NOT NULL" if null == false
          column_sql
        else
          super
        end
      end
    end
  end
end
