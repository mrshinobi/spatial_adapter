module SpatialAdapter
  module ConnectionAdapters
    module PostgresqlAdapter
      extend ActiveSupport::Concern

      included do
        alias_method_chain :native_database_types, :spatial_types
        alias_method_chain :type_cast, :spatial_support
        alias_method_chain :quote, :spatial_support
        alias_method_chain :add_column, :spatial_support
        alias_method_chain :remove_column, :spatial_support
      end

      def native_database_types_with_spatial_types
        native_database_types_without_spatial_types.merge(SpatialAdapter::GEOMETRY_DATA_TYPES)
      end

      def postgis_version
        select_value("SELECT postgis_full_version()").scan(/POSTGIS="([\d\.]*)"/)[0][0]
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def postgis_major_version
        version = postgis_version
        version ? version.scan(/^(\d)\.\d\.\d$/)[0][0].to_i : nil
      end

      def postgis_minor_version
        version = postgis_version
        version ? version.scan(/^\d\.(\d)\.\d$/)[0][0].to_i : nil
      end

      def spatial?
        !postgis_version.nil?
      end

      def supports_geographic?
        postgis_major_version > 1 || (postgis_major_version == 1 && postgis_minor_version >= 5)
      end

      def type_cast_with_spatial_support(value, column)
        if value.kind_of?(GeoRuby::SimpleFeatures::Geometry)
          value.as_hex_ewkb
        else
          type_cast_without_spatial_support(value, column)
        end
      end

      #Redefines the quote method to add behaviour for when a Geometry is encountered
      def quote_with_spatial_support(value, column = nil)
        if value.kind_of?(GeoRuby::SimpleFeatures::Geometry)
          "'#{value.as_hex_ewkb}'"
        else
          quote_without_spatial_support(value, column)
        end
      end

      def create_table(table_name, options = {})
        # Using the subclassed table definition
        table_definition = SpatialAdapter::ConnectionAdapters::PostgresqlTableDefinition.new(self)
        table_definition.primary_key(options[:primary_key] || ActiveRecord::Base.get_primary_key(table_name.to_s.singularize)) unless options[:id] == false

        yield table_definition if block_given?

        if options[:force] && table_exists?(table_name)
          drop_table(table_name, options)
        end

        create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
        create_sql << "#{quote_table_name(table_name)} ("
        create_sql << table_definition.to_sql
        create_sql << ") #{options[:options]}"

        # This is the additional portion for PostGIS
        unless table_definition.geom_columns.nil?
          table_definition.geom_columns.each do |geom_column|
            geom_column.table_name = table_name
            create_sql << "; " + geom_column.to_sql
          end
        end

        execute create_sql
      end

      def remove_column_with_spatial_support(table_name, *column_names)
        column_names = column_names.flatten
        columns(table_name).each do |col|
          if column_names.include?(col.name.to_sym)
            # Geometry columns have to be removed using DropGeometryColumn
            if col.is_a?(SpatialColumn) && col.spatial? && !col.geographic?
              execute "SELECT DropGeometryColumn('#{table_name}','#{col.name}')"
            else
              remove_column_without_spatial_support(table_name, col.name)
            end
          end
        end
      end

      def tables_without_postgis
        tables - %w{ geometry_columns spatial_ref_sys }
      end

      def column_spatial_info(table_name)
        constr = query("SELECT * FROM geometry_columns WHERE f_table_name = '#{table_name}'")

        raw_geom_infos = {}
        constr.each do |constr_def_a|
          raw_geom_infos[constr_def_a[3]] ||= SpatialAdapter::RawGeomInfo.new
          raw_geom_infos[constr_def_a[3]].type = constr_def_a[6]
          raw_geom_infos[constr_def_a[3]].dimension = constr_def_a[4].to_i
          raw_geom_infos[constr_def_a[3]].srid = constr_def_a[5].to_i

          if raw_geom_infos[constr_def_a[3]].type[-1] == ?M
            raw_geom_infos[constr_def_a[3]].with_m = true
            raw_geom_infos[constr_def_a[3]].type.chop!
          else
            raw_geom_infos[constr_def_a[3]].with_m = false
          end
        end

        raw_geom_infos.each_value do |raw_geom_info|
          #check the presence of z and m
          raw_geom_info.convert!
        end

        raw_geom_infos
      end

      def columns(table_name, name = nil) #:nodoc:
        raw_geom_infos = column_spatial_info(table_name)

        column_definitions(table_name).collect do |name, type, default, notnull|
          case type
          when /geography/i
            SpatialAdapter::ConnectionAdapters::SpatialPostgresqlColumn.create_from_geography(name, default, type, notnull == 'f')
          when /geometry/i
            raw_geom_info = raw_geom_infos[name]
            if raw_geom_info.nil?
              # This column isn't in the geometry_columns table, so we don't know anything else about it
              SpatialAdapter::ConnectionAdapters::SpatialPostgresqlColumn.create_simplified(name, default, notnull == "f")
            else
              SpatialAdapter::ConnectionAdapters::SpatialPostgresqlColumn.new(name, default, raw_geom_info.type, notnull == "f", raw_geom_info.srid, raw_geom_info.with_z, raw_geom_info.with_m)
            end
          else
            ActiveRecord::ConnectionAdapters::PostgresqlColumn.new(name, default, type, notnull == "f")
          end
        end
      end

      def add_column_with_spatial_support(table_name, column_name, type, options = {})
        unless SpatialAdapter::GEOMETRY_DATA_TYPES[type].nil?
          geom_column = SpatialAdapter::ConnectionAdapters::PostgresqlColumnDefinition.new(self, column_name, type, nil, nil, options[:null], options[:srid] || -1 , options[:with_z] || false , options[:with_m] || false, options[:geographic] || false)
          if geom_column.geographic
            default = options[:default]
            notnull = options[:null] == false

            execute("ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{geom_column.to_sql}")

            change_column_default(table_name, column_name, default) if options_include_default?(options)
            change_column_null(table_name, column_name, false, default) if notnull
          else
            geom_column.table_name = table_name
            execute geom_column.to_sql
          end
        else
          add_column_without_spatial_support(table_name, column_name, type, options)
        end
      end

      # Adds an index to a column.
      def add_index(table_name, column_name, options = {})
        column_names = Array(column_name)
        index_name   = index_name(table_name, :column => column_names)

        if Hash === options # legacy support, since this param was a string
          index_type = options[:unique] ? "UNIQUE" : ""
          index_name = options[:name] || index_name
          index_method = options[:spatial] ? 'USING GIST' : ""
        else
          index_type = options
        end
        quoted_column_names = column_names.map { |e| quote_column_name(e) }.join(", ")
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} #{index_method} (#{quoted_column_names})"
      end

      # Returns the list of all indexes for a table.
      #
      # This is a full replacement for the ActiveRecord method and as a result
      # has a higher probability of breaking in future releases.
      def indexes(table_name, name = nil)
         schemas = schema_search_path.split(/,/).map { |p| quote(p) }.join(',')

         # Changed from upstread: link to pg_am to grab the index type (e.g. "gist")
         result = query(<<-SQL, name)
           SELECT distinct i.relname, d.indisunique, d.indkey, t.oid, am.amname
             FROM pg_class t, pg_class i, pg_index d, pg_attribute a, pg_am am
           WHERE i.relkind = 'i'
             AND d.indexrelid = i.oid
             AND d.indisprimary = 'f'
             AND t.oid = d.indrelid
             AND t.relname = '#{table_name}'
             AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname IN (#{schemas}) )
             AND i.relam = am.oid
             AND a.attrelid = t.oid
          ORDER BY i.relname
        SQL

        indexes = result.map do |row|
          index_name = row[0]
          unique = row[1] == 't'
          indkey = row[2].split(" ")
          oid = row[3]
          indtype = row[4]

          # Changed from upstream: need to get the column types to test for spatial indexes
          columns = query(<<-SQL, "Columns for index #{row[0]} on #{table_name}").inject({}) {|attlist, r| attlist[r[1]] = [r[0], r[2]]; attlist}
          SELECT a.attname, a.attnum, t.typname
          FROM pg_attribute a, pg_type t
          WHERE a.attrelid = #{oid}
          AND a.attnum IN (#{indkey.join(",")})
          AND a.atttypid = t.oid
          SQL

          # Only GiST indexes on spatial columns denote a spatial index
          spatial = indtype == 'gist' && columns.size == 1 && (columns.values.first[1] == 'geometry' || columns.values.first[1] == 'geography')

          column_names = indkey.map {|attnum| columns[attnum] ? columns[attnum][0] : nil }
          ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, index_name, unique, column_names, spatial)
        end
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, SpatialAdapter::ConnectionAdapters::PostgresqlAdapter)
