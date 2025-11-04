"Convert msh to openCARP format."

import meshio
import numpy as np
import sys
import os
from pathlib import Path

if __name__ == "__main__":
    # FIXME: add binary format and vtu output
    # if len(sys.argv) < 2:
    #     print("Missing mesh filename argument.")
    #     print(f"Usage: {sys.argv[0]} emigrid.msh")
    #     sys.exit(1)

    # mesh_filename = sys.argv[1]
    mesh_filename = Path("data/emigrid/emigrid.msh")
    base, ext = os.path.splitext(mesh_filename)
    ofdir = Path("data/emigrid/carp")
    ofdir.mkdir(exist_ok=True)

    # outputs
    pts_fn = f"{base}.pts"
    elem_fn = f"{base}.elem"
    intra_fn = f"{base}.intra"
    extra_fn = f"{base}.extra"
    lon_fn = f"{base}.lon"

    pts_fn = ofdir / Path(pts_fn).name
    elem_fn = ofdir / Path(elem_fn).name
    intra_fn = ofdir / Path(intra_fn).name
    extra_fn = ofdir / Path(extra_fn).name
    lon_fn = ofdir / Path(lon_fn).name

    msh = meshio.read(mesh_filename)
    pts = msh.points
    elm = msh.cells_dict["tetra"]
    tag = np.hstack(msh.cell_data["gmsh:physical"])
    ntags = len(msh.cell_data["gmsh:physical"])

    print(f"Mesh with {pts.shape[0]} vertices, {elm.shape[0]} tetra, {ntags} tags")

    with open(pts_fn, "w") as fo:
        print(pts.shape[0], file=fo)
        np.savetxt(fo, pts, fmt="%1.4f")

    arr = np.empty((elm.shape[0], 6), dtype=object)
    arr[:, 0] = "Tt"
    arr[:, 1:5] = elm[:, 0:4]
    arr[:, 5] = tag
    print(arr[:, 5])
    extra = np.arange(0, ntags + 1, step=2)
    intra = np.arange(1, ntags + 1, step=2)

    lon = np.zeros((arr.shape[0], 3))
    lon[:, 0] = 1

    # print(ntags)
    # print(intra)
    # print(extra)

    with open(elem_fn, "w") as fo:
        print(arr.shape[0], file=fo)
        np.savetxt(fo, arr, fmt="%s %d %d %d %d %d")

    with open(intra_fn, "w") as fo:
        print(intra.shape[0], file=fo)
        np.savetxt(fo, intra, fmt="%d")

    with open(extra_fn, "w") as fo:
        print(extra.shape[0], file=fo)
        np.savetxt(fo, extra, fmt="%d")

    with open(lon_fn, "w") as fo:
        print(1, file=fo)
        np.savetxt(fo, lon, fmt="%d")
