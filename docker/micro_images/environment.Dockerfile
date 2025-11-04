# Dockerfile.environment
FROM docker.io/nvidia/cuda:11.8.0-devel-ubuntu22.04

ARG libfabric_version=1.22.0
ARG mpi_version=4.3.1
ARG osu_version=7.5.1

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential gcc g++ gfortran automake autoconf libtool make \
    git gdb strace ca-certificates pkg-config \
    python3-pip python3-dev python-is-python3 \
    gengetopt ninja-build curl wget unzip \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir numpy pybind11 PyYAML dataclasses lit

# CUDA stub setup for build
RUN echo '/usr/local/cuda/lib64/stubs' > /etc/ld.so.conf.d/cuda_stubs.conf && ldconfig

# XPMEM
RUN git clone https://github.com/hpc/xpmem \
    && cd xpmem/lib \
    && gcc -I../include -shared -o libxpmem.so.1 libxpmem.c \
    && ln -s libxpmem.so.1 libxpmem.so \
    && mv libxpmem.so* /usr/lib \
    && cp ../include/xpmem.h /usr/include/ \
    && ldconfig \
    && cd ../../ && rm -rf xpmem

# Libfabric
RUN wget -q https://github.com/ofiwg/libfabric/archive/v${libfabric_version}.tar.gz \
    && tar xf v${libfabric_version}.tar.gz \
    && cd libfabric-${libfabric_version} \
    && ./autogen.sh && ./configure --prefix=/usr --with-cuda=/usr/local/cuda \
    && make -j$(nproc) && make install && ldconfig \
    && cd .. && rm -rf libfabric-${libfabric_version}*

# MPICH (CUDA-aware, OFI)
RUN wget -q https://www.mpich.org/static/downloads/${mpi_version}/mpich-${mpi_version}.tar.gz \
    && tar xf mpich-${mpi_version}.tar.gz \
    && cd mpich-${mpi_version} \
    && ./autogen.sh && ./configure --prefix=/usr \
    --enable-fast=O3,ndebug --enable-fortran --enable-cxx \
    --with-device=ch4:ofi --with-libfabric=/usr \
    --with-xpmem=/usr --with-cuda=/usr/local/cuda \
    && make -j$(nproc) && make install && ldconfig \
    && cd .. && rm -rf mpich-${mpi_version}*

# OSU microbenchmarks
RUN wget -q http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-v${osu_version}.tar.gz \
    && tar xf osu-micro-benchmarks-v${osu_version}.tar.gz \
    && cd osu-micro-benchmarks-v${osu_version} \
    && ./configure --prefix=/usr/local --with-cuda=/usr/local/cuda CC=$(which mpicc) CFLAGS=-O3 \
    && make -j$(nproc) && make install \
    && cd .. && rm -rf osu-micro-benchmarks-v${osu_version}*

CMD ["/bin/bash"]
