-- Minecraft-style views: first person, from behind with the crosshair above the
-- head, and from in front. Its values are in mutator.toml's [script].

local FIRST_PERSON, BEHIND, FRONT = 0, 1, 2

local view = FIRST_PERSON
local was_down = false

function frame()
	input.claim(settings.controller)

	local down = input.held(settings.keyboard) or input.held(settings.controller)
	if down and not was_down then
		view = (view + 1) % 3
	end
	was_down = down

	-- a vehicle's seat has its own camera, and the dead theirs
	if view == FIRST_PERSON or not camera.free() or not player.alive() or player.in_vehicle() then
		return
	end
	camera.view{
		distance = settings.distance,
		height = settings.height,
		backward = view == FRONT,
		crosshair = view == BEHIND,
	}
end
