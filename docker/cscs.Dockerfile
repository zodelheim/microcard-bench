FROM docker.io/nvidia/cuda:11.8.0-devel-ubuntu22.04

ARG libfabric_version=1.22.0
ARG mpi_version=4.3.1
ARG osu_version=7.5.1
ARG CMAKE_VERSION=3.30.3
ARG PETSC_VERSION=3.22.3
ARG LLVM_VERSION=18.1.8
ARG OPENCARP_DIR=/usr/local/opencarp

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential gcc g++ ca-certificates automake autoconf libtool make gdb strace \
    git gfortran gengetopt ninja-build git curl wget unzip pkg-config \
    python3-pip python3-dev python-is-python3 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir numpy pybind11 PyYAML dataclasses lit

# When building on a machine without a GPU,
# during the build process on Daint the GPU driver and libraries are not imported into the build process
RUN echo '/usr/local/cuda/lib64/stubs' > /etc/ld.so.conf.d/cuda_stubs.conf && ldconfig

RUN git clone https://github.com/hpc/xpmem \
    && cd xpmem/lib \
    && gcc -I../include -shared -o libxpmem.so.1 libxpmem.c \
    && ln -s libxpmem.so.1 libxpmem.so \
    && mv libxpmem.so* /usr/lib \
    && cp ../include/xpmem.h /usr/include/ \
    && ldconfig \
    && cd ../../ \
    && rm -Rf xpmem

RUN wget -q https://github.com/ofiwg/libfabric/archive/v${libfabric_version}.tar.gz \
    && tar xf v${libfabric_version}.tar.gz \
    && cd libfabric-${libfabric_version} \
    && ./autogen.sh \
    && ./configure --prefix=/usr --with-cuda=/usr/local/cuda \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd .. \
    && rm -rf v${libfabric_version}.tar.gz libfabric-${libfabric_version}

RUN wget -q https://www.mpich.org/static/downloads/${mpi_version}/mpich-${mpi_version}.tar.gz \
    && tar xf mpich-${mpi_version}.tar.gz \
    && cd mpich-${mpi_version} \
    && ./autogen.sh \
    && ./configure --prefix=/usr --enable-fast=O3,ndebug --enable-fortran --enable-cxx --with-device=ch4:ofi --with-libfabric=/usr --with-xpmem=/usr --with-cuda=/usr/local/cuda \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd .. \
    && rm -rf mpich-${mpi_version}.tar.gz mpich-${mpi_version}

RUN wget -q http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-v${osu_version}.tar.gz \
    && tar xf osu-micro-benchmarks-v${osu_version}.tar.gz \
    && cd osu-micro-benchmarks-v${osu_version} \
    && ./configure --prefix=/usr/local --with-cuda=/usr/local/cuda CC=$(which mpicc) CFLAGS=-O3 \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf osu-micro-benchmarks-v${osu_version} osu-micro-benchmarks-v${osu_version}.tar.gz

RUN curl -L https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).sh -o /tmp/cmake.sh \
    && chmod +x /tmp/cmake.sh \
    && /tmp/cmake.sh --skip-license --prefix=/usr \
    && rm /tmp/cmake.sh

RUN curl -L https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz | tar xz \
    && cd petsc-${PETSC_VERSION} \
    && ./configure \
    --with-shared-libraries \
    --PETSC_ARCH="docker-opt" \
    --with-debugging=0 \
    --with-cuda=1 \
    --download-metis \
    --download-parmetis \
    --download-hypre \
    --download-fblaslapack \
    --prefix=${OPENCARP_DIR} \
    COPTFLAGS='-O3' \
    CXXOPTFLAGS='-O3' \
    FOPTFLAGS='-O3' \
    CUDAOPTFLAGS="-O3" \
    && make all \
    && make install \
    && cd .. \
    && rm -rf petsc-${PETSC_VERSION}


