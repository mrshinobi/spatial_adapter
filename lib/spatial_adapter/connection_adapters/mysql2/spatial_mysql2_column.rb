module SpatialAdapter
  module ConnectionAdapters
    class SpatialMysql2Column < ActiveRecord::ConnectionAdapters::Mysql2Column
      include SpatialAdapter::SpatialColumn
      
      #MySql-specific geometry string parsing. By default, MySql returns geometries in strict wkb format with "0" characters in the first 4 positions.
      def self.string_to_geometry(string)
        return string unless string.is_a?(String)
        GeoRuby::SimpleFeatures::Geometry.from_ewkb(string[4..-1])
      rescue Exception
        nil
      end
    end
  end
end
