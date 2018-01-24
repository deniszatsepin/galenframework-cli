FROM ubuntu:16.04
LABEL authors="Martin Reinhardt <contact@martinreinhardt-online.de>"

ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 6.11.4
ENV GALEN_VERSION 2.3.5
ENV TEST_HOME /var/jenkins_home

#================================================
# Customize sources for apt-get
#================================================
RUN  echo "deb http://archive.ubuntu.com/ubuntu xenial main universe\n" > /etc/apt/sources.list \
  && echo "deb http://archive.ubuntu.com/ubuntu xenial-updates main universe\n" >> /etc/apt/sources.list \
  && echo "deb http://security.ubuntu.com/ubuntu xenial-security main universe\n" >> /etc/apt/sources.list

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

#========================
# Miscellaneous packages
# Includes minimal runtime used for executing non GUI Java programs
#========================
RUN apt-get -qqy update \
  && apt-get -qqy --no-install-recommends install \
    bzip2 \
    ca-certificates \
    openjdk-8-jre-headless \
    tzdata \
    sudo \
    unzip \
    wget \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
  && sed -i 's/securerandom\.source=file:\/dev\/random/securerandom\.source=file:\/dev\/urandom/' ./usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/java.security

#===================
# Timezone settings
# Possible alternative: https://github.com/docker/docker/issues/3359#issuecomment-32150214
#===================
ENV TZ "UTC"
RUN echo "${TZ}" > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

#========================================
# Add normal user with passwordless sudo
#========================================
RUN useradd galen \
         --shell /bin/bash  \
         --create-home \
  && usermod -a -G sudo galen \
  && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers \
  && echo 'galen:secret' | chpasswd

#========================================
# Install Java 8
#========================================
RUN echo 'deb http://httpredir.debian.org/debian jessie-backports main' >> /etc/apt/sources.list.d/jessie-backports.list

RUN set -x \
    && apt-get update \
    && apt-get install -y \
        locales

ENV LANG C.UTF-8
RUN locale-gen $LANG

RUN set -x \
    && apt-get update \
    && apt-get install -y -t \
        jessie-backports \
        ca-certificates-java \
        openjdk-8-jre-headless \
        openjdk-8-jre \
        openjdk-8-jdk-headless \
        openjdk-8-jdk

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

#===================================================
# Install xvfb
#===================================================
RUN set -x \
    && apt-get update \
    && apt-get install -y \
        xvfb

#===================================================
# Install Chrome
#===================================================

RUN echo 'deb http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/chrome.list

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -

RUN set -x \
    && apt-get update \
    && apt-get install -y \
        google-chrome-stable

ADD scripts/xvfb-chrome /usr/bin/xvfb-chrome
RUN ln -sf /usr/bin/xvfb-chrome /usr/bin/google-chrome

#===================================================
# Install firefox
#===================================================
RUN set -x \
    && apt-get update \
    && apt-get install -y \
        pkg-mozilla-archive-keyring

RUN echo 'deb http://security.debian.org/ jessie/updates main' >> /etc/apt/sources.list.d/jessie-updates.list

RUN set -x \
    && apt-get update \
    && apt-get install -y \
        xvfb \
    && apt-get install -y -t \
        jessie-backports \
        firefox-esr

ADD scripts/xvfb-firefox /usr/bin/xvfb-firefox
RUN ln -sf /usr/bin/xvfb-firefox /usr/bin/firefox

#===================================================
# This is needed for PhantomJS
#===================================================

RUN set -x && \
    apt-get update && \
    apt-get install -y \
        bzip2 \
        zip

#===================================================
# Run the following commands as non-privileged user
#===================================================
USER galen

#===================================================
# Install nvm with node and npm
#===================================================
RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.31.0/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && npm install -g galenframework-cli@$GALEN_VERSION

VOLUME /var/test_scripts

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/v$NODE_VERSION/bin:$PATH
