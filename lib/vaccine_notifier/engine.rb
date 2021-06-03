module VaccineNotifier
  class Engine < ::Rails::Engine
    isolate_namespace VaccineNotifier
    initializer "vaccine_notifier.assets.precompile" do |app|
      app.config.assets.precompile << "vaccine_notifier_manifest.js"
    end
  end
end
