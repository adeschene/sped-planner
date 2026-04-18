source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '~> 3.2.0'

gem 'rails', '~> 7.1.0'
gem 'puma', '~> 6.0'
gem 'bcrypt', '~> 3.1.7'
gem 'dartsass-rails'
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'jbuilder', '~> 2.11'
gem 'simple_calendar', '~> 3.0'
gem 'bootsnap', require: false
gem 'sprockets-rails'

group :production do
  gem 'pg', '~> 1.5'
end

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'web-console'
  gem 'rack-mini-profiler'
  gem 'sqlite3', '~> 1.6'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
