FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive

# built-in packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common curl git \
    && sh -c "echo 'deb http://download.opensuse.org/repositories/home:/Horst3180/xUbuntu_16.04/ /' >> /etc/apt/sources.list.d/arc-theme.list" \
    && curl -sSL http://download.opensuse.org/repositories/home:Horst3180/xUbuntu_16.04/Release.key | apt-key add - \
    && sh -c "echo 'deb http://ppa.launchpad.net/fcwu-tw/ppa/ubuntu xenial main  /' >> /etc/apt/sources.list.d/arc-theme.list" \
    && curl -sSL 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x52F5AE973E6B74ECDD48FE8F1E79DD0304873C4E' | apt-key add - \
    && apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
        openssh-server pwgen sudo dirmngr gnupg2 \
        # net tools
        net-tools firefox nginx \
        # build tools
        python-pip python-dev build-essential cmake \
        # gui related
        mesa-utils libgl1-mesa-dri \
        lxde x11vnc xvfb \
        gtk2-engines-murrine ttf-ubuntu-font-family \
        gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine pinta arc-theme \
        dbus-x11 x11-utils \
        # user tool
        supervisor terminator vim gedit zsh okular \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* 

# =================================
# install ros (source: https://github.com/osrf/docker_images/blob/5399f380af0a7735405a4b6a07c6c40b867563bd/ros/kinetic/ubuntu/xenial/ros-core/Dockerfile)

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# install ros packages
ENV ROS_DISTRO kinetic
ENV CATKIN_WS=/root/catkin_ws

# setup keys
RUN curl -sSL 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xC1CF6E31E6BADE8868B172B4F42ED6FBAB17C654' | sudo apt-key add - \
    && sh -c "echo 'deb http://packages.ros.org/ros/ubuntu xenial main' > /etc/apt/sources.list.d/ros-latest.list" \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        ros-kinetic-desktop-full \
        #              A
        #              +--- full desktop \
        python-rosdep \
        python-rosinstall \
        python-wstool \
        python-rosinstall-generator \
        python-catkin-tools \
        ros-${ROS_DISTRO}-cv-bridge \
        ros-${ROS_DISTRO}-image-transport \
        ros-${ROS_DISTRO}-message-filters \
        ros-${ROS_DISTRO}-tf \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p $CATKIN_WS/src/

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# =================================
# install ceres-solver (reference: https://github.com/HKUST-Aerial-Robotics/VINS-Fusion/blob/master/docker/Dockerfile)

ENV CERES_VERSION="1.12.0"

      # set up thread number for building
RUN if [ "x$(nproc)" = "x1" ] ; then export USE_PROC=1 ; \
    else export USE_PROC=$(($(nproc)/2)) ; fi \
    # apt-getable dependencise
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        libatlas-base-dev \
        libeigen3-dev \
        libgoogle-glog-dev \
        libsuitesparse-dev \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    # build and install Ceres
    && git clone https://ceres-solver.googlesource.com/ceres-solver \
    && cd ceres-solver \
    && git checkout tags/${CERES_VERSION} \ 
    && mkdir build && cd build \
    && cmake .. \
    && make -j$(USE_PROC) install \
    && rm -rf ../../ceres-solver \

# =================================
# realsense sdk (reference: https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md)

RUN curl -sSL 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF6E65AC044F831AC80A06380C8B3A55A6F3EFCDE' | sudo apt-key add - \
    && add-apt-repository "deb http://realsense-hw-public.s3.amazonaws.com/Debian/apt-repo xenial main" -u \
    && apt-get install -y \
        librealsense2-dkms \
        librealsense2-utils \
        librealsense2-dev \
        librealsense2-dbg \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* 

# =================================
# final configurations

ADD image /
    # tini for subreap
RUN curl -o /bin/tini https://github.com/krallin/tini/releases/download/v0.18.0/tini \
    && chmod +x /bin/tini \
    # dependencise of web service
    && pip install setuptools wheel \
    && pip install -r /usr/lib/web/requirements.txt \
    # add terminator's link to destop
    && cp /usr/share/applications/terminator.desktop /root/Desktop \
    # zsh customization
    && echo "source /opt/ros/kinetic/setup.zsh" >> /root/.zshrc \
    && chsh -s $(which zsh) \
    && sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

EXPOSE 80
WORKDIR /root
ENV HOME=/root \
    SHELL=/bin/zsh
ENTRYPOINT ["/startup.sh"]
