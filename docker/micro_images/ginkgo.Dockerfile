# Dockerfile.ginkgo
ARG BASE_IMAGE=opencarp-petsc:latest
FROM ${BASE_IMAGE}

ARG OPENCARP_DIR=/usr/local/opencarp

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
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="89;90" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    && cmake --build build --parallel $(nproc) --target install \
    && cd .. && rm -rf ginkgo

CMD ["/bin/bash"]
