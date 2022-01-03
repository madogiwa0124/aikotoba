require_relative "lib/aikotoba/version"

Gem::Specification.new do |spec|
  spec.name = "aikotoba"
  spec.version = Aikotoba::VERSION
  spec.authors = ["Madogiwa"]
  spec.email = ["madogiwa0124@gmail.com"]
  spec.homepage = "https://github.com/madogiwa0124/aikotoba"
  spec.summary = "Aikotoba is a Rails engine that makes it easy to implement simple email and password authentication."
  spec.license = "MIT"
  spec.metadata["source_code_uri"] = "https://github.com/madogiwa0124/aikotoba"
  spec.files = Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", ">= 6.1.4"
  spec.add_dependency "argon2", "~> 2.1"
end
