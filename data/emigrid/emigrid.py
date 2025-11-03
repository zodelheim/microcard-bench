import gmsh

gmsh.initialize()
gmsh.model.add("myocyte_array")

# -----------------------------
# Parameters
# -----------------------------
nx = 3  # * "Number of cells in X"
ny = 3  # * "Number of cells in Y"
nz = 3  # * "Number of cells in Z"

cl = 100.0  # * "Cell length (myocyte + Z-disk), units μm"
cw = 40.0  # * "Cell  width (myocyte + Z-disk), units μm"
gl = 5.0  # * "Z-disk length, units μm"
gw = 10.0  # * "Z-disk  width, units μm"
minlc = 2.0  # * "Min Characteristic length"
maxlc = 4.0  # * "Max Characteristic length"
# minlc = 2  # * "Min Characteristic length"
# maxlc = 2  # * "Max Characteristic length"

gmsh.option.setNumber("Mesh.CharacteristicLengthMin", minlc)
gmsh.option.setNumber("Mesh.CharacteristicLengthMax", maxlc)

# -----------------------------
# Create base geometry
# -----------------------------
b1 = gmsh.model.occ.addBox(
    -cl / 2 + gl, -cw / 2 + gl, -cw / 2 + gl, cl - 2 * gl, cw - 2 * gl, cw - 2 * gl, 1
)
b2 = gmsh.model.occ.addBox(-cl / 2, -gw / 2, -gw / 2, cl, gw, gw, 2)
b3 = gmsh.model.occ.addBox(-gw / 2, -cw / 2, -gw / 2, gw, cw, gw, 3)
b4 = gmsh.model.occ.addBox(-gw / 2, -gw / 2, -cw / 2, gw, gw, cw, 4)
b5 = gmsh.model.occ.addBox(-cl / 2, -cw / 2, -cw / 2, cl, cw, cw, 5)

# -----------------------------
# Boolean operations
# -----------------------------
v_union, _ = gmsh.model.occ.fuse([(3, 1)], [(3, 2), (3, 3), (3, 4)], 6)
v_diff, _ = gmsh.model.occ.cut([(3, 5)], [(3, 6)], 7, removeTool=False)
gmsh.model.occ.synchronize()

# # Re-query valid base volumes (they may have new tags)
base = gmsh.model.getEntities(dim=3)
# -----------------------------
# Replication
# -----------------------------
all_vols = []
for i in range(nx):
    for j in range(ny):
        for k in range(nz):
            tx = i * cl
            ty = j * cw
            tz = k * cw
            if i > 0 or j > 0 or k > 0:
                new_entities = gmsh.model.occ.copy([base[0], base[1]])
                gmsh.model.occ.translate(new_entities, tx, ty, tz)
                all_vols.extend(new_entities)

# -----------------------------
# Merge all fragments
# -----------------------------
gmsh.model.occ.fragment(base, all_vols, removeObject=True, removeTool=True)
gmsh.model.occ.synchronize()

# # -----------------------------
# # Physical volumes
# # -----------------------------
final_vols = gmsh.model.getEntities(dim=3)

for idx, vol in enumerate(final_vols, start=1):
    gmsh.model.addPhysicalGroup(3, [vol[1]], idx)

# -----------------------------
# Mesh and output
# -----------------------------
gmsh.model.mesh.generate(3)
gmsh.write("data/emigrid/emigrid.msh")

# print(f"Generated {len(final_vols)} volumes -> myocyte_array.msh")

if not gmsh.option.getNumber("General.Terminal"):
    gmsh.fltk.run()

gmsh.finalize()
