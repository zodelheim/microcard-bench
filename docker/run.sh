docker run --sig-proxy=false -a STDOUT -a STDERR \
--mount type=bind,source=/home/arsenii/Documents/PYTHON/MICROCARD/microcard-bench,target=/workspaces/MICROCARD2 \
-w /workspaces/MICROCARD2 \
--gpus all --rm opencarp/microcard:emi /usr/bin/bash tests/run_strong_scaling.sh
