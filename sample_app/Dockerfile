FROM ruby:latest
RUN mkdir -pm 770 /var/www/sample_app
WORKDIR /var/www/sample_app
COPY Gemfile /var/www/sample_app/Gemfile
COPY Gemfile.lock /var/www/sample_app/Gemfile.lock
RUN gem update
RUN gem install bundler
RUN bundle install

EXPOSE 3000

# Start the main process.
CMD ["rails", "server", "-b", "0.0.0.0"]