module SpatialAdapter
  class Railtie < Rails::Railtie
    initializer "spatial_adapter.load_current_database_adapter" do
      ActiveSupport.on_load :active_record do

        ActiveRecord::SchemaDumper.class_eval do
          include SpatialAdapter::SchemaDumper
        end

        ActiveRecord::ConnectionAdapters::IndexDefinition.class_eval do
          include SpatialAdapter::ConnectionAdapters::IndexDefinition
        end

        ActiveRecord::ConnectionAdapters::TableDefinition.class_eval do
          include SpatialAdapter::ConnectionAdapters::TableDefinition
        end

        case ActiveRecord::Base.configurations[Rails.env]['adapter']
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
  end
end
