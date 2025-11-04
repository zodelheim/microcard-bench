# Dockerfile.petsc
ARG BASE_IMAGE=opencarp-env:latest
FROM ${BASE_IMAGE}

ARG PETSC_VERSION=3.22.3
ARG OPENCARP_DIR=/usr/local/opencarp

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
    COPTFLAGS='-O3' CXXOPTFLAGS='-O3' FOPTFLAGS='-O3' CUDAOPTFLAGS="-O3" \
    && make all && make install \
    && cd .. && rm -rf petsc-${PETSC_VERSION}

ENV PATH=${OPENCARP_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${OPENCARP_DIR}/lib:${LD_LIBRARY_PATH}
ENV PETSC_DIR=${OPENCARP_DIR}

CMD ["/bin/bash"]
