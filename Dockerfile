FROM alpine:3.10.2

LABEL version=1.1.2
LABEL description="BitBucket Server Exporter Utility for GitHub"
LABEL maintainer="GitHub Services <services@github.com>"

WORKDIR /opt/bbs-exporter

COPY Gemfile Gemfile.lock bbs_exporter.gemspec ./
COPY lib/bbs_exporter/version.rb lib/bbs_exporter/

RUN \
  DEPS=" \
    git \
    ruby \
    ruby-bigdecimal \
    ruby-json \
  " && \
  BUILD_DEPS=" \
    cmake \
    g++ \
    gcc \
    make \
    ncurses-dev \
    openssl-dev \
    ruby-dev \
  " && \
  \
  apk add $DEPS $BUILD_DEPS && \
  \
  bundler_version=$(sed -n '/^BUNDLED WITH$/{n;s/ *//g;p}' Gemfile.lock) && \
  gem install --no-document --version $bundler_version bundler && \
  \
  cpu_count=$(grep processor /proc/cpuinfo | wc -l) && \
  bundle config --global silence_root_warning 1 && \
  bundle install --without=development --jobs=$cpu_count && \
  \
  apk del $BUILD_DEPS && \
  rm /var/cache/apk/APKINDEX.*.tar.gz

CMD /bin/sh

COPY . .
