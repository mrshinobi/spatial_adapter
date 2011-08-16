# This file should typically not be directly require'd into your project. You
# should require the database-specific adapter you desire, e.g.
#
#   require 'spatial_adapter/postgresql'
#
# Why is this file here?
#
# Mostly to keep Rails happy when using config.gem to specify dependencies.
# The Rails init code (rails/init.rb) will then load the adapter that matches
# your database.yml configuration.

module SpatialAdapter
  extend ActiveSupport::Autoload

  autoload :RawGeomInfo
  autoload :SpatialColumn
  autoload :SchemaDumper

  module ConnectionAdapters
    extend ActiveSupport::Autoload

    autoload :MysqlAdapter
    autoload :Mysql2Adapter
    autoload :PostgresqlAdapter

    autoload_under 'abstract' do
      autoload :IndexDefinition
      autoload :TableDefinition
    end

    autoload_under 'mysql' do
      autoload :SpatialMysqlColumn
    end
    autoload_under 'mysql2' do
      autoload :SpatialMysql2Column
    end
    autoload_under 'postgresql' do
      autoload :PostgresqlColumnDefinition
      autoload :PostgresqlTableDefinition
      autoload :SpatialPostgresqlColumn
    end
  end

  # Translation of geometric data types
  GEOMETRY_DATA_TYPES = {
    :point => { :name => "POINT" },
    :line_string => { :name => "LINESTRING" },
    :polygon => { :name => "POLYGON" },
    :geometry_collection => { :name => "GEOMETRYCOLLECTION" },
    :multi_point => { :name => "MULTIPOINT" },
    :multi_line_string => { :name => "MULTILINESTRING" },
    :multi_polygon => { :name => "MULTIPOLYGON" },
    :geometry => { :name => "GEOMETRY"}
  }

  class << self
    def initialize!(adapter)
      ActiveRecord::SchemaDumper.class_eval do
        include SpatialAdapter::SchemaDumper
      end

      ActiveRecord::ConnectionAdapters::IndexDefinition.class_eval do
        include SpatialAdapter::ConnectionAdapters::IndexDefinition
      end

      ActiveRecord::ConnectionAdapters::TableDefinition.class_eval do
        include SpatialAdapter::ConnectionAdapters::TableDefinition
      end

      case adapter
      when 'mysql'
        SpatialAdapter::ConnectionAdapters::MysqlAdapter
      when 'mysql2'
        SpatialAdapter::ConnectionAdapters::Mysql2Adapter
      when 'postgresql'
        SpatialAdapter::ConnectionAdapters::PostgresqlAdapter
      else
        raise SpatialAdapter::NotCompatibleError.new("spatial_adapter does not currently support the #{adapter} database.")
      end
    end
  end

  class NotCompatibleError < ::StandardError
  end
end

require 'spatial_adapter/railtie' if defined?(Rails::Railtie)
