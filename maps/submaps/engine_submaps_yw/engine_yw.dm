//player pickble engine marker.
//Holds all objects related to player chosen engine. - gozulio.
//Engine submaps get declared in engine_yw_index.dm

/obj/effect/landmark/engine_loader_pickable
	name = "Player Picked Engine Loader"
	var/clean_turfs // A list of lists, where each list is (x, )

//check for duplicte loaders. TODO: Make referance a subsystem that isnt upstream. See /controllers/subsystems/mapping_yw.dm and mapping_vr.dm
/obj/effect/landmark/engine_loader_pickable/New()
	if(SSmapping.engine_loader_pickable)
		warning("Duplicate engine_loader landmarks: [log_info_line(src)] and [log_info_line(SSmapping.engine_loader)]")
		delete_me = TRUE
	SSmapping.engine_loader_pickable = src
	return ..()

/obj/effect/landmark/engine_loader_pickable/proc/get_turfs_to_clean()
	. = list()
	if(clean_turfs)
		for(var/list/coords in clean_turfs)
			. += block(locate(coords[1], coords[2], src.z), locate(coords[3], coords[4], src.z))

/obj/effect/landmark/engine_loader_pickable/proc/annihilate_bounds()
	var/deleted_atoms = 0
	var/killed_mobs = 0
	admin_notice("<span class='danger'>Annihilating objects in engine loading location.</span>", R_DEBUG)
	var/list/turfs_to_clean = get_turfs_to_clean()
	if(turfs_to_clean.len)
		for(var/x in 1 to 2) // Delete things that shouldn't be players.
			for(var/turf/T in turfs_to_clean)
				for(var/atom/movable/AM in T)
					if(!istype(AM, /mob/living) && !istype(AM, /mob/observer))
						if(istype(AM, /mob)) // a mob we don't know what to do with got in somehow.
							message_admins("a mob of type [AM.type] was in the build area and got deleted.", R_DEBUG)
							++killed_mobs
						qdel(AM)
						++deleted_atoms

		for(var/turf/T in turfs_to_clean) //now deal with those pesky mobs.
			for(var/mob/living/LH in T)
				if(istype(LH, /mob/living))
					to_chat(LH, "<span class='danger'>It feels like you're being torn apart!</span>")
					LH.apply_effect(20, AGONY, 0, 0)
					LH.visible_message("<span class='danger'>[LH.name] is ripped apart by something you can't see!</span>")
					LH.gib() //Murder them horribly!
					message_admins("[key_name(LH, LH.client)] was just killed by the engine loader!", R_DEBUG)
					++killed_mobs

	admin_notice("<span class='danger'>Annihilated [deleted_atoms] objects.</span>", R_DEBUG)
	admin_notice("<span class='danger'>Annihilated [killed_mobs] Living Mobs</span>", R_DEBUG)

/obj/machinery/computer/pickengine
	name = "Engine Selector."
	desc = "A Terminal for selecting what engine will be assembled for the station."
	icon = 'icons/obj/computer.dmi' //Barrowed from supply computer.
	icon_keyboard = "tech_key"
	icon_screen = "supply"
	light_color = "#b88b2e"
	req_one_access = list(access_engine, access_heads)
	var/lifetime = 900 //lifetime decreases every seconds, hopefully. see process()
	var/destroy = 0 //killmepls
	var/building = 0

/obj/machinery/computer/pickengine/New()
	message_admins("Engine select console placed at [src.x] [src.y] [src.z]")
	..()

/obj/machinery/computer/pickengine/attack_ai(var/mob/user as mob)
	user << "<span class='warning'>The network data sent by this machine is encrypted!</span>"
	return

/obj/machinery/computer/pickengine/attack_hand(var/mob/user as mob)

	if(!allowed(user))
		user << "<span class='warning'>Access Denied.</span>"
		return

	if(..())
		return

	add_fingerprint(user)
	user.set_machine(src)
	var/dat

	dat += "<B>Engine Select console</B><BR>"
	dat += "Please select an engine for construction.<BR><HR>"
	dat += "Engine autoselect in [time2text(src.lifetime * 10, "mm:ss")].<BR>"
	dat += "WARNING: Selecting an engine will deploy nanobots to construct it. These nanobots will attempt to disassemble anything in their way, including curious engineers!.<BR>"

	dat += "<A href='?src=\ref[src];TESLA=1'>Build Tesla engine</A><BR>"
	dat += "<A href='?src=\ref[src];SM=1'>Build Supermatter Engine</A><BR>"
	dat += "<A href='?src=\ref[src];RUSTEngine=1'>Build R-UST</A><BR>"

	dat += "<A href='?src=\ref[user];mach_close=computer'>Close</A>"
	user << browse(dat, "window=computer;size=575x450")
	onclose(user, "computer")
	return

/obj/machinery/computer/pickengine/Topic(href, href_list)
	if(..())
		return 1

	if( isturf(loc) && (in_range(src, usr) || istype(usr, /mob/living/silicon)) )
		usr.set_machine(src)

	if(href_list["RUSTEngine"] && !building)
		setEngineType("R-UST Engine")

	if(href_list["TESLA"] && !building)
		setEngineType("Edison's Bane")

	if(href_list["SM"] && !building)
		setEngineType("Supermatter Engine")

	if(href_list["close"])
		usr << browse(null, "window=computer")
		usr.unset_machine()

	add_fingerprint(usr)
	updateUsrDialog()
	return

/obj/machinery/computer/pickengine/proc/setEngineType(engine)
	building = 1
	usr << browse(null, "window=computer")
	usr.unset_machine()
	global_announcer.autosay("Engine selected: You have 30 seconds to clear the engine Room!", "Engine Constructor", "Engineering")
	spawn(300)
		SSmapping.pickEngine(engine)
	destroy = 1

/obj/machinery/computer/pickengine/process()
	--lifetime
	if(lifetime <= 0 && !building) //We timed out while building, but we're allready building so it's okay!
		setEngineType(pick(config.engine_map))

	if(destroy)
		qdel(src)
	sleep(10 * world.tick_lag) // should sleep for roughly one second before trying again.
