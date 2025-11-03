import os
from datetime import date
from carputils.settings import solver
from carputils import tools
from carputils import model
from pathlib import Path


def read_intra_tags(intra_path: Path):
    """Read first line as N, then take the next N lines as integer tags; return sorted ascending."""
    with open(intra_path, "r") as f:
        lines = [ln.strip() for ln in f if ln.strip() != ""]
    if not lines:
        raise RuntimeError(f"{intra_path} is empty")
    try:
        n = int(lines[0])
    except Exception as e:
        raise RuntimeError(f"Cannot parse first line as int in {intra_path}: {e}")
    if len(lines) < 1 + n:
        raise RuntimeError(f"{intra_path}: expected {n} tags, found {len(lines) - 1}")
    tags = [int(x) for x in lines[1 : 1 + n]]
    tags.sort()
    return tags


def build_stim_opts_literal(tags):
    """Return a Python list literal (as string) for stim_opts per your rules."""
    out = []
    # out.append("[")
    out.extend(["-num_stim", len(tags)])
    for i, tag in enumerate(tags):
        strength = 20.0 if i == 0 else -80.0
        out.extend([f"-stim[{int(i)}].ptcl.start", 0.0])
        out.extend([f"-stim[{int(i)}].ptcl.duration", 1.0])
        out.extend([f"-stim[{int(i)}].pulse.strength", strength])
        out.extend([f"-stim[{int(i)}].crct.type", 10])
        out.extend([f"-stim[{int(i)}].elec.geomID", tag])
    # out.append("    ]")
    return out


def parser():
    parser = tools.standard_parser()
    emi = parser.add_argument_group("EMI model")
    emi.add_argument(
        "--meshname",
        type=str,
        default="",
        help="Define which mesh you want to use. Destination needs to contain .mesh and .pts as well as intra- and extracellular region tags.",
    )
    emi.add_argument("--dt", type=float, default=10.0, help="Temporal resolution in us.")
    emi.add_argument("--tend", type=float, default=150.0, help="Duration of the simulation in ms.")
    emi.add_argument(
        "--spacedt", type=float, default=1, help="Temporal interval to output data to files."
    )
    emi.add_argument(
        "--debug",
        action="store_true",
        default=False,
        help="If set, increase output_level and dump stiffness and mass matrices, mappings and stimulation vectors to be used with MatLab to the simulation folder.",
    )
    emi.add_argument(
        "--petsc-option",
        type=str,
        default="petsc-preonly-lu",
        help="Path to PETSc options file (used for -parab_options_file).",
    )
    emi.add_argument("--ginkgo_exec", type=str, default="cuda", help="")

    # emi.add_argument(
    #     "--jobID",
    #     type=str,
    #     required=True,
    #     help="Top-level output directory name for the simulation.",
    # )

    return parser


def jobID(args):
    """
    Generate name of top level output directory.
    """
    return f"output/{Path(args.meshname).name}"


@tools.carpexample(parser, jobID)
def run(args, job):
    # Use external mesh
    # meshname = os.path.join(EXAMPLE_DIR, '{}/{}'.format(args.mesh, args.mesh))
    meshname = args.meshname

    cmd = tools.carp_cmd(None)
    cmd += [
        "-simID",
        job.ID,
        "-meshname",
        meshname,
        "-dt",
        args.dt,
        "-tend",
        args.tend,
        "-spacedt",
        args.spacedt,
        # "-timedt",
        # args.dt / 1000,
    ]

    if args.debug:
        cmd += ["-output_level", 10, "-dump2Matlab", True]

    # Set basic EMI options
    phys_opts = tools.gen_physics_opts(EMI=True)

    # Define gregions.
    gregions = [
        # Default values are taken from https://doi.org/10.1007/978-3-030-61157-6
        model.ConductivityRegionEMI.extra_default(g_bath=2.0),
        model.ConductivityRegionEMI.intra_default(g_bath=0.4),
    ]
    gregion_opts = ["-num_gregions", len(gregions)]
    for i, gregion in enumerate(gregions):
        # .opts_formatted() will automatically generate the string of openCARP parameters
        # from your specified ConductivityRegion.
        gregion_opts += gregion.opts_formatted(i)

    mesh = Path(args.meshname).absolute().with_suffix("")
    tags = read_intra_tags(mesh.with_suffix(".intra"))
    # print(f"{mesh.with_suffix('.intra')=}")
    print(tags)
    stim_opts = build_stim_opts_literal(tags)

    # Define imp regions
    impregions = [
        model.ionic.AlievPanfilovIonicModel(None, "default_ionic", emi=True),
        model.ionic.PlonseyIonicModel(None, "default_gap_junction", Rm=0.0045, emi=True),
    ]
    imp_opts = ["-num_imp_regions", len(impregions)]
    for i, region in enumerate(impregions):
        imp_opts += region.opts_formatted(i)

    cmd += phys_opts + gregion_opts + stim_opts + imp_opts

    cmd += [
        "-parab_options_file",
        "/workspace/openCARP/external/carputils/carputils/resources/ginkgo_options/parab_solver.json",
    ]
    cmd += [
        "-ellip_options_file",
        "/workspace/openCARP/external/carputils/carputils/resources/ginkgo_options/ellip_solver.json",
    ]
    cmd += ["-flavor", "ginkgo"]
    cmd += ["-ginkgo_exec", args.ginkgo_exec]

    job.mpi(cmd)


if __name__ == "__main__":
    run()
