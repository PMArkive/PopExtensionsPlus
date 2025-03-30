// By washy
PopExt.waveSchedulePointTemplates <- []
PopExt.wavePointTemplates         <- []
PopExt.globalTemplateSpawnCount   <- 0

//spawns an entity when called, can be called on StartWaveOutput and InitWaveOutput, automatically kills itself after wave completion
::SpawnTemplate <- function(pointtemplate, parent = null, origin = "", angles = "", forceparent = false, attachment = null, purgestrings = true) {

	if (forceparent && parent.IsEFlagSet(EFL_SPAWNTEMPLATE))
		parent.RemoveEFlags(EFL_SPAWNTEMPLATE) //forceparent is set, delete the EFlag to parent another template

	if (parent != null && parent.IsEFlagSet(EFL_SPAWNTEMPLATE))
		return //we already have a template

	// credit to ficool2
	PopExt.globalTemplateSpawnCount <- PopExt.globalTemplateSpawnCount + 1
	local template = CreateByClassname("point_script_template")
	DispatchSpawn(template)
	local scope = template.GetScriptScope()

	local nofixup = false
	local keepalive = false
	local removeifkilled = ""

	scope.parent <- parent
	scope.Entities <- []
	scope.EntityFixedUpTargetName <- []
	scope.OnSpawnOutputArray <- []
	scope.OnParentKilledOutputArray <- []
	scope.SpawnedEntities <- {}

	scope.__EntityMakerResult <- {
		entities = scope.Entities
	}.setdelegate({
		_newslot = function(_, value) {
			entities.append(value)
		}
	})

	scope.PostSpawn <- function(named_entities) {

		//can only set bounding box size for brush entities after they spawn
		foreach(entity in Entities)
		{
			local responsecontext = GetPropString(entity, "m_iszResponseContext")
			local buf = responsecontext.find(",") ? split(responsecontext, ",") : split(responsecontext, " ")

			if (buf.len() == 6)
			{
				buf.apply( function(val) { return val.tofloat() })
				entity.SetSize(Vector(buf[0], buf[1], buf[2]), Vector(buf[3], buf[4], buf[5]))
				entity.SetSolid(2)
			}

			if (purgestrings)
				SetPropBool(entity, "m_bForcePurgeFixedupStrings", true)

			scope.SpawnedEntities[entity] <- [origin, angles]

			if (origin != "" || angles != "")
			{
				foreach(k, v in SpawnedEntities)
				{
					if (origin != "")
					{
						if (typeof origin == "Vector")
							k.SetOrigin(origin)
						else
						{
							local orgbuf = v[0].find(",") ? split(v[0], ",") : split(v[0], " ")
							orgbuf.apply(@(val) val.tofloat() )
							k.SetOrigin(Vector(orgbuf[0], orgbuf[1], orgbuf[2]))
						}
					}
					if (angles != "")
					{
						if (typeof angles == "QAngle")
							k.SetAbsAngles(angles)
						else
						{
							local angbuf = v[1].find(",") ? split(v[1], ",") : split(v[1], " ")
							angbuf.apply(@(val) val.tofloat() )
							k.SetAbsAngles(QAngle(angbuf[0], angbuf[1], angbuf[2]))
						}
					}
				}
			}

			PopExt.wavePointTemplates.append(entity)

			if (parent != null) {

				if (typeof parent == "string") parent = FindByName(null, parent)
				//this function is defined in util.nut
				PopExtUtil.SetParentLocalOrigin(entity, parent, attachment)

				//entities parented to players do not kill itself when the player dies as the player entity is not considered killed
				if (parent.IsPlayer()) {

					parent.AddEFlags(EFL_SPAWNTEMPLATE)

					if (!keepalive) {
						parent.ValidateScriptScope()
						local scope = parent.GetScriptScope()

						// reused from CreatePlayerWearable function
						if (!("popWearablesToDestroy" in scope))
							scope.popWearablesToDestroy <- []

						scope.popWearablesToDestroy.append(entity)
					}
				}
			}
		}
		if (parent && parent.IsValid()) {

			function FireOnParentKilledOutputs() {

				foreach(output in scope.OnParentKilledOutputArray) {

					local target 	= output.Target
					local action 	= output.Action
					local param  	= ("Param" in output) ? output.Param.tostring() : ""
					local delay  	= ("Delay" in output) ? output.Delay.tofloat() : -1
					local activator = ("Activator" in output) ? (typeof(output.Activator) == "string" ? FindByName(null, output.Activator) : output.Activator) : null
					local caller 	= ("Caller" in output) ? (typeof(output.Caller) == "string" ? FindByName(null, output.Caller) : output.Caller) : null

					local entfirefunc = typeof(target) == "string" ? DoEntFire : EntFireByHandle
					entfirefunc(target, action, param, delay, activator, caller)
				}
			}

			if (parent.IsPlayer()) {

				// copied from popextensions_hooks.nut
				if (scope.OnParentKilledOutputArray.len()) {

					local playerscope = parent.GetScriptScope()

					if (!("popHooks" in playerscope)) {
						playerscope.popHooks <- {}
					}

					if (!("OnDeath" in playerscope.popHooks)) {
						playerscope.popHooks.OnDeath <- []
					}

					// FireOnParentKilledOutputs()

					playerscope.popHooks.OnDeath.append(FireOnParentKilledOutputs)

					FireOnParentKilledOutputs()
					if (!("TemplatesToKill" in playerscope)) playerscope.TemplatesToKill <- []
					playerscope.TemplatesToKill.append(FireOnParentKilledOutputs);
				}
			}
			//use own think instead of parent's think
			function CheckIfKilled() {

				if (parent && parent.IsValid()) {
					lastorigin <- parent.GetOrigin()
					lastangles <- parent.GetAbsAngles()
				}
				else {
					if (keepalive)
						//spawn template again after being killed
						SpawnTemplate(pointtemplate, null, lastorigin + origin, lastangles + angles)

					//fire OnParentKilledOutputs
					//does not work on its own internal entities if NoFixup is true since the entities are always killed
					FireOnParentKilledOutputs()

					SetPropString(self, "m_iszScriptThinkFunction", "")
					self.RemoveEFlags(EFL_SPAWNTEMPLATE)
				}

				if (removeifkilled != "") {
					if (FindByName(null, removeifkilled) == null) {
						foreach(entity, _ in scope.SpawnedEntities)
							if (entity && entity.IsValid())
								entity.Kill()

						SetPropString(self, "m_iszScriptThinkFunction", "")
					}
				}
				return -1
			}
			"PlayerThinkTable" in scope ?
			scope.PlayerThinkTable.CheckIfKilled <- CheckIfKilled :
			scope.CheckIfKilled <- CheckIfKilled; AddThinkToEnt(template, "CheckIfKilled")
		}

		//fire OnSpawnOutputs
		foreach(output in scope.OnSpawnOutputArray) {

			local target 	= output.Target
			local action 	= output.Action
			local param  	= ("Param" in output) ? output.Param.tostring() : ""
			local delay  	= ("Delay" in output) ? output.Delay.tofloat() : -1
			local activator = ("Activator" in output) ? (typeof(output.Activator) == "string" ? FindByName(null, output.Activator) : output.Activator) : null
			local caller 	= ("Caller" in output) ? (typeof(output.Caller) == "string" ? FindByName(null, output.Caller) : output.Caller) : null

			local entfirefunc = typeof(target) == "string" ? DoEntFire : EntFireByHandle
			entfirefunc(target, action, param, delay, activator, caller)
		}
	}

	//make a copy of the pointtemplate
	local pointtemplatecopy = PopExtUtil.CopyTable(PointTemplates[pointtemplate])

	if ("DontPurgeStrings" in pointtemplatecopy && !pointtemplatecopy.DontPurgeStrings)
		purgestrings = false

	//establish "flags"
	foreach(index, entity in pointtemplatecopy) {

		if (typeof(index) != "string") continue

		if (index.tolower() == "nofixup" && entity)
			nofixup = true

		else if (index.tolower() == "keepalive" && entity)
			keepalive = true

		else if (index.tolower() == "dontpurgestrings" && entity)
			purgestrings = false

		else if (index.tolower() == "removeifkilled")
			scope.removeifkilled <- entity
	}

	//perform name fixup
	if (!nofixup) {
		//first, get list of targetnames in the point template for name fixup
		foreach(index, entity in pointtemplatecopy)
		{
			if (typeof(entity) != "table") continue

			foreach(classname, keyvalues in entity)
				foreach(key, value in keyvalues)
					if (key == "targetname" && scope.EntityFixedUpTargetName.find(value) == null)
						scope.EntityFixedUpTargetName.append(value)
		}

		//iterate through all entities and fixup every value containing a valid targetname
		//may have issues with targetnames that are substrings of other targetnames?
		//this should cover targetnames, parentnames, target, and output params
		foreach(index, entity in pointtemplatecopy)
		{
			if (typeof(entity) != "table") continue

			foreach(classname, keyvalues in entity)
			{
				foreach(key, value in keyvalues)
				{
					if (typeof(value) != "string") continue

					foreach(targetname in scope.EntityFixedUpTargetName)
					{
						if (value.find(targetname) != null && value.find("/") == null) //ignore potential file paths, also ignores targetnames with "/"
						{
							keyvalues[key] <- value.slice(0, targetname.len()) + PopExt.globalTemplateSpawnCount + value.slice(targetname.len())
						}
					}
				}
			}
			if (index == "RemoveIfKilled") scope.removeifkilled <- entity + PopExt.globalTemplateSpawnCount
		}
	}

	//add templates to point_script_template
	foreach(index, entity in pointtemplatecopy)
	{
		if (typeof(entity) != "table") continue

		foreach(classname, keyvalues in entity)
		{
			if (classname == "OnSpawnOutput")
				scope.OnSpawnOutputArray.append(keyvalues)

			else if (classname == "OnParentKilledOutput")
				scope.OnParentKilledOutputArray.append(keyvalues)

			else
			{
				//adjust origin and angles
				if ("origin" in keyvalues)
				{
					//if origin is a string, construct vectors to perform math on them if needed
					if (typeof(keyvalues.origin) == "string") {
						local buf = keyvalues.origin.find(",") ? split(keyvalues.origin, ",") : split(keyvalues.origin, " ")

						buf.apply(@(val) val.tofloat() )
						keyvalues.origin = Vector(buf[0], buf[1], buf[2])
					}
					// keyvalues.origin += origin
				}
				else keyvalues.origin <- origin

				if ("angles" in keyvalues)
				{
					//if angles is a string, construct qangles to perform math on them if needed
					if (typeof(keyvalues.angles) == "string") {
						local buf = keyvalues.angles.find(",") ? split(keyvalues.angles, ",") : split(keyvalues.angles, " ")

						buf.apply(@(val) val.tofloat() )
						keyvalues.angles = QAngle(buf[0], buf[1], buf[2])
					}
					// keyvalues.angles += angles
				}
				else keyvalues.angles <- angles

				//needed for brush entities
				if ("mins" in keyvalues || "maxs" in keyvalues) {
					local mins = ("mins" in keyvalues) ? keyvalues.mins : Vector()
					local maxs = ("maxs" in keyvalues) ? keyvalues.maxs : Vector()
					if (typeof(mins) == "Vector") mins =  mins.ToKVString()
					if (typeof(maxs) == "Vector") maxs =  maxs.ToKVString()

					local mins_sum = (mins.find(",") ? split(mins, ",") : split(mins, " ")).apply(@(val) val.tofloat()).reduce(@(a, b) a + b, 0)
					local maxs_sum = (maxs.find(",") ? split(maxs, ",") : split(maxs, " ")).apply(@(val) val.tofloat()).reduce(@(a, b) a + b, 0)

					if (mins_sum > maxs_sum) {
						printl(format("\n\n**SPAWNTEMPLATE WARNING: mins > maxs on %s! Inverting...**\n\n", "targetname" in keyvalues ? keyvalues.targetname : classname))
						keyvalues.mins <- maxs
						keyvalues.maxs <- mins
						mins = maxs
						maxs = mins
					}

					//overwrite responsecontext even if someone fills it in for some reason
					keyvalues.responsecontext <- format("%s %s", mins, maxs)
				}

				template.AddTemplate(classname, keyvalues)
			}
		}
	}
	EntFireByHandle(template, "ForceSpawn", "", -1, null, null)
}

