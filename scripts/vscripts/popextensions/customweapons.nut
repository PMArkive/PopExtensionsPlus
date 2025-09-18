//By washy
//credit to ficool2, Yaki and LizardofOz
//special thanks to fellen for help on tf_item_map.nut

POPEXT_CREATE_SCOPE( "__popext_customweapons", "PopExtWeapons" )

//arrays copied from Yaki's gtfw
//Order based on internal constants of ETFClass
PopExtWeapons.TF_AMMO_PER_CLASS_PRIMARY <- {
	"scout"    : 32	 //Scout
	"sniper"   : 25	 //Sniper
	"soldier"  : 20	 //Soldier
	"demo"     : 16	 //Demo
	"medic"    : 150 //Medic
	"heavy"    : 200 //Heavy
	"pyro"     : 200 //Pyro
	"spy"      : 20	 //Spy
	"engineer" : 32	 //Engineer
}

//Order based on internal constants of ETFClass
PopExtWeapons.TF_AMMO_PER_CLASS_SECONDARY <- {
	"scout"    : 36	 //Scout
	"sniper"   : 75	 //Sniper
	"soldier"  : 32	 //Soldier
	"demo"     : 24	 //Demo
	"medic"    : 150 //Medic
	"heavy"    : 32	 //Heavy
	"pyro" 	   : 32	 //Pyro
	"spy" 	   : 24	 //Spy
	"engineer" : 200 //Engineer
}

function PopExtWeapons::_OnDestroy() {

	foreach( key in [ "CustomWeapons", "ExtraItems" ] )
		if ( key in ROOT )
			delete ROOT[ key ]
}

