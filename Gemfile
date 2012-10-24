source :rubygems
gemspec

gem "rake"

group :development, :test do
  gem "rspec", "~> 2.11"

  gem "sinatra", "~> 1.3"
  gem "json"
  gem "faraday", "~> 0.8.4"

  if RUBY_PLATFORM == "java"
    gem "spoon"
  end

  unless ENV["CI"]
    gem "guard-rspec", "~> 0.7"
    gem 'rb-fsevent', '~> 0.9.1'
  end
end
