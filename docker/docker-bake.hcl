group "all" {
    targets = [ "environment", "microcard", "microcard-cpu"]
}


variable "ARCH" {
    default = "75"
}

variable "SM_ARCH" {
    default = "sm_${ARCH}"
}

variable "OPENCARP_DIR" {
    default = "/usr/local/opencarp"
}

target "environment" {
    context = "."
    dockerfile = "environment.Dockerfile" //! No Ginkgo preinstall
    tags = [ "opencarp/environment" ]
    output = [ "type=docker" ]
    args = {
        ARCH = ARCH
        SM_ARCH = SM_ARCH
        LLVM_VERSION="18.1.8"
        PETSC_VERSION="3.22.3"
        OPENCARP_DIR=OPENCARP_DIR
    }
}

target "microcard" {
    context = "."
    dockerfile = "microcard.Dockerfile"
    tags = [ "opencarp/microcard:emi" ]
    output = [ "type=docker" ]
    args = {
        OPENCARP_DIR=OPENCARP_DIR
        CARPUTILS_BRANCH="emi-interface"
        BRANCH="emi_model"
        ARCH = ARCH
        SM_ARCH = SM_ARCH
        IMAGE="opencarp/environment"
    }

}
target "microcard-cpu" {
    context = "."
    dockerfile = "microcard.Dockerfile"
    tags = [ "opencarp/microcard:emicpu" ]
    output = [ "type=docker" ]
    args = {
        OPENCARP_DIR=OPENCARP_DIR
        CARPUTILS_BRANCH="emi-interface"
        BRANCH="emi_model_cpu"
        ARCH = ARCH
        SM_ARCH = SM_ARCH
        ENABLE_GINKGO="ON"
        IMAGE="opencarp/environment"
    }
}