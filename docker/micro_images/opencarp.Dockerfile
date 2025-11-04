# Dockerfile.opencarp
ARG BASE_IMAGE=opencarp-ginkgo:latest
FROM ${BASE_IMAGE}

ARG LLVM_VERSION=18.1.8
ARG OPENCARP_DIR=/usr/local/opencarp

# CMake (if not inherited)
ARG CMAKE_VERSION=3.30.3
RUN curl -L https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).sh -o /tmp/cmake.sh \
    && chmod +x /tmp/cmake.sh \
    && /tmp/cmake.sh --skip-license --prefix=/usr && rm /tmp/cmake.sh

# LLVM + MLIR
RUN curl -L https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz | tar xJ \
    && cd llvm-project-${LLVM_VERSION}.src \
    && cmake -S. -B build -G Ninja llvm \
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
    && cd .. && rm -rf llvm-project-${LLVM_VERSION}.src

ENV PYTHONPATH=${OPENCARP_DIR}/python_packages/mlir_core

# openCARP build
WORKDIR /workspace
RUN git clone https://git.opencarp.org/openCARP/openCARP.git

WORKDIR /workspace/openCARP
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
    -DCMAKE_CUDA_ARCHITECTURES="89;90" \
    -DMLIR_CUDA_PTX_FEATURE=ptx64 \
    -DCUDA_GPU_ARCH=sm_89 \
    -DBUILD_EXTERNAL=ON \
    -DCMAKE_INSTALL_PREFIX=${OPENCARP_DIR} \
    && cmake --build build --parallel $(nproc) --target install \
    && cp ./build/physics/limpet/Transforms/mlir/lib/ExecutionEngine/libopencarp_cuda_runtime.so /usr/local/opencarp/lib/

RUN rm /etc/ld.so.conf.d/cuda_stubs.conf && ldconfig
CMD ["/bin/bash"]
