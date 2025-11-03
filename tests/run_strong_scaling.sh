#! CUDA STRONG SCALING
cusettings ~/.config/carputils/settings.yaml
nvidia-smi

mkdir output
mkdir logs_strong_mpi

filename="./data/emigrid/carp/emigrid"
filename="$(realpath "${filename}")"
base="$(basename "$filename")"
echo "${filename}"
echo "${basename}"
for np in 8; do
    echo "np = ${np}"
    python ./tests/strong_scaling.py --np="$np" --meshname="$filename" --ginkgo_exec 'ref' \
    --overwrite-behaviour 'overwrite' \
    >logs_strong_mpi/run-$(basename "$file")_n_${np}.out \
    2>logs_strong_mpi/run-$(basename "$file")_n_${np}.err
done