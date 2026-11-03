-- The grappling hook of a campaign mod's a10.lua: press its button to fire a hook
-- along your aim, and again to let it go. On the line, hold jump to climb it (the
-- mod's pull, which pulls what it hit too) and crouch to let it out; otherwise the
-- line keeps its length and you swing on it. Its values are in mutator.toml's
-- [script].
--
-- tick() runs on every machine for every player, from the buttons the network
-- brings, so a client's player is pulled at once, as its running is. The host
-- decides: it alone moves what isn't a player, and its word corrects the rest.

-- the buttons each player's machine sends: the hook wanted, climbing, letting out
local HOOK = 0
local CLIMB = 1
local LET_OUT = 2

-- the mod's own: the hook's head, and the rope from the hand to it (its two nodes)
local HEAD = "altis\\weapons\\grappling_hook\\hook"
local ROPE = "altis\\weapons\\grappling_hook\\grappling_hook"

-- how much a vehicle moves. higher value means more
local VEHICLES = {
	["vehicles\\banshee\\banshee"] = 0.07,
	["vehicles\\c_dropship\\c_dropship"] = 0,
	["vehicles\\ghost\\ghost"] = 0.1,
	["vehicles\\lifepod\\lifepod"] = 0,
	["vehicles\\pelican\\pelican"] = 0,
	["vehicles\\warthog\\warthog"] = 0.1,
	["vehicles\\scorpion\\scorpion"] = 0.03,
	["vehicles\\c gun turret\\c gun turret"] = 0.35,
	["vehicles\\wraith\\wraith"] = 0.07,
}

-- how much of the pull reaches the player, by what the hook is in
local PLAYER_MASS = { weapon = 0.05, equipment = 0, garbage = 0, projectile = 0 }

local hooks = {}
local last_time = 0

local function state_of(index)
	local state = hooks[index]
	if not state then
		state = { ready = 0, armed = false }
		hooks[index] = state
	end
	return state
end

local function root_of(thing)
	local parent = thing and object.parent(thing)
	while parent do
		thing = parent
		parent = object.parent(thing)
	end
	return thing
end

local function release_moved(state)
	if state.moved then
		local x, y, z = object.velocity(state.moved)
		if x then
			object.set_velocity(state.moved, x * 0.5, y * 0.5, z * 0.5)
		end
		state.moved = nil
	end
end

local function remove_hook(state, unit)
	if state.hook then
		if state.hook.attached and unit then
			local x, y, z = object.velocity(unit)
			local mult = settings.release_multiplier
			object.set_velocity(unit, x * mult, y * mult, z * mult)
		end
		state.hook = nil
		state.ready = settings.cooldown
		release_moved(state)
	end
end

local function fire(state, index, unit)
	local x, y, z = object.position(unit)
	local ax, ay, az = player.aim(index)
	if not ax then
		return
	end
	local ahead = az < -0.9 and 0.5 or 0.3
	local side = 0.03
	local height = 0.615 - player.crouch(index) * (0.615 - 0.35)
	local velocity = settings.projectile_velocity
	state.hook = {
		x = x + ax * ahead - ay * side,
		y = y + ay * ahead + ax * side,
		z = z + az * ahead + height,
		vx = ax * velocity, vy = ay * velocity, vz = az * velocity,
		flown = 0,
		attached = false,
	}
	state.moved = nil
end

local function fly(hook, unit)
	local x, y, z, thing = world.ray(hook.x, hook.y, hook.z, hook.vx, hook.vy, hook.vz, unit)
	if x then
		hook.x, hook.y, hook.z = x, y, z
		hook.attached = true
		local ux, uy, uz = object.position(unit)
		hook.length = math.sqrt((x - ux) ^ 2 + (y - uy) ^ 2 + (z - uz) ^ 2)
		if thing then
			local tx, ty, tz = object.position(thing)
			hook.object = thing
			hook.ox, hook.oy, hook.oz = x - tx, y - ty, z - tz
		end
		return true
	end
	hook.x, hook.y, hook.z = hook.x + hook.vx, hook.y + hook.vy, hook.z + hook.vz
	hook.flown = hook.flown + settings.projectile_velocity
	return hook.flown < settings.range
end

-- a hook in an object goes where the object goes. False if it is gone.
local function follow(hook)
	if hook.object then
		local x, y, z = object.position(hook.object)
		if not x then
			return false
		end
		hook.x, hook.y, hook.z = x + hook.ox, y + hook.oy, z + hook.oz
	end
	return true
end

local function pull(state, hook, unit)
	local x, y, z = object.position(unit)
	local vx, vy, vz = object.velocity(unit)
	local parent = root_of(hook.object)
	local kind = parent and object.kind(parent)
	local mass = parent and PLAYER_MASS[kind] or 1

	local dx, dy = hook.x - x, hook.y - y
	local dz = hook.z - z - settings.z_offset
	if not parent then
		dz = dz + settings.z_offset * 2
	end
	local distance = math.sqrt(dx * dx + dy * dy + (z - hook.z) * (z - hook.z))
	local speed = settings.speed

	object.set_velocity(unit,
		vx + dx / distance * speed * mass,
		vy + dy / distance * speed * mass,
		vz + dz / distance * speed * mass)

	if parent and game.host() then
		local moved = (1 - mass) * settings.object_multiplier
		if kind == "vehicle" and VEHICLES[object.tag(parent)] then
			moved = VEHICLES[object.tag(parent)] * settings.object_multiplier
		elseif kind == "biped" then
			moved = object.acceleration_scale(parent) * 0.3 * settings.object_multiplier
		end
		if moved ~= 0 then
			if kind == "biped" and not state.moved then
				-- the first tug turns them around, and is the hard one
				if object.alive(parent) then
					object.turn_around(parent)
				end
				moved = moved * 5
			end
			if kind ~= "vehicle" then
				state.moved = parent
			end
			local px, py, pz = object.velocity(parent)
			object.set_velocity(parent,
				px - dx / distance * speed * moved,
				py - dy / distance * speed * moved,
				pz - dz / distance * speed * moved)
		end
	end
end

-- the line holds its length: what would take the player further is taken away,
-- and a little more brings them back to it, so they swing on it
local function hold(hook, unit, distance)
	if distance <= hook.length or distance <= 0 then
		return
	end
	local x, y, z = object.position(unit)
	local rx, ry, rz = (hook.x - x) / distance, (hook.y - y) / distance, (hook.z - z) / distance
	local vx, vy, vz = object.velocity(unit)
	local along = vx * rx + vy * ry + vz * rz
	local back = math.min((distance - hook.length) * 0.3, 0.2)
	if along < 0 then
		back = back - along
	end
	object.set_velocity(unit, vx + rx * back, vy + ry * back, vz + rz * back)
end

local function update(index)
	local state = state_of(index)
	local unit = player.unit(index)
	if not unit then
		state.hook = nil
		state.moved = nil
		return
	end
	local in_vehicle = object.parent(unit) ~= nil
	local wanted = player.button(index, HOOK)

	-- (a hook is fired as the button goes on: one that misses, or that a
	-- vehicle takes away, isn't fired again until it has been let go)
	if not wanted then
		state.armed = true
	end
	if state.hook and (not wanted or in_vehicle) then
		remove_hook(state, unit)
	end
	if state.ready > 0 then
		state.ready = state.ready - 1
	end
	if not state.hook and wanted and state.armed and state.ready == 0 and not in_vehicle then
		fire(state, index, unit)
		state.armed = false
	end

	local hook = state.hook
	if not hook then
		return
	end
	if not hook.attached then
		if not fly(hook, unit) then
			remove_hook(state, unit)
		end
		return
	end
	if not follow(hook) then
		remove_hook(state, unit)
		return
	end
	local x, y, z = object.position(unit)
	local dx, dy, dz = hook.x - x, hook.y - y, hook.z - z
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	-- (the line takes in what slack there is, as a winch's does: the player hangs
	-- where they came nearest, unless it is let out)
	if player.button(index, LET_OUT) then
		hook.length = math.min(settings.range, hook.length + settings.let_out_speed)
	else
		hook.length = math.max(settings.min_distance, math.min(hook.length, distance))
	end
	if player.button(index, CLIMB) then
		if distance > settings.min_distance then
			pull(state, hook, unit)
		end
		return
	end
	release_moved(state)
	hold(hook, unit, distance)
end

function tick()
	-- a checkpoint went back: nothing was hooked then
	local time = game.time()
	if time < last_time then
		hooks = {}
	end
	last_time = time

	for _, index in ipairs(game.players()) do
		update(index)
	end
end

-- the models this machine draws for each player's hook: made as it is fired (the
-- rope's making plays its sound), gone when it is
local shown = {}

local function hide(index)
	local models = shown[index]
	if models then
		model.delete(models.head)
		model.delete(models.rope)
		shown[index] = nil
	end
end

-- a line where the map has none of the mod's models
local function draw_line_rope(first_person, ux, uy, uz, hook)
	local x, y, z = hook.x, hook.y, hook.z
	local r, g, b = 0.75, 0.75, 0.7
	if first_person then
		draw.line_from_view(0.12, 0.1, 0.25, x, y, z, r, g, b)
	else
		draw.line(ux, uy, uz, x, y, z, r, g, b)
	end
	local size = 0.04
	draw.line(x - size, y, z, x + size, y, z, r, g, b)
	draw.line(x, y - size, z, x, y + size, z, r, g, b)
	draw.line(x, y, z - size, x, y, z + size, r, g, b)
end

local function show(index, hook, unit)
	local models = shown[index]
	if models and hook ~= models.hook then
		hide(index)
		models = nil
	end
	local ux, uy, uz = object.position(unit)
	uz = uz + 0.4
	if not models then
		models = { hook = hook }
		models.rope = model.create(ROPE, ux, uy, uz, unit)
		models.head = model.create(HEAD, hook.x, hook.y, hook.z, unit)
		shown[index] = models
	end
	local first_person = index == player.local_index() and camera.first_person()
	if not model.exists(models.rope) or not model.exists(models.head) then
		draw_line_rope(first_person, ux, uy, uz, hook)
		return
	end
	-- the head points the way it flew
	model.place(models.head, hook.x, hook.y, hook.z, hook.vx, hook.vy, hook.vz, 0, 0, 1)
	model.place(models.rope, ux, uy, uz)
	model.node(models.rope, 1, hook.x, hook.y, hook.z)
	if first_person then
		model.node_from_view(models.rope, 0, 0.12, 0.1, 0.25)
	else
		model.node(models.rope, 0, ux, uy, uz)
	end
	model.face_view(models.rope)
end

-- this machine's player's hook, as its button toggles it
local wanted = false
local was_pressed = false
local asked_at = 0
local seen = false

local function toggle()
	local pressed = input.held(settings.keyboard) or input.held(settings.controller)
	local time = game.time()
	if pressed and not was_pressed then
		wanted = not wanted
		asked_at = time
		seen = false
	end
	was_pressed = pressed
	-- (one that went by itself, a miss or a vehicle, or that never went, is off)
	if wanted then
		local index = player.local_index()
		local state = index and hooks[index]
		if state and state.hook then
			seen = true
		elseif seen or time < asked_at or time - asked_at > settings.cooldown + 15 then
			wanted = false
		end
	end
	input.button(HOOK, wanted)
	input.button(CLIMB, wanted and input.jump())
	input.button(LET_OUT, wanted and input.crouch())
end

function frame()
	toggle()
	for index in pairs(shown) do
		local state = hooks[index]
		if not state or not state.hook or not player.unit(index) then
			hide(index)
		end
	end
	for index, state in pairs(hooks) do
		local unit = player.unit(index)
		if state.hook and unit then
			show(index, state.hook, unit)
		end
	end
end