// give item to specified player
// itemname accepts strings
// player accepts player entities
function PopExtWeapons::GiveItem( itemname, player ) {

	if ( !player || player.GetPlayerClass() < 1 ) return
	local playerclass = PopExtUtil.Classes[player.GetPlayerClass()]

	local extraitem = null
	local model = null
	local modelindex = null
	local animset = null
	local id = null
	local item_class = null
	local item_slot = null
	local original_itemname = "OriginalItemName" in ExtraItems[itemname] ? ExtraItems[itemname].OriginalItemName : itemname

	if ( itemname in ExtraItems )
		extraitem = ExtraItems[itemname]

	if ( original_itemname in PopExtItems ) {

		id = PopExtItems[original_itemname].id
		model = PopExtItems[original_itemname].model_player
		modelindex = PrecacheModel( model )
		animset = PopExtItems[original_itemname].animset
		item_class = PopExtItems[original_itemname].item_class
		item_slot = PopExtItems[original_itemname].item_slot

		if ( typeof PopExtItems[original_itemname].animset == "array" ) {

			if ( PopExtItems[original_itemname].animset.find( playerclass ) == null ) {

				animset = PopExtItems[original_itemname].animset[0]
				item_class = PopExtItems[original_itemname].item_class[0]
				item_slot = PopExtItems[original_itemname].item_slot[0]
			}
			else {

				animset = PopExtItems[original_itemname].animset[PopExtItems[original_itemname].animset.find( playerclass )]
				item_class = PopExtItems[original_itemname].item_class[PopExtItems[original_itemname].animset.find( playerclass )]
				item_slot = PopExtItems[original_itemname].item_slot[PopExtItems[original_itemname].animset.find( playerclass )]
			}
		}

		// multiclass items will not spawn unless they are specified for a certain class
		// this includes multiclass shotguns, melees, base jumper, pain train ( but not half zatoichi )
		// the stock pistol, tf_weapon_pistol is a valid classname and will spawn however tf_weapon_pistol_scout is also supported

		// animset can be a array or a string, arrays exist for weapons that are multi class ( shotgun pistol and all class melees )
		// if the current player's class is not one of the classes listed in the table, it will fall back to the first index
	}
	else return

	// replace overrides if they exist in extraitems
	if ( extraitem != null ) {

		if ( "ItemClass" in extraitem ) item_class = extraitem.ItemClass
		if ( "Model" in extraitem ) model = extraitem.Model; modelindex = PrecacheModel( model )
		if ( "AnimSet" in extraitem ) animset = extraitem.AnimSet
		if ( "Slot" in extraitem ) item_slot = extraitem.Slot
	}

	// create item entity
	local item = CreateByClassname( item_class )
	PopExtUtil.InitEconItem( item, id )
	item.SetTeam( player.GetTeam() )
	DispatchSpawn( item )
	local reserved_keywords = {
		"OriginalItemName" : null
		"ItemClass" : null
		"Name" : null
		"Model" : null
		"AnimSet" : null
		"Slot" : null
	}

	if ( !( "CustomWeapons" in player.GetScriptScope() ) )
		player.GetScriptScope().CustomWeapons <- {}

	player.GetScriptScope().CustomWeapons[item] <- {modelidx = modelindex, name = itemname, original_itemname = original_itemname}
	local scope = PopExtUtil.GetEntScope( item )

	//if max ammo needs to be changed, create a tf_wearable and assign attributes to it
	if ( item_slot == "primary" ) {

		if ( TF_AMMO_PER_CLASS_PRIMARY[playerclass] != TF_AMMO_PER_CLASS_PRIMARY[animset] ) {

			if ( !( "ammofix" in player.GetScriptScope().CustomWeapons ) ) {

				local ammofix = CreateByClassname( "tf_wearable" )
				SetPropBool( ammofix, STRING_NETPROP_INIT, true )
				SetPropBool( ammofix, STRING_NETPROP_ATTACH, true )
				PopExtUtil._SetOwner( ammofix, player )
				DispatchSpawn( ammofix )
				ammofix.AcceptInput( "SetParent", "!activator", player, player )
				player.GetScriptScope().CustomWeapons.ammofix <- ammofix

				if ( !( "ExtraLoadout" in player.GetScriptScope().Preserved ) ) {

					local ExtraLoadout = array( 10 )
					player.GetScriptScope().Preserved.ExtraLoadout <- ExtraLoadout
				}
				player.GetScriptScope().Preserved.ExtraLoadout.append( ammofix ) //for clean up
			}
			player.GetScriptScope().CustomWeapons.ammofix.AddAttribute( "hidden primary max ammo bonus", TF_AMMO_PER_CLASS_PRIMARY[animset].tofloat() / TF_AMMO_PER_CLASS_PRIMARY[playerclass].tofloat(), -1.0 )
			player.GetScriptScope().CustomWeapons.ammofix.ReapplyProvision()
			SetPropIntArray( player, STRING_NETPROP_AMMO, GetMaxAmmo( player, 1 ), 1 )
		}
	}

	if ( item_slot == "secondary" ) {

		if ( TF_AMMO_PER_CLASS_SECONDARY[playerclass] != TF_AMMO_PER_CLASS_SECONDARY[animset] ) {

			if ( !( "ammofix" in player.GetScriptScope().CustomWeapons ) ) {

				local ammofix = CreateByClassname( "tf_wearable" )
				SetPropBool( ammofix, STRING_NETPROP_INIT, true )
				SetPropBool( ammofix, STRING_NETPROP_ATTACH, true )
				PopExtUtil._SetOwner( ammofix, player )
				DispatchSpawn( ammofix )
				ammofix.AcceptInput( "SetParent", "!activator", player, player )
				player.GetScriptScope().CustomWeapons.ammofix <- ammofix
				if ( !( "ExtraLoadout" in player.GetScriptScope().Preserved ) ) {

					local ExtraLoadout = array( 10 )
					player.GetScriptScope().Preserved.ExtraLoadout <- ExtraLoadout
				}
				player.GetScriptScope().Preserved.ExtraLoadout.append( ammofix ) //for clean up
			}
			player.GetScriptScope().CustomWeapons.ammofix.AddAttribute( "hidden secondary max ammo penalty", TF_AMMO_PER_CLASS_SECONDARY[animset].tofloat() / TF_AMMO_PER_CLASS_SECONDARY[playerclass].tofloat(), -1.0 )
			player.GetScriptScope().CustomWeapons.ammofix.ReapplyProvision()
			SetPropIntArray( player, STRING_NETPROP_AMMO, GetMaxAmmo( player, 2 ), 2 )
		}
	}

	//adjust clip size
	item.SetClip1( item.GetMaxClip1() )

	//find the slot of the weapon then iterate through all entities parented to the player
	//and kill the entity that occupies the required slot
	local slot = FindSlot( item )
	if ( slot != null ) {

		local itemreplace = player.FirstMoveChild()
		while ( itemreplace ) {

			if ( FindSlot( itemreplace ) == slot ) {

				itemreplace.Kill()
				break
			}
			itemreplace = itemreplace.NextMovePeer()
		}
		player.Weapon_Equip( item )
		item.AcceptInput( "SetParent", "!activator", player, player )

		// Apply attributes
		// THIS MUST BE DONE AFTER WEAPON_EQUIP!!!
		// Normal attributes can work for owner-less items, custom attributes cannot.
		foreach ( attribute, value in extraitem || {} )
			if ( !( attribute in reserved_keywords ) )
				PopExtUtil.SetPlayerAttributes( player, attribute, value, item, true )

		// copied from ficool2 mw2_highrise
		// viewmodel
		local main_viewmodel = GetPropEntity( player, "m_hViewModel" )

		local armmodel = "models/weapons/c_models/c_" + animset + "_arms.mdl"

		//animset ? armmodel = animset : armmodel = main_viewmodel.GetModelName()

		item.SetModelSimple( armmodel )
		item.SetCustomViewModel( armmodel )
		item.SetCustomViewModelModelIndex( PrecacheModel( armmodel ) )
		SetPropInt( item, "m_iViewModelIndex", PrecacheModel( armmodel ) )

		local player_scope = PopExtUtil.GetEntScope( player )
		// worldmodel
		PopExtUtil.AddThink( player, UpdateWorldmodel )
		if ( !( "worldmodel" in player_scope.CustomWeapons ) ) {

			local tp_wearable = CreateByClassname( "tf_wearable" )
			SetPropInt( tp_wearable, STRING_NETPROP_MODELINDEX, modelindex )
			SetPropBool( tp_wearable, STRING_NETPROP_INIT, true )
			SetPropBool( tp_wearable, STRING_NETPROP_ATTACH, true )
			PopExtUtil._SetOwner( tp_wearable, player )
			DispatchSpawn( tp_wearable )

			tp_wearable.AcceptInput( "SetParent", "!activator", player, player )
			SetPropInt( tp_wearable, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL )
			player_scope.CustomWeapons.worldmodel <- tp_wearable
			if ( !( "ExtraLoadout" in player_scope.Preserved ) ) {

				local ExtraLoadout = array( 10 )
				player_scope.Preserved.ExtraLoadout <- ExtraLoadout
			}
			player_scope.Preserved.ExtraLoadout.append( tp_wearable ) //for clean up
		}

		// copied from LizardOfOz open fortress dm_crossfire
		// viewmodel arms
		SetPropInt( item, "m_nRenderMode", kRenderTransColor )
		SetPropInt( item, "m_clrRender", 1 )

		local hands = SpawnEntityFromTable( "tf_wearable_vm", {
			modelindex = PrecacheModel( format( "models/weapons/c_models/c_%s_arms.mdl", playerclass ) )
		})
		SetPropBool( hands, STRING_NETPROP_PURGESTRINGS, true )
		player.EquipWearableViewModel( hands )

		local hands2 = SpawnEntityFromTable( "tf_wearable_vm", {
			modelindex = PrecacheModel( model )
		})
		SetPropBool( hands2, STRING_NETPROP_PURGESTRINGS, true )
		player.EquipWearableViewModel( hands2 )

		SetPropEntity( hands2, "m_hWeaponAssociatedWith", item )
		SetPropEntity( item, "m_hExtraWearableViewModel", hands2 )

		// Doesn't work, needs entfire delay
		// player.Weapon_Switch( item )

		PopExtUtil.WeaponSwitchSlot( player, item.GetSlot() )
	}
	return item
}

//returns the slot number of entities with classname tf_weapon_
//also includes exceptions for passive weapons such as demo shields, soldier/demo boots and sniper backpacks
//action items includes canteen, contracker
//return null if the entity is not a weapon or passive weapon
function PopExtWeapons::FindSlot( item ) {

	if ( item.GetClassname().find( "tf_weapon_" ) == 0 )
		return item.GetSlot()
	else {

		//base jumper and invis watches are not included as they have classnames starting with "tf_weapon_"
		local id = GetPropInt( item, STRING_NETPROP_ITEMDEF )

		//Ali Baba's Wee Booties and Bootlegger
		if ( [405, 608].find( id ) != null ) return 0

		//Razorback, Gunboats, Darwin's Danger Shield, Mantreads, Cozy Camper
		else if ( [57, 133, 231, 444, 642].find( id ) != null ) return 1

		//All demo shields
		else if ( item.GetClassname() == "tf_wearable_demoshield" ) return 1

		//Action items, Canteens and Contracker
		else if ( ( item.GetClassname() == "tf_powerup_bottle"|| item.GetClassname() == "tf_wearable_campaign_item" ) ) return 5
	}
	return null
}

//equip item in player's loadout, does not give item
//itemname accepts strings
//player accepts player entities
//playerclass accepts integers, will default to player's current class if null, optional
function PopExtWeapons::EquipItem( itemname, player, playerclass = null ) {

	if ( playerclass == null ) playerclass = player.GetPlayerClass()

	if ( !( "ExtraLoadout" in player.GetScriptScope().Preserved ) ) {

		local ExtraLoadout = array( 10 )
		player.GetScriptScope().Preserved.ExtraLoadout <- ExtraLoadout
	}
	if ( player.GetScriptScope().Preserved.ExtraLoadout[playerclass] == null )
		player.GetScriptScope().Preserved.ExtraLoadout[playerclass] = []

	if ( player.GetScriptScope().Preserved.ExtraLoadout[playerclass].find( itemname ) == null )
		player.GetScriptScope().Preserved.ExtraLoadout[playerclass].append( itemname )
}

//unequip item in player's loadout
//itemname accepts strings
//player accepts player entities
//playerclass accepts integers, will default to player's current class if null, optional
function PopExtWeapons::UnequipItem( itemname, player, playerclass = null ) {

	if ( playerclass == null ) playerclass = player.GetPlayerClass()

	if ( "ExtraLoadout" in player.GetScriptScope().Preserved )
		if ( player.GetScriptScope().Preserved.ExtraLoadout[playerclass] != null )
			if ( player.GetScriptScope().Preserved.ExtraLoadout[playerclass].find( itemname ) != null )
				player.GetScriptScope().Preserved.ExtraLoadout[playerclass].remove( player.GetScriptScope().Preserved.ExtraLoadout[playerclass].find( itemname ) )

}

//think function that runs on players to update viewmodels
//runs every tick
function PopExtWeapons::UpdateWorldmodel() {

	local scope = PopExtUtil.GetEntScope( self )

	if ( "CustomWeapons" in scope ) {

		local activeweapon = self.GetActiveWeapon()

		if ( activeweapon in scope.CustomWeapons && "worldmodel" in scope.CustomWeapons ) {

			if ( ( GetPropInt( scope.CustomWeapons.worldmodel, STRING_NETPROP_MODELINDEX ) != scope.CustomWeapons[activeweapon].modelidx ) ) {

				if ( scope.CustomWeapons.worldmodel.IsValid() )
					scope.CustomWeapons.worldmodel.Kill()

				local modelindex = scope.CustomWeapons[activeweapon].modelidx
				local tp_wearable = CreateByClassname( "tf_wearable" )
				SetPropInt( tp_wearable, "m_iTeamNum", self.GetTeam() )
				SetPropInt( tp_wearable, STRING_NETPROP_MODELINDEX, modelindex )
				SetPropBool( tp_wearable, STRING_NETPROP_INIT, true )
				SetPropBool( tp_wearable, STRING_NETPROP_ATTACH, true )
				tp_wearable.SetSkin( self.GetTeam() - 2 )
				PopExtUtil._SetOwner( tp_wearable, self )
				DispatchSpawn( tp_wearable )
				tp_wearable.AcceptInput( "SetParent", "!activator", self, self )
				SetPropInt( tp_wearable, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL )
				scope.CustomWeapons.worldmodel <- tp_wearable
				if ( !( "ExtraLoadout" in scope.Preserved ) ) {

					local ExtraLoadout = array( 10 )
					scope.Preserved.ExtraLoadout <- ExtraLoadout
				}
				scope.Preserved.ExtraLoadout.append( tp_wearable ) //for clean up
			}
		}
		else if ( scope.CustomWeapons.worldmodel.IsValid() )
			scope.CustomWeapons.worldmodel.Kill()
	}
	return -1
}

//returns max ammo of player by slot after attributes
//player accepts player entities
//slot accepts integers 1 to 4
function PopExtWeapons::GetMaxAmmo( player, slot ) {

	local multiplier = 1
	local attributearray = []
	local slottable = null
	switch( slot ) {
		case 1: //primary ammo
			attributearray = ["hidden primary max ammo bonus", "maxammo primary increased", "maxammo primary reduced"]
			slottable = TF_AMMO_PER_CLASS_PRIMARY
			break
		case 2: //secondary ammo
			attributearray = ["hidden secondary max ammo penalty", "maxammo secondary increased", "maxammo secondary reduced"]
			slottable = TF_AMMO_PER_CLASS_SECONDARY
			break
		case 3: //metal
			attributearray = ["maxammo metal increased", "maxammo metal reduced"]
			break
		case 4: //grenades1 ammo ( sandman, wrap assassin, jarate, heavy lunchbox )
			attributearray = ["maxammo grenades1 increased"]
			break
		case 5: //grenades2 ammo ( mad milk, bonk )
			return
		case 6: //grenades3 ammo ( spellbook )
			return
		default:
			return
	}

	foreach ( attribute in attributearray ) {

		multiplier = multiplier * player.GetCustomAttribute( attribute, 1 )
	}

	local item = player.FirstMoveChild()
	while ( item && item instanceof CEconEntity ) {

		foreach ( attribute in attributearray ) {

			multiplier = multiplier * item.GetAttribute( attribute, 1 )
		}
		item = item.NextMovePeer()
	}

	if ( slot == 3 ) {

		player.GetPlayerClass() == 9 ? slottable = 200 : slottable = 100
		return multiplier * slottable
	}
	if ( slot == 4 ) return multiplier * 1

	return multiplier * slottable[PopExtUtil.Classes[player.GetPlayerClass()]]
}

