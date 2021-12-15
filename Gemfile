source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in aikotoba.gemspec.
gemspec

group :development do
  gem "brakeman"
  gem "standard"
  gem "letter_opener_web"
end

group :development, :test do
  gem "bcrypt"
  gem "sqlite3"
  gem "capybara"
  gem "webrick"
  gem "webdrivers"
end

# To use a debugger
# gem 'byebug', group: [:development, :test]
