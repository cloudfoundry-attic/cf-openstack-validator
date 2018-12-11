FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update; apt-get -y upgrade; apt-get clean
RUN apt-get install -y ssh curl wget make libssl-dev jq; apt-get clean

# install newest git CLI
RUN apt-get install software-properties-common -y; \
    add-apt-repository ppa:git-core/ppa -y; \
    apt-get update; \
    apt-get install git -y

RUN mkdir /tmp/ruby-install && \
    cd /tmp && \
    curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.5.0 | tar -xz && \
    cd /tmp/ruby-install-0.5.0 && \
    make install && \
    rm -rf /tmp/ruby-install

RUN ruby-install --system ruby 2.3.1

RUN ["/bin/bash", "-l", "-c", "gem install bundler --no-ri --no-rdoc"]

RUN useradd -ms /bin/bash -G sudo validator-ci
RUN echo "%sudo ALL = NOPASSWD: ALL" >> /etc/sudoers.d/sudo_group

USER validator-ci
