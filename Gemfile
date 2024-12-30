source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in aikotoba.gemspec.
gemspec

group :development do
  gem "letter_opener_web"
  gem "brakeman", require: false
end

group :development, :test do
  gem "net-smtp"
  gem "webrick"
  gem "sqlite3", "~> 2.5"
  gem "sprockets-rails"
  gem "standard", require: false
end

group :test do
  gem "capybara", require: false
  gem "webdrivers"
  gem "simplecov", require: false
end

# To use a debugger
# gem 'byebug', group: [:development, :test]