#ENV PYTHONPATH=${OPENCARP_DIR}/python_packages/mlir_core
ENV PATH=${OPENCARP_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${OPENCARP_DIR}/lib:${LD_LIBRARY_PATH}

# IMPORTANT: keep CUDA backend only, and pin compilers + SMs
# Keep source for now, good for testing
RUN git clone https://github.com/ginkgo-project/ginkgo.git \
    && cd ginkgo \
    && cmake -S. -B build -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${OPENCARP_DIR} \
    -DGINKGO_BUILD_CUDA=ON \
    -DGINKGO_BUILD_OMP=ON \
    -DGINKGO_BUILD_REFERENCE=ON \
    -DGINKGO_BUILD_HIP=OFF \
    -DGINKGO_BUILD_SYC=OFF \
    -DGINKGO_BUILD_BENCHMARKS=ON \
    -DGINKGO_BUILD_EXAMPLES=ON \
    -DGINKGO_BUILD_TESTS=OFF \
    -DGINKGO_DEVEL_TOOLS=OFF \
    -DGINKGO_HAVE_GPU_AWARE_MPI=ON \
    -DGINKGO_WITH_CCACHE=OFF \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="75;89;90" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    && cmake --build build --parallel $(nproc) --target install

RUN curl -L https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz | tar xJ \
    && cd llvm-project-${LLVM_VERSION}.src \
    && cmake -S. -B build  -G Ninja llvm \
    -DLLVM_ENABLE_PROJECTS="mlir;clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="host;NVPTX" \
    -DLLVM_ENABLE_RUNTIMES="openmp;compiler-rt;libcxx;libcxxabi;libunwind" \
    -DCMAKE_BUILD_TYPE=Release \
    -DMLIR_ENABLE_BINDINGS_PYTHON=True \
    -DBUILD_SHARED_LIBS=True \
    -DLLVM_USE_LINKER=gold \
    -DLLVM_INSTALL_UTILS=ON \
    -DMLIR_ENABLE_CUDA_RUNNER=True \
    -DCUDAToolkit_ROOT=/usr/local/cuda \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    -DCMAKE_CUDA_FLAGS_INIT="-std=c++17 -ccbin gcc" \
    -DCMAKE_INSTALL_PREFIX=${OPENCARP_DIR} \
    && cmake --build build --parallel $(nproc) --target install \
    && cd .. \
    && rm -rf llvm-project-${LLVM_VERSION}.src

ENV PYTHONPATH=${OPENCARP_DIR}/python_packages/mlir_core
ENV PETSC_DIR=${OPENCARP_DIR}

# RUN python3 -c "import ctypes; ctypes.CDLL('libcuda.so.1', mode=ctypes.RTLD_GLOBAL)" || true
# RUN python3 -c "from mlir import _mlir_libs; print(_mlir_libs.__file__)" # Just to check that MLIR is found

#RUN git clone https://github.com/ginkgo-project/ssget.git && cp /ssget/ssget /usr/local/opencarp/bin

WORKDIR /workspace
RUN git clone https://git.opencarp.org/openCARP/openCARP.git

WORKDIR /workspace/openCARP
RUN git checkout emi_model; git pull
# # COPY openCARP .
RUN cmake -S. -B build -G Ninja \
    -DDLOPEN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-O3 -march=native" \
    -DENABLE_GINKGO=ON \
    -DGINKGO_DIR=${OPENCARP_DIR} \
    -DENABLE_MLIR_CODEGEN=ON \
    -DCMAKE_CXX_FLAGS="-I/usr/local/cuda/include" \
    -DUSE_OPENMP=OFF \
    -DENABLE_PETSC=ON \
    -DCUDAToolkit_ROOT=/usr/local/cuda \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_FLAGS="-std=c++17 -ccbin gcc-11" \
    -DCMAKE_CUDA_ARCHITECTURES="75;89;90" \
    -DMLIR_CUDA_PTX_FEATURE=ptx64 \
    -DCUDA_GPU_ARCH=sm_75 \
    -DBUILD_EXTERNAL=ON \
    -DCMAKE_INSTALL_PREFIX=${OPENCARP_DIR} \
    && cmake --build build --parallel $(nproc) --target install \
    && cp ./build/physics/limpet/Transforms/mlir/lib/ExecutionEngine/libopencarp_cuda_runtime.so /usr/local/opencarp/lib/

# Get rid of the stubs libraries, because at runtime the CUDA driver and libraries will be available
RUN rm /etc/ld.so.conf.d/cuda_stubs.conf && ldconfig

WORKDIR /workspace/openCARP/external/carputils
RUN git checkout emi-interface && git pull
RUN pip install .
RUN cusettings $HOME/.config/carputils/settings.yaml

WORKDIR /workspace

RUN pip install ranger-fm
RUN apt-get update && apt-get install -y --no-install-recommends vim less locate file
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
ENV LD_LIBRARY_PATH=/workspace/openCARP/_build/physics/limpet/Transforms/mlir/lib/ExecutionEngine:$LD_LIBRARY_PATH
RUN cusettings ~/.config/carputils/settings.yaml
CMD ["/bin/bash"]
