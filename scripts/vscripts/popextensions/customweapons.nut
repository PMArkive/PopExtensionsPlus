//credit to ficool2, Yaki and LizardofOz
ExtraItems <-
{
	"Wasp Launcher" :
	{
        OriginalItemName = "Upgradeable TF_WEAPON_ROCKETLAUNCHER"
        Model = "models/weapons/c_models/c_wasp_launcher/c_wasp_launcher.mdl"
        "blast radius increased" : 1.5
        "max health additive bonus" : 100
	}
	"Thumper" :
	{
        OriginalItemName = "Upgradeable TF_WEAPON_SHOTGUN_PRIMARY"
        Model = "models/weapons/c_models/c_rapidfire/c_rapidfire_1.mdl"
		//defaults to engineer's primary shotgun, need to specify
		//ItemClass and Animset to use secondary shotgun on non shotgun wielding classes
		ItemClass = "tf_weapon_shotgun_soldier"
        AnimSet = "soldier"
		Slot = "secondary"
        "damage bonus" : 2.3
        "clip size bonus" : 1.25
        "weapon spread bonus" : 0.85
        "maxammo secondary increased" : 1.5
        "fire rate penalty" : 1.2
        "bullets per shot bonus" : 0.5
        "Reload time increased" : 1.13
        "single wep deploy time increased" : 1.15
        "minicritboost on kill" : 5
	}
	"Crowbar" :
	{
        OriginalItemName = "Necro Smasher"
        Model = "models/weapons/c_models/c_cratesmasher/c_cratesmasher_1.mdl"
		"deploy time decreased" : 0.75
		"fire rate bonus" : 0.30
		"damage penalty" : 0.54
	}
}

//arrays copied from Yaki's gtfw
//Order based on internal constants of ETFClass
// Use: TF_AMMO_PER_CLASS_PRIMARY[hPlayer.GetPlayerClass()]
::TF_AMMO_PER_CLASS_PRIMARY <- {
	"scout" : 32,	//Scout
	"sniper" : 25,	//Sniper
	"soldier" : 20	//Soldier
	"demo" : 16,	//Demo
	"medic" : 150	//Medic
	"heavy" : 200,	//Heavy
	"pyro" : 200,	//Pyro
	"spy" : 20,	//Spy
	"engineer" : 32,	//Engineer
}

//Order based on internal constants of ETFClass
// Use: TF_AMMO_PER_CLASS_SECONDARY[hPlayer.GetPlayerClass()]
::TF_AMMO_PER_CLASS_SECONDARY <- {
	"scout" : 36,	//Scout
	"sniper" : 75,	//Sniper
	"soldier" : 32	//Soldier
	"demo" : 24,	//Demo
	"medic" : 150	//Medic
	"heavy" : 32,	//Heavy
	"pyro" : 32,	//Pyro
	"spy" : 24,	//Spy
	"engineer" : 200,	//Engineer
}

::CustomWeapons <- {
	//give item to specified player
	//itemname accepts strings
	//player accepts player entities
	function GiveItem(itemname, player)
	{
		if (!player || player.GetPlayerClass() < 1) return
		local playerclass = PopExtUtil.Classes[player.GetPlayerClass()]

		local extraitem = null
		local model = null
		local modelindex = null
		local animset = null
		local id = null
		local item_class = null
		local item_slot = null

		//if item is a custom item, overwrite itemname with OriginalItemName
		if (itemname in ExtraItems)
		{
			extraitem = ExtraItems[itemname]
			itemname = ExtraItems[itemname].OriginalItemName
		}

		if (itemname in PopExtItems)
		{
			id = PopExtItems[itemname].id
			model = PopExtItems[itemname].model_player
			modelindex = GetModelIndex(model)
			animset = PopExtItems[itemname].animset
			item_class = PopExtItems[itemname].item_class
			item_slot = PopExtItems[itemname].item_slot

			if (typeof(PopExtItems[itemname].animset) == "array")
			{
				if (PopExtItems[itemname].animset.find(playerclass) == null) 
				{
					animset = PopExtItems[itemname].animset[0]
					item_class = PopExtItems[itemname].item_class[0]
					item_slot = PopExtItems[itemname].item_slot[0]
				}
				else 
				{
					animset = PopExtItems[itemname].animset[PopExtItems[itemname].animset.find(playerclass)]
					item_class = PopExtItems[itemname].item_class[PopExtItems[itemname].animset.find(playerclass)]
					item_slot = PopExtItems[itemname].item_slot[PopExtItems[itemname].animset.find(playerclass)]
				}
			}

			//multiclass items will not spawn unless they are specified for a certain class
			//this includes multiclass shotguns, melees, base jumper, pain train (but not half zatoichi)
			//the stock pistol, tf_weapon_pistol is a valid classname and will spawn however tf_weapon_pistol_scout is also supported

			//animset can be a array or a string, arrays exist for weapons that are multi class (shotgun pistol and all class melees)
			//if the current player's class is not one of the classes listed in the table, it will fall back to the first index
		}
		else return

		//replace overrides if they exist in extraitems
		if (extraitem != null)
		{
			if ("ItemClass" in extraitem) item_class = extraitem.ItemClass
			if ("Model" in extraitem) model = extraitem.Model; modelindex = GetModelIndex(model)
			if ("AnimSet" in extraitem) animset = extraitem.AnimSet
			if ("Slot" in extraitem) item_slot = extraitem.Slot
		}

		//create item entity
		local item = CreateByClassname(item_class)
		SetPropInt(item, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", id)
		SetPropBool(item, "m_AttributeManager.m_Item.m_bInitialized", true)
		SetPropBool(item, "m_bValidatedAttachedEntity", true)
		item.SetTeam(player.GetTeam())
		DispatchSpawn(item)
		local reservedKeywords = {
			"OriginalItemName" : null
			"ItemClass" : null
			"Name" : null
			"Model" : null
			"AnimSet" : null
			"Slot" : null
		}
		if (extraitem != null)
			foreach (attribute, value in extraitem)
				if (!(attribute in reservedKeywords))
					if (attribute in CustomAttributes.Attrs)
						CustomAttributes.AddAttr(player, attribute, value, {item = [attribute, value]})
					else
						item.AddAttribute(attribute, value, -1.0)

		//if max ammo needs to be changed, create a tf_wearable and assign attributes to it
		if (item_slot == "primary")
		{
			if (TF_AMMO_PER_CLASS_PRIMARY[playerclass] != TF_AMMO_PER_CLASS_PRIMARY[animset]) 
			{
				player.ValidateScriptScope()
				if (!("ammofix" in player.GetScriptScope()))
				{
					local ammofix = CreateByClassname("tf_wearable")
					SetPropBool(ammofix, "m_bValidatedAttachedEntity", true)
					SetPropBool(ammofix, "m_AttributeManager.m_Item.m_bInitialized", true)
					SetPropEntity(ammofix, "m_hOwnerEntity", player)
					ammofix.SetOwner(player)
					ammofix.DispatchSpawn()
					player.GetScriptScope().ammofix <- ammofix
				}
				player.GetScriptScope().ammofix.AddAttribute("hidden primary max ammo bonus", TF_AMMO_PER_CLASS_PRIMARY[animset].tofloat() / TF_AMMO_PER_CLASS_PRIMARY[playerclass].tofloat(), -1.0)
				player.GetScriptScope().ammofix.ReapplyProvision()
			}
		}

		if (item_slot == "secondary")
		{
			if (TF_AMMO_PER_CLASS_SECONDARY[playerclass] != TF_AMMO_PER_CLASS_SECONDARY[animset]) 
			{
				player.ValidateScriptScope()
				if (!("ammofix" in player.GetScriptScope()))
				{
					local ammofix = CreateByClassname("tf_wearable")
					SetPropBool(ammofix, "m_bValidatedAttachedEntity", true)
					SetPropBool(ammofix, "m_AttributeManager.m_Item.m_bInitialized", true)
					SetPropEntity(ammofix, "m_hOwnerEntity", player)
					ammofix.SetOwner(player)
					ammofix.DispatchSpawn()
					player.GetScriptScope().ammofix <- ammofix
				}
				player.GetScriptScope().ammofix.AddAttribute("hidden secondary max ammo penalty", TF_AMMO_PER_CLASS_SECONDARY[animset].tofloat() / TF_AMMO_PER_CLASS_SECONDARY[playerclass].tofloat(), -1.0)
				player.GetScriptScope().ammofix.ReapplyProvision()
			}
		}


		//find the slot of the weapon then iterate through all entities parented to the player
		//and kill the entity that occupies the required slot
		local slot = FindSlot(item)
		if (slot != null)
		{
			local itemreplace = player.FirstMoveChild()
			while (itemreplace)
			{
				if (FindSlot(itemreplace) == slot)
				{
					itemreplace.Destroy()
					break
				}
				itemreplace = itemreplace.NextMovePeer()
			}
			player.Weapon_Equip(item)

			// copied from ficool2 mw2_highrise
			// viewmodel
			local main_viewmodel = GetPropEntity(player, "m_hViewModel")

			local armmodel = "models/weapons/c_models/c_" + animset + "_arms.mdl"

			//animset ? armmodel = animset : armmodel = main_viewmodel.GetModelName()

			item.SetModelSimple(armmodel)
			item.SetCustomViewModel(armmodel)
			item.SetCustomViewModelModelIndex(GetModelIndex(armmodel))
			SetPropInt(item, "m_iViewModelIndex", GetModelIndex(armmodel))

			// worldmodel
			local tpWearable = CreateByClassname("tf_wearable")
			SetPropInt(tpWearable, "m_nModelIndex", modelindex)
			SetPropBool(tpWearable, "m_bValidatedAttachedEntity", true)
			SetPropBool(tpWearable, "m_AttributeManager.m_Item.m_bInitialized", true)
			SetPropEntity(tpWearable, "m_hOwnerEntity", player)
			tpWearable.SetOwner(player)
			tpWearable.DispatchSpawn()
			EntFireByHandle(tpWearable, "SetParent", "!activator", 0.0, player, player)
			SetPropInt(tpWearable, "m_fEffects", 129) // EF_BONEMERGE|EF_BONEMERGE_FASTCULL

			// copied from LizardOfOz open fortress dm_crossfire
			// viewmodel arms
			SetPropInt(item, "m_nRenderMode", kRenderTransColor)
			SetPropInt(item, "m_clrRender", 1)

			local hands = SpawnEntityFromTable("tf_wearable_vm", {
				modelindex = PrecacheModel(format("models/weapons/c_models/c_%s_arms.mdl", playerclass))
			})
			SetPropBool(hands, "m_bForcePurgeFixedupStrings", true)
			player.EquipWearableViewModel(hands)

			local hands2 = SpawnEntityFromTable("tf_wearable_vm", {
				modelindex = PrecacheModel(model)
			})
			SetPropBool(hands2, "m_bForcePurgeFixedupStrings", true)
			player.EquipWearableViewModel(hands2)

			SetPropEntity(hands2, "m_hWeaponAssociatedWith", item)
			SetPropEntity(item, "m_hExtraWearableViewModel", hands2)

			player.Weapon_Switch(item)
			player.ValidateScriptScope()
		}
		return item;
	}

	//returns the slot number of entities with classname tf_weapon_
	//also includes exceptions for passive weapons such as demo shields, soldier/demo boots and sniper backpacks
	//action items includes canteen, contracker
	//return null if the entity is not a weapon or passive weapon
	function FindSlot(item)
	{
		if (item.GetClassname().find("tf_weapon_") == 0) return item.GetSlot()
		else
		{
			//base jumper and invis watches are not included as they have classnames starting with "tf_weapon_"
			local id = GetPropInt(item, "m_AttributeManager.m_Item.m_iItemDefinitionIndex")

			//Ali Baba's Wee Booties and Bootlegger
			if ([405, 608].find(id) != null) return 0

			//Razorback, Gunboats, Darwin's Danger Shield, Mantreads, Cozy Camper
			else if ([57, 133, 231, 444, 642].find(id) != null) return 1

			//All demo shields
			else if (item.GetClassname() == "tf_wearable_demoshield") return 1

			//Action items, Canteens and Contracker
			else if ((item.GetClassname() == "tf_powerup_bottle"|| item.GetClassname() == "tf_wearable_campaign_item")) return 5
		}
		return null
	}

	//equip item in player's loadout, does not give item
	//itemname accepts strings
	//player accepts player entities
	//playerclass accepts integers, will default to player's current class if null, optional
	function EquipItem(itemname, player, playerclass = null)
	{
		if (playerclass == null) playerclass = player.GetPlayerClass()
		player.ValidateScriptScope()
		if (!("ExtraLoadout" in player.GetScriptScope()))
		{
			local ExtraLoadout = array(10)
			player.GetScriptScope().ExtraLoadout <- ExtraLoadout
		}
		if (player.GetScriptScope().ExtraLoadout[playerclass] == null)
			player.GetScriptScope().ExtraLoadout[playerclass] = []
			
		if (player.GetScriptScope().ExtraLoadout[playerclass].find(itemname) == null)
			player.GetScriptScope().ExtraLoadout[playerclass].append(itemname)
	}

	//unequip item in player's loadout
	//itemname accepts strings
	//player accepts player entities
	//playerclass accepts integers, will default to player's current class if null, optional
	function UnequipItem(itemname, player, playerclass = null)
	{
		if (playerclass == null) playerclass = player.GetPlayerClass()
		player.ValidateScriptScope()
		if ("ExtraLoadout" in player.GetScriptScope())
			if (ExtraLoadout[playerclass] != null)
				if (player.GetScriptScope().ExtraLoadout[playerclass].find(itemname) != null)
					player.GetScriptScope().ExtraLoadout[playerclass].remove(player.GetScriptScope().ExtraLoadout[playerclass].find(itemname))

	}
}


/* function OnGameEvent_post_inventory_application(params)
{
	printl(params.userid)
	ClientPrint(null, 3, "post_inventory_application")
	ClientPrint(null, 3, params.userid)

	local player = GetPlayerFromUserID(params.userid)
	local playerclass = player.GetPlayerClass()
	if ("ExtraLoadout" in player.GetScriptScope())
		if (player.GetScriptScope().ExtraLoadout[playerclass] != null)
			for (local i = 0; i < player.GetScriptScope().ExtraLoadout[playerclass].len(); i++)
				CustomWeapons.GiveItem(player.GetScriptScope().ExtraLoadout[playerclass][i], player)
} */