//regenerating players by default will clear custom weapons
//give all weapons in the player's class's extraloadout and set hp
POP_EVENT_HOOK("post_inventory_application", "RegenerateCustomWeapons", function( params ) {

	local player = GetPlayerFromUserID( params.userid )

	if ( player.IsEFlagSet( EFL_CUSTOM_WEARABLE ) )
		return

	if ( ( "ExtraLoadout" in player.GetScriptScope().Preserved ) ) {

		if ( player.GetScriptScope().Preserved.ExtraLoadout.len() > 10 ) {

			foreach ( entity in player.GetScriptScope().Preserved.ExtraLoadout ) {

				if ( ( typeof entity == "instance" ) && entity.IsValid() )
				entity.Kill()
			}
			player.GetScriptScope().Preserved.ExtraLoadout.resize( 10 )
		}
		local playerclass = player.GetPlayerClass()

		if ( player.GetScriptScope().Preserved.ExtraLoadout[playerclass] != null )
			foreach ( item in player.GetScriptScope().Preserved.ExtraLoadout[playerclass] )
				PopExtWeapons.GiveItem( item, player )

		player.SetHealth( player.GetMaxHealth() )

		SetPropIntArray( player, STRING_NETPROP_AMMO, PopExtWeapons.GetMaxAmmo( player, 1 ), 1 )
		SetPropIntArray( player, STRING_NETPROP_AMMO, PopExtWeapons.GetMaxAmmo( player, 2 ), 2 )
		SetPropIntArray( player, STRING_NETPROP_AMMO, PopExtWeapons.GetMaxAmmo( player, 3 ), 3 )
		SetPropIntArray( player, STRING_NETPROP_AMMO, PopExtWeapons.GetMaxAmmo( player, 4 ), 4 )
	}
}, EVENT_WRAPPER_CUSTOMWEP)

// TODO: deprecate the old namespace
::CustomWeapons <- PopExtWeapons


//ExtraItems <-	// Example, make your own script and use ::ExtraItems to set up custom weapon list
//{
//	"Wasp Launcher" :
//	{
//        OriginalItemName = "Upgradeable TF_WEAPON_ROCKETLAUNCHER"
//        Model = "models/weapons/c_models/c_wasp_launcher/c_wasp_launcher.mdl"
//        "blast radius increased" : 1.5
//        "max health additive bonus" : 100
//	}
//	"Thumper" :
//	{
//        OriginalItemName = "Upgradeable TF_WEAPON_SHOTGUN_PRIMARY"
//        Model = "models/weapons/c_models/c_rapidfire/c_rapidfire_1.mdl"
//		//defaults to engineer's primary shotgun, need to specify
//		//ItemClass and Animset to use secondary shotgun on non shotgun wielding classes
//		//specify Slot to make sure the reserve ammo fix is applied properly
//		ItemClass = "tf_weapon_shotgun_soldier"
//        AnimSet = "soldier"
//		Slot = "secondary"
//        "damage bonus" : 2.3
//        "clip size bonus" : 1.25
//        "weapon spread bonus" : 0.85
//        "maxammo secondary increased" : 1.5
//        "fire rate penalty" : 1.2
//        "bullets per shot bonus" : 0.5
//        "Reload time increased" : 1.13
//        "single wep deploy time increased" : 1.15
//        "minicritboost on kill" : 5
//	}
//	"Crowbar" :
//	{
//        OriginalItemName = "Necro Smasher"
//        Model = "models/weapons/c_models/c_cratesmasher/c_cratesmasher_1.mdl"
//		"deploy time decreased" : 0.75
//		"fire rate bonus" : 0.30
//		"damage penalty" : 0.54
//	}
//}