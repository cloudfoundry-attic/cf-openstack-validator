FROM ubuntu:16.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update; apt-get -y upgrade; apt-get clean

RUN apt-get install -y sudo curl wget make gcc zlib1g-dev libssl-dev ssh; apt-get clean

RUN mkdir /tmp/ruby-install && \
    cd /tmp && \
    curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.5.0 | tar -xz && \
    cd /tmp/ruby-install-0.5.0 && \
    make install && \
    rm -rf /tmp/ruby-install

RUN ruby-install --system ruby 2.3.1

RUN ["/bin/bash", "-l", "-c", "gem install bundler --no-ri --no-rdoc"]

RUN useradd -ms /bin/bash validator-ci
USER validator-ci

RUN wget -O ~/stemcell.tgz https://d26ekeud912fhb.cloudfront.net/bosh-stemcell/openstack/bosh-stemcell-3262.9-openstack-kvm-ubuntu-trusty-go_agent.tgz