//altenative version of SpawnTemplate that will recreate itself only after wave resets (after failure, after voting, after using tf_mvm_jump_to_wave) to imitate spawning in WaveSchedule
//does not accept parent parameter, does not allow parenting entities
::SpawnTemplateWaveSchedule <- function (pointtemplate, origin = null, angles = null) {
	PopExt.waveSchedulePointTemplates.append([PointTemplates[pointtemplate], origin, angles])
}

::SpawnTemplates <- {
	//hook to both of these events to emulate OnWaveInit
	Events = {

		function OnGameEvent_mvm_wave_complete(params) {

			foreach(entity in PopExt.wavePointTemplates)
				if (entity.IsValid())
					entity.Kill()

			PopExt.wavePointTemplates.clear()
		}

		//despite the name, this event also calls on wave reset from voting, and on jumping to wave, and when loading mission
		function OnGameEvent_mvm_wave_failed(params) {

			foreach(entity in PopExt.wavePointTemplates)
				if (entity.IsValid())
					entity.Kill()
			//messy
			foreach(param in PopExt.waveSchedulePointTemplates) {
				SpawnTemplate(param[0], null, param[1], param[2])
			}
		}

		function OnGameEvent_player_death(params) {

			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()

			if ("TemplatesToKill" in scope)
				foreach (func in scope.TemplatesToKill)
					func()

			player.RemoveEFlags(EFL_SPAWNTEMPLATE)
		}
	}

	// alternative version that accepts a table of arguments
	function DoSpawnTemplate(args = { pointtemplate = null, parent = null, origin = "", angles = "", forceparent = false, purgestrings = true }) {
		SpawnTemplate(args.pointtemplate, args.parent, args.origin, args.angles, args.forceparent, args.purgestrings)
	}
}
__CollectGameEventCallbacks(SpawnTemplates.Events)
