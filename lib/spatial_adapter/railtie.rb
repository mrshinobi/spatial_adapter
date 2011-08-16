module SpatialAdapter
  class Railtie < Rails::Railtie
    initializer "spatial_adapter.load_current_database_adapter" do
      SpatialAdapter.initialize!(ActiveRecord::Base.configurations[Rails.env]['adapter'])
    end
  end
end
