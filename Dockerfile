FROM starefossen/ruby-node
ENV BUNDLER_VERSION=2.1.4
RUN apt-get update -qq && apt-get install -y
RUN apt-get -y install git vim
WORKDIR /samples_extraction
ADD Gemfile /samples_extraction
ADD Gemfile.lock /samples_extraction
ADD package.json /samples_extraction
ADD yarn.lock /samples_extraction
RUN gem install bundler
RUN bundle install
RUN yarn install

ADD . /samples_extraction/

# Compiling assets
RUN RAILS_ENV=production bundle exec rake assets:precompile
RUN RAILS_ENV=production bundle exec rake webpacker:compile

# Generating sha
RUN git rev-parse HEAD > REVISION
RUN git tag -l --points-at HEAD --sort -version:refname | head -1 > TAG
RUN git rev-parse --abbrev-ref HEAD > BRANCH
