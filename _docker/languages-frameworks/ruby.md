---
title: Ruby on Docker
weight: 48
tags:
  - ruby
  - languages
  - docker
category: Languages &amp; Frameworks
redirect_from:
  - /docker-integration/ruby/
---
In this article you will learn about setting up a Ruby based project, including Rails projects, on our Docker infrastructure. We will set up testing with RSpec and Cucumber, but the same applies to any other Ruby testing framework.

## Services and Steps
Before reading through the documentation please take a look at the [Services]({% link _docker/getting-started/services.md %}) and [Steps]({% link _docker/getting-started/steps.md %}) documentation page so you have a good understanding how services and steps on Codeship work.

## Dockerfile
We will start by creating a Dockerfile that lets you run your Ruby based test suite in Codeship.

Please take a look at our [Dockerfile Caching best practices]({{ site.baseurl }}{% link _docker/getting-started/caching.md %}) article first to make sure you build your Dockerfile in a way that only invalidates the Docker cache when necessary.

Following is an example Dockerfile with inline comments describing each step in the file.

```Dockerfile
# Article for Dockerfile at ADD_URL_FOR_THIS
# We're using the Ruby 2.2 base container and extend it
FROM ruby:2.2

# We install certain OS packages necessary for running our build
# Node.js needs to be installed for compiling assets
# libpq-dev is necessary for installing the pg gem
# libmysqlclient-dev is necessary for installing the mysql2 gem
RUN apt-get update && \
    apt-get install -yq \
      libmysqlclient-dev \
      libpq-dev \
      nodejs

# INSTALL any further tools you need here so they are cached in the docker build

# Create a directory for your application code and set it as the WORKDIR. All following commands will be run in this directory.
RUN mkdir /app
WORKDIR /app

# Set the Rails Environment to test
ENV RAILS_ENV test

# COPY Gemfile and Gemfile.lock and install dependencies before adding the full code so the cache only
# gets invalidated when dependencies are changed
COPY Gemfile Gemfile.lock ./
RUN gem install bundler
RUN bundle install -j20

# Copy the whole repository into the container
COPY . ./
```

This Dockerfile will give you a good starting point to install any further packages or tools you might need. Take a look at our [browser testing documentation]({{ site.baseurl }}{% link _docker/continuous-integration/browser-testing.md %}) to find and install any further tools you might need for your build.

## codeship-services.yml

The following example will use the Dockerfile we created to set up a container we call project_name (please change to your specific project name) that will run your build. We're adding a [PostgreSQL container](https://hub.docker.com/_/postgres/) and [Redis container](https://hub.docker.com/_/redis/) so the tests have access to those two services.

When accessing other containers please be aware that those services do not run on localhost, but on a different hostname, e.g. "postgres" or "mysql". If you reference localhost in any of your configuration files you have to change that to point to the hostname of the service you want to access. Setting them through environment variables and using those inside of your configuration files is the cleanest approach to setting up your build environment.

```yaml
project_name:
  build:
    image: organisation_name/project_name
    dockerfile_path: Dockerfile.ci
  # Linking Redis and Postgres into the container
  links:
    - redis
    - postgres
  # Set environment variables to connect to the service you need for your build. Those environment variables can overwrite settings from your configuration files (e.g. database.yml) if configured. Make sure that your environment variables and configuration files work work together as expected. Read more about Rails and database configuration in their Documentation: http://edgeguides.rubyonrails.org/configuring.html#configuring-a-database
  environment:
    - DATABASE_URL=postgres://postgres@postgres/YOUR_DATABASE_NAME
    - REDIS_URL=redis://redis
# Service definition that specify a version of the service through container tags
redis:
  image: redis:2.8
postgres:
  image: postgres:9.4
```

For more information about other services you can use with Codeship check out our [services and databases documentation]({{ site.baseurl }}{% link _docker/getting-started/services-and-databases.md %}).

## codeship-steps.yml

Now we're going to set up our steps file that contains a parallelized build configuration.

Every step in a build gets its own clean container and linked services. Any setup commands that are necessary to setup a linked container (e.g. database migrations) need to be run for every step. While this duplicates some of the work, it also makes sure your parallelized test commands run completely independently.

As a step can only have a single command the best way to set up the build is through scripts in your repository. You can then call those scripts in your step file.

In the following example we're testing an application with Cucumber and RSpec. We also use Brakeman to search for vulnerabilities and load our development seed data to make sure that doesn't break.

```yaml
- name: ci
  type: parallel
  steps:
  - name: features
    service: project_name
    command: script/ci features
  - name: specs
    service: project_name
    command: script/ci specs
  - name: brakeman
    service: project_name
    command: script/ci brakeman
  - name: seeds
    service: project_name
    command: script/ci seed
```

And here is the corresponding script file you can put into `script/ci`

```bash
#!/bin/bash
# Usage: script/ci [command]
# Run the test suite on a Codeship build machine.

# This makes sure the script fails on the first failing command
set -e

# Adding a check so an argument has to be passed to the container
COMMAND=${1:?'You need to pass a command as the first parameter!'}

# Create and init the database
bundle exec rake db:create db:migrate

case $COMMAND in
specs)
  bundle exec rspec spec
  ;;
features)
  bundle exec cucumber features
  ;;
brakeman)
  bundle exec brakeman
  ;;
seed)
  bundle exec rake db:seed
  ;;
esac
```

## Parallelisation with the parallel_tests gem

To get the most speed out of your builds you can use the [parallel_tests gem](https://github.com/grosser/parallel_tests) to automatically split up your test suite in different containers.

The following example will split your specs and features into two parts each. By setting the `SPLIT_NUMBER` on each split we define which group of tests should be run in this split. We're setting the `TOTAL_SPLITS` inline for each command, you can also set it in the environment settings of the main container in your `codeship-services.yml`

```yaml
- name: ci
  type: parallel
  steps:
  - name: specs_1
    service: project_name
    command: bash -c "TOTAL_SPLITS=2 SPLIT_NUMBER=1 script/ci spec"
  - name: specs_2
    service: project_name
    command: bash -c "TOTAL_SPLITS=2 SPLIT_NUMBER=2 script/ci spec"
  - name: features_1
    service: project_name
    command: bash -c "TOTAL_SPLITS=2 SPLIT_NUMBER=1 script/ci features"
  - name: features_2
    service: project_name
    command: bash -c "TOTAL_SPLITS=2 SPLIT_NUMBER=2 script/ci features"
  - name: brakeman
    service: project_name
    command: script/ci brakeman
  - name: seeds
    service: project_name
    command: script/ci seed
```

And here the corresponding `script/ci` file that will run each group of specs and features.

```bash
#!/bin/bash
# Usage: script/ci [command]
# Run the test suite on a Codeship build machine.

# This makes sure the script fails on the first failing command
set -e

# Adding a check so an argument has to be passed to the container
COMMAND=${1:?'You need to pass a command as the first parameter!'}

# Create and init the database
bundle exec rake db:create db:migrate

case $COMMAND in
spec)
  parallel_rspec -n $TOTAL_SPLITS --only-group $SPLIT_NUMBER spec
  ;;
features)
  parallel_cucumber -n $TOTAL_SPLITS --only-group $SPLIT_NUMBER features
  ;;
brakeman)
  bundle exec brakeman
  ;;
seed)
  bundle exec rake db:seed
  ;;
esac
```
