FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

# Noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

ARG CMAKE_VERSION=3.30.3
ARG PETSC_VERSION=3.22.3
ARG LLVM_VERSION=18.1.8
ARG OPENCARP_DIR=/usr/local/opencarp

ARG ARCH="75"
ARG SM_ARCH=sm_75

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ gfortran \
    ninja-build git curl wget unzip pkg-config \
    gengetopt \
    python3 python3-pip python3-dev python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir numpy pybind11 PyYAML dataclasses

RUN curl -L https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh -o /tmp/cmake.sh \
    && chmod +x /tmp/cmake.sh \
    && /tmp/cmake.sh --skip-license --prefix=/usr/local \
    && rm /tmp/cmake.sh

WORKDIR /workspace

# IMPORTANT: keep CUDA backend only, and pin compilers + SMs
# Keep source for now, good for testing

# -DGINKGO_FORCE_GPU_AWARE_MPI=ON <- 
# @Simone Pezzuto  and @Arsenii Dokuchaev  please use -DGINKGO_FORCE_GPU_AWARE_MPI=on  
# instead in your Dockerfile. Please let me know if that helps. 
# See https://github.com/ginkgo-project/ginkgo/blob/614bcbc60c45e4742332eeedc414b0a4415fb1a7/CMakeLists.txt#L184 


# RUN git clone https://github.com/ginkgo-project/ginkgo.git \
#     && cd ginkgo \
#     && cmake -S. -B build -G "Unix Makefiles" \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DCMAKE_INSTALL_PREFIX=${OPENCARP_DIR} \
#     -DGINKGO_BUILD_CUDA=ON \
#     -DGINKGO_BUILD_OMP=ON \
#     -DGINKGO_BUILD_REFERENCE=ON \
#     -DGINKGO_BUILD_HIP=OFF \
#     -DGINKGO_BUILD_SYC=OFF \
#     -DGINKGO_BUILD_BENCHMARKS=ON \
#     -DGINKGO_BUILD_EXAMPLES=OFF \
#     -DGINKGO_BUILD_TESTS=OFF \
#     -DGINKGO_DEVEL_TOOLS=OFF \
#     -DGINKGO_HAVE_GPU_AWARE_MPI=ON \
#     -DGINKGO_WITH_CCACHE=OFF \
#     -DGINKGO_FORCE_GPU_AWARE_MPI=ON \ 
#     -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
#     -DCMAKE_CUDA_ARCHITECTURES=${ARCH} \
#     -DCMAKE_C_COMPILER=/usr/bin/gcc \
#     -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
#     && cmake --build build --parallel $(nproc) --target install

RUN curl -L https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz | tar xJ \
    && mv llvm-project-${LLVM_VERSION}.src llvm-project

WORKDIR /workspace/llvm-project/build
RUN cmake -G Ninja ../llvm \
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
    && ninja all \
    && ninja install

ENV PYTHONPATH=${OPENCARP_DIR}/python_packages/mlir_core
ENV PATH=${OPENCARP_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${OPENCARP_DIR}/lib:${LD_LIBRARY_PATH}

# Ensure CUDA stubs are usable during build and Python imports
# Detect proper CUDA target path (x86_64 or sbsa for ARM)
RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
    CUDA_TARGET=targets/x86_64-linux; \
    elif [ "$ARCH" = "aarch64" ]; then \
    CUDA_TARGET=targets/sbsa-linux; \
    else \
    echo "Unsupported architecture: $ARCH" >&2; exit 1; \
    fi; \
    CUDA_STUB_PATH="/usr/local/cuda/${CUDA_TARGET}/lib/stubs"; \
    ln -sf ${CUDA_STUB_PATH}/libcuda.so ${CUDA_STUB_PATH}/libcuda.so.1; \
    echo "Using CUDA stub path: ${CUDA_STUB_PATH}"; \
    echo "export CUDA_STUB_PATH=${CUDA_STUB_PATH}" >> /etc/profile.d/cuda_stubs.sh

# Make sure it's visible to the linker
ENV CUDA_STUB_PATH=/usr/local/cuda/targets/x86_64-linux/lib/stubs
RUN ln -sf ${CUDA_STUB_PATH}/libcuda.so ${CUDA_STUB_PATH}/libcuda.so.1 || true
ENV LDFLAGS="-Wl,--allow-shlib-undefined"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${CUDA_STUB_PATH}"

# (Optional sanity check)
RUN python3 -c "import ctypes; ctypes.CDLL('libcuda.so.1', mode=ctypes.RTLD_GLOBAL)" || true
RUN python3 -c "from mlir import _mlir_libs; print(_mlir_libs.__file__)" # Just to check that MLIR is found

WORKDIR /workspace
RUN curl -L https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz | tar xz \
    && cd petsc-${PETSC_VERSION} \
    && ./configure \
    --with-shared-libraries \
    --PETSC_ARCH="docker-opt" \
    --with-debugging=0 \
    --download-metis \
    --download-parmetis \
    --download-hypre \
    --download-fblaslapack \
    --download-mpich \
    --download-fblaslapack \
    --prefix=${OPENCARP_DIR} \
    COPTFLAGS='-O2' \
    CXXOPTFLAGS='-O2' \
    FOPTFLAGS='-O2' \
    LDFLAGS=${LDFLAGS} \
    && make all \
    && make PETSC_DIR=/workspace/petsc-${PETSC_VERSION} PETSC_ARCH=docker-opt install

ENV PETSC_DIR=${OPENCARP_DIR}

RUN pip install --no-cache-dir lit
