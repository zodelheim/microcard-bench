ARG IMAGE=opencarp/environment
FROM ${IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ARG CMAKE_VERSION=3.30.3
# ARG PETSC_VERSION=3.22.3
# ARG LLVM_VERSION=18.1.8

ARG ARCH="75"
ARG SM_ARCH=sm_75

ARG ENABLE_GINKGO=ON

ARG OPENCARP_DIR=/usr/local/opencarp

ARG BRANCH=emi_model
ARG CARPUTILS_BRANCH=emi-interface

ENV PYTHONPATH=${OPENCARP_DIR}/python_packages/mlir_core
ENV PATH=${OPENCARP_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${OPENCARP_DIR}/lib:${LD_LIBRARY_PATH}

ENV CUDA_STUB_PATH=/usr/local/cuda/targets/x86_64-linux/lib/stubs
ENV LDFLAGS="-Wl,--allow-shlib-undefined"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${CUDA_STUB_PATH}"

RUN ln -sf ${CUDA_STUB_PATH}/libcuda.so ${CUDA_STUB_PATH}/libcuda.so.1 || true

WORKDIR /workspace
RUN git clone https://git.opencarp.org/openCARP/openCARP.git
# COPY openCARP .

WORKDIR /workspace/openCARP
RUN git checkout ${BRANCH} && git pull

RUN cmake -S. -B_build -GNinja \
    -DDLOPEN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-O3 -march=native" \
    -DENABLE_GINKGO=${ENABLE_GINKGO} \
    -DGINKGO_DIR=${OPENCARP_DIR} \
    -DENABLE_MLIR_CODEGEN=${ENABLE_GINKGO} \
    -DCMAKE_CXX_FLAGS="-I/usr/local/cuda/include" \
    -DUSE_OPENMP=OFF \
    -DENABLE_PETSC=ON \
    -DCUDAToolkit_ROOT=/usr/local/cuda \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_FLAGS="-std=c++17 -ccbin gcc-11" \
    -DCMAKE_CUDA_ARCHITECTURES=${ARCH} \
    -DMLIR_CUDA_PTX_FEATURE=ptx64 \
    -DCUDA_GPU_ARCH=${SM_ARCH} \
    -DBUILD_EXTERNAL=ON \
    -DCMAKE_INSTALL_PREFIX=${OPENCARP_DIR} \
    && cmake --build _build --parallel $(nproc) --target install 

# RUN cp /workspace/openCARP/_build/physics/limpet/Transforms/mlir/lib/ExecutionEngine/libopencarp_cuda_runtime.so /usr/local/opencarp/lib/

# otherwise it will keep using the stub file
RUN rm ${CUDA_STUB_PATH}/libcuda.so.1

WORKDIR /workspace/openCARP/external/carputils
RUN git checkout ${CARPUTILS_BRANCH} && git pull
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
