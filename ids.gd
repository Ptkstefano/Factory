extends Node

# Global registry of every pickup id in the game.
# Add new pickups here so pickup.gd and the player's inventory
# always refer to the same set of ids.
enum OBJECTS {
	NONE,
	CROWBAR,
	TAPE,
	FOOD,
}

const NAMES := {
	OBJECTS.NONE: "",
	OBJECTS.CROWBAR: "Crowbar",
	OBJECTS.TAPE: "Tape",
	OBJECTS.FOOD: "Food",
}

func get_object_name(id: OBJECTS) -> String:
	return NAMES.get(id, "Item")
