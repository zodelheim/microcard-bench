site_configuration = {
    "systems": [
        {
            "name": "tutorialsys",
            "descr": "Example system",
            "hostnames": ["arsenii-ubuntu"],
            "partitions": [
                {
                    "name": "default",
                    "descr": "Example partition",
                    "scheduler": "local",
                    "launcher": "local",
                    "environs": ["baseline", "gnu"],
                }
            ],
        }
    ],
    "environments": [
        {"name": "baseline", "features": ["stream"]},
        {
            "name": "gnu",
            "cc": "gcc",
            "cxx": "g++",
            "features": ["openmp"],
            "extras": {"omp_flag": "-fopenmp"},
        },
    ],
    "general": [
        {
            "report_file": "reports/run-report-{sessionid}.json",  # <-- your custom folder
        }
    ],
}
