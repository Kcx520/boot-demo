extends SceneTree
## Measurement helper: prints the boot's cross-section extents so the heel and
## zipper can be placed from real numbers instead of guesses.
## Run with: godot --headless --path . --script res://probe.gd

func _init() -> void:
	var boot = load("res://boot_model.gd").new()
	root.add_child(boot)

	var frames: Array = boot._frames(120)
	var segs: int = boot.SEGMENTS
	print("segments=%d rings=%d" % [segs, frames.size()])
	print("  u    y      zmin    zmax    xmax   ybot   ytop")
	for i in range(0, frames.size(), 6):
		var ymin := 1e9
		var ymax := -1e9
		var zmin := 1e9
		var zmax := -1e9
		var xmax := -1e9
		for s in segs:
			var p: Vector3 = boot._ring_point(frames[i], TAU * float(s) / float(segs))
			ymin = minf(ymin, p.y)
			ymax = maxf(ymax, p.y)
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
			xmax = maxf(xmax, absf(p.x))
		print("%.3f %.3f  %+.3f  %+.3f   %.3f  %.3f  %.3f"
			% [float(i) / 119.0, frames[i]["pos"].y, zmin, zmax, xmax, ymin, ymax])
	quit()
