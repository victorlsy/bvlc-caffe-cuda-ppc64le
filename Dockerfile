#make base image
FROM zoomtech/ubuntu-cuda-ppc64le
MAINTAINER LiShengYao <lisy@zoomserver.cn>

WORKDIR /root

RUN apt-get update && apt-get install -y git cmake unzip curl wget \
    autoconf libtool python3-dev python3-pip libboost-python-dev \
    libboost-dev libboost-system-dev libboost-filesystem-dev libboost-thread-dev \
    libgflags-dev libgoogle-glog-dev liblmdb-dev libsnappy-dev libleveldb-dev libprotobuf-dev libhdf5-dev \
    libpng-dev libxft-dev libfreetype6-dev python3-numpy liblapack-dev libblas-dev \
    && cd /usr/lib/powerpc64le-linux-gnu && ln -s libboost_python-py35.so libboost_python3.so \
    && apt-get autoremove -y && apt-get clean && rm -fr /var/lib/apt/lists/*

#install cudnn with local deb files,we can use url method in the furture
#COPY libcudnn6-dev_6.0.21-1%2Bcuda8.0_ppc64el.deb libcudnn6_6.0.21-1%2Bcuda8.0_ppc64el.deb \
#     libcudnn6-doc_6.0.20-1+cuda8.0_ppc64el.deb ./
#RUN dpkg -i libcudnn6-dev_6.0.21-1%2Bcuda8.0_ppc64el.deb \
#    libcudnn6_6.0.21-1%2Bcuda8.0_ppc64el.deb \
#    libcudnn6-doc_6.0.20-1+cuda8.0_ppc64el.deb \
#    && rm -f libcudnn*

#install openblas
RUN git clone https://github.com/xianyi/OpenBLAS.git  openblas \
    && cd openblas && make && PREFIX=/usr/local make install && cd .. && rm -fr openblas

#install nccl
RUN git clone https://github.com/NVIDIA/nccl nccl \
    && cd nccl && make && make install && cd .. && rm -fr nccl

#install opencv
ADD opencv-3.3.0.zip ./
RUN unzip opencv-3.3.0.zip && cd opencv-3.3.0 && mkdir build && cd build \
    && cmake -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr/local .. \
    && make -j$(nproc) && make install && cd ../.. && rm -fr opencv-3.3.0 opencv-3.3.0.zip

#install protoc for caffe
RUN git clone https://github.com/google/protobuf.git protobuf \
    &&  cd protobuf && git checkout 3.2.x && ./autogen.sh \
    && ./configure && make -j$(nproc) && make install && ldconfig && cd .. && rm -fr protobuf

ENV CAFFE=bvlc-caffe
#install bvlc-caffe
ADD Makefile.config Makefile ./
RUN git clone https://github.com/BVLC/caffe.git $CAFFE \
    && cd $CAFFE && mv -f ../Makefile.config ../Makefile . \
    && make all -j$(nproc) 
#&& make test -j$(nproc) && make runtest -j$(nproc)

#build pycaffe
WORKDIR $CAFFE
RUN for req in $(cat python/requirements.txt); do pip3 install $req; done \
    && pip3 install --upgrade python-dateutil && make pycaffe -j$(nproc) 
ENV PYTHONPATH=/root/$CAFFE/python
