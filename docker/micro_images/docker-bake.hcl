group "default" {
    targets = ["environment", "petsc", "ginkgo", "opencarp"]
}

target "environment" {
    dockerfile = "Dockerfile.environment"
    context = "."
    tags = ["opencarp-env:latest"]
}

target "petsc" {
    dockerfile = "Dockerfile.petsc"
    context = "."
    args = { BASE_IMAGE = "opencarp-env:latest" }
    tags = ["opencarp-petsc:latest"]
    depends_on = ["environment"]
}

target "ginkgo" {
    dockerfile = "Dockerfile.ginkgo"
    context = "."
    args = { BASE_IMAGE = "opencarp-petsc:latest" }
    tags = ["opencarp-ginkgo:latest"]
    depends_on = ["petsc"]
}

target "opencarp" {
    dockerfile = "Dockerfile.opencarp"
    context = "."
    args = { BASE_IMAGE = "opencarp-ginkgo:latest" }
    tags = ["opencarp:latest"]
    depends_on = ["ginkgo"]
}
