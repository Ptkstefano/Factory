extends Node

# Global registry of every pickup id in the game.
# Add new pickups here so pickup.gd and the player's inventory
# always refer to the same set of ids.
enum OBJECTS {
	NONE,
	CROWBAR,
	KEY,
	FUEL,
	FLASHLIGHT,
}

const NAMES := {
	OBJECTS.NONE: "",
	OBJECTS.CROWBAR: "Crowbar",
	OBJECTS.KEY: "KEY",
	OBJECTS.FUEL: "FUEL",
	OBJECTS.FLASHLIGHT: "Flashlight",
}

enum INTERACTABLE_AREAS {
	FLASHLIGHT,
	CROWBAR_DOOR,
	KEY_DOOR,
	POWER_GENERATOR,
	GATE_FENCE
}

enum SOUND_AREAS {
	INSIDE,
	COURTYARD,
	GARAGE,
}

func get_object_name(id: OBJECTS) -> String:
	return NAMES.get(id, "Item")
