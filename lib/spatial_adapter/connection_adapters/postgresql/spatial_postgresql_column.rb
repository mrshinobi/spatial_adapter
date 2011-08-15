module SpatialAdapter
  module ConnectionAdapters
    class SpatialPostgresqlColumn < ActiveRecord::ConnectionAdapters::PostgreSQLColumn
      include SpatialAdapter::SpatialColumn

      def initialize(name, default, sql_type = nil, null = true, srid=-1, with_z=false, with_m=false, geographic = false)
        super(name, default, sql_type, null, srid, with_z, with_m)
        @geographic = geographic
      end

      def geographic?
        @geographic
      end
      
      #Transforms a string to a geometry. PostGIS returns a HewEWKB string.
      def self.string_to_geometry(string)
        return string unless string.is_a?(String)
        GeoRuby::SimpleFeatures::Geometry.from_hex_ewkb(string) rescue nil
      end

      def self.create_simplified(name, default, null = true)
        new(name, default, "geometry", null)
      end
      
      def self.create_from_geography(name, default, sql_type, null = true)
        params = extract_geography_params(sql_type)
        new(name, default, sql_type, null, params[:srid], params[:with_z], params[:with_m], true)
      end
      
      private
      
      # Add detection of PostGIS-specific geography columns
      def geometry_simplified_type(sql_type)
        case sql_type
        when /geography\(point/i then :point
        when /geography\(linestring/i then :line_string
        when /geography\(polygon/i then :polygon
        when /geography\(multipoint/i then :multi_point
        when /geography\(multilinestring/i then :multi_line_string
        when /geography\(multipolygon/i then :multi_polygon
        when /geography\(geometrycollection/i then :geometry_collection
        when /geography/i then :geometry
        else
          super
        end
      end

      def self.extract_geography_params(sql_type)
        params = {
          :srid => 0,
          :with_z => false,
          :with_m => false
        }
        if sql_type =~ /geography(?:\((?:\w+?)(Z)?(M)?(?:,(\d+))?\))?/i
          params[:with_z] = $1 == 'Z'
          params[:with_m] = $2 == 'M'
          params[:srid]   = $3.to_i
        end
        params
      end
    end
  end
end
