extends NavigationRegion3D

func _ready():
	Signals.bake_navmesh.connect(on_bake_navmesh)
	
func on_bake_navmesh():
	bake_navigation_mesh()
