::PopExtWavebar <- {
    
    netprop_classnames = "m_iszMannVsMachineWaveClassNames"
    netprop_flags      = "m_nMannVsMachineWaveClassFlags"
    netprop_counts     = "m_nMannVsMachineWaveClassCounts"
    netprop_active     = "m_bMannVsMachineWaveClassActive"
    netprop_enemycount = "m_nMannVsMachineWaveEnemyCount"

    function _PopIncrementTankIcon( icon ) {

        local flags = MVM_CLASS_FLAG_NORMAL
        if ( icon.is_crit ) {
            flags = flags | MVM_CLASS_FLAG_ALWAYSCRIT
        }
        if ( icon.is_boss ) {
            flags = flags | MVM_CLASS_FLAG_MINIBOSS
        }
        if ( icon.is_support ) {
            flags = flags | MVM_CLASS_FLAG_SUPPORT
        }
        if ( icon.is_support_limited ) {
            flags = flags | MVM_CLASS_FLAG_SUPPORT_LIMITED
        }

        PopExt.DecrementWaveIconSpawnCount( "tank", MVM_CLASS_FLAG_NORMAL | MVM_CLASS_FLAG_MINIBOSS | ( icon.is_support ? MVM_CLASS_FLAG_SUPPORT : 0 ) | ( icon.is_support_limited ? MVM_CLASS_FLAG_SUPPORT_LIMITED : 0 ), icon.count, false )
        PopExt.IncrementWaveIconSpawnCount( icon.name, flags, icon.count, false )
    }

    function _PopIncrementIcon( icon ) {

        local flags = MVM_CLASS_FLAG_NORMAL
        if ( icon.is_crit ) {
            flags = flags | MVM_CLASS_FLAG_ALWAYSCRIT
        }
        if ( icon.is_boss ) {
            flags = flags | MVM_CLASS_FLAG_MINIBOSS
        }
        if ( icon.is_support ) {
            flags = flags | MVM_CLASS_FLAG_SUPPORT
        }
        if ( icon.is_support_limited ) {
            flags = flags | MVM_CLASS_FLAG_SUPPORT_LIMITED
        }

        PopExt.IncrementWaveIconSpawnCount( icon.name, flags, icon.count, true )
    }

    function AddCustomTankIcon( name, count, is_crit = false, is_boss = true, is_support = false, is_support_limited = false ) {

        local icon = {
            name      = name
            count     = count
            is_crit    = is_crit
            is_boss    = is_boss
            is_support = is_support
            is_support_limited = is_support_limited
        }
        PopExtHooks.tank_icons.append( icon )
        PopExt._PopIncrementTankIcon( icon )
    }

    function AddCustomIcon( name, count, is_crit = false, is_boss = false, is_support = false, is_support_limited = false ) {

        local icon = {
            name      = name
            count     = count
            is_crit    = is_crit
            is_boss    = is_boss
            is_support = is_support
            is_support_limited = is_support_limited
        }
        PopExtHooks.icons.append( icon )
        PopExt._PopIncrementIcon( icon )
    }

    function SetWaveIconsFunction( func ) {
        PopExt.wave_icons_function <- func
        func()
    }

    local resource = FindByClassname( null, "tf_objective_resource" )

    // Get wavebar spawn count of an icon with specified name and flags
    function GetWaveIconSpawnCount( name, flags ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array * 2; i++ ) {

                if ( GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i ) == name && ( flags == MVM_CLASS_FLAG_NONE || GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i ) == flags ) ) {

                    return GetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), i )
                }
            }
        }
        return 0
    }

    // Set wavebar spawn count of an icon with specified name and flags
    // If count is set to 0, removes the icon from the wavebar
    // Can be used to put custom icons on a wavebar
    // if flags or count are null they will retain their current values
    function SetWaveIconSpawnCount( name, flags, count, change_max_enemy_count = true ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )
                local count_slot = GetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), i )
                local flags_slot = GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i )
                local enemy_count = GetPropInt( resource, "m_nMannVsMachineWaveEnemyCount" )

                if ( count == null ) count = count_slot
                if ( flags == null ) flags = flags_slot

                if ( name_slot == "" && count > 0 ) {

                    SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), name, i )
                    SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), count, i )
                    SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), flags, i )

                    if ( change_max_enemy_count && ( flags & ( MVM_CLASS_FLAG_NORMAL | MVM_CLASS_FLAG_MINIBOSS ) ) ) {

                        SetPropInt( resource, "m_nMannVsMachineWaveEnemyCount", enemy_count + count )
                    }
                    return
                }

                if ( name_slot == name && ( flags == MVM_CLASS_FLAG_NONE || flags_slot == flags ) ) {

                    local pre_count = count_slot
                    SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), count, i )

                    if ( change_max_enemy_count && ( flags & ( MVM_CLASS_FLAG_NORMAL | MVM_CLASS_FLAG_MINIBOSS ) ) ) {

                        SetPropInt( resource, "m_nMannVsMachineWaveEnemyCount", enemy_count + count - pre_count )
                    }
                    if ( count <= 0 ) {

                        SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), "", i )
                        SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), 0, i )
                        SetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), false, i )
                    }
                    return
                }
            }
        }
    }

    // Replace/update a specific icon on the wavebar
    // index override can be used to preserve wavebar order
    // more robust version of the above function
    // setting incrementer to true will add/subtract the current count instead of replacing it
    function SetWaveIconSlot( name, slot = null, flags = null, count = null, index_override = -1, incrementer = false, change_max_enemy_count = true ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            local indices = {}

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )
                local flags_slot = GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i )
                local count_slot = GetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), i )
                local enemy_count = GetPropInt( resource, netprop_enemycount )

                if ( count == null ) count = count_slot
                if ( flags == null ) flags = flags_slot

                if ( index_override != -1 ) {

                    indices[i] <- [name_slot, flags_slot, count_slot, false]
                    if ( flags_slot & MVM_CLASS_FLAG_MISSION )
                        indices[i][3] = true
                }

                if ( name_slot == name && ( flags == MVM_CLASS_FLAG_NONE || flags_slot == flags ) ) {

                    local pre_count = count_slot

                    if ( count == 0 ) {

                        SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), "", i )
                        SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), 0, i )
                        SetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), false, i )

                        if ( change_max_enemy_count )
                            SetPropInt( resource, netprop_enemycount, enemy_count - pre_count )

                        return
                    }

                    else if ( incrementer ) {

                        count = count_slot + count
                        SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), count, i )

                        if ( count_slot <= 0 ) {
                            SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), "", i )
                            SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), 0, i )
                            SetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), false, i )
                        }
                        return
                    }

                    if ( index_override != -1 ) {

                        SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), indices[i][0], i )
                        SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), indices[i][1], i )
                        SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), indices[i][2], i )
                        SetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), indices[i][3], i )

                        SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), 0, i )
                        SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), "", i )
                        SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), 0, i )
                    }

                    SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), count, index_override )
                    SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), slot, index_override )
                    SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), flags, index_override )

                    if ( change_max_enemy_count && ( flags & ( MVM_CLASS_FLAG_NORMAL | MVM_CLASS_FLAG_MINIBOSS ) ) )
                        SetPropInt( resource, netprop_enemycount, GetPropInt( resource, netprop_enemycount ) + count - pre_count )
                    return
                }
            }
        }
    }
    function GetWaveIconSlot( name, flags ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )
                local flags_slot = GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i )

                if ( name_slot == name && flags_slot == flags ) {
                    return i
                }
            }
        }
        return -1
    }
    function GetAllWaveIconSlots( name, flags ) {

        local size_array = GetPropArraySize( resource, netprop_counts )
        local slots = []
        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )
                local flags_slot = GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i )

                if ( name_slot == name && ( flags == MVM_CLASS_FLAG_NONE || flags_slot == flags ) ) {
                    slots.append( i )
                }
            }
        }
        return slots
    }
    // Increment wavebar spawn count of an icon with specified name and flags
    // Can be used to put custom icons on a wavebar
    function IncrementWaveIconSpawnCount( name, flags, count = 1, change_max_enemy_count = true ) {
        PopExt.SetWaveIconSpawnCount( name, flags, PopExt.GetWaveIconSpawnCount( name, flags ) + count, change_max_enemy_count )
        return 0
    }

    function GetWaveIconFlags( name ) {

        local size_array = GetPropArraySize( resource, netprop_counts )
        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )

                if ( name_slot == name )
                    return GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i )
            }
        }
        return 0
    }

    function GetAllWaveIconFlags( name ) {

        local size_array = GetPropArraySize( resource, netprop_counts )
        local flags = []
        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )

                if ( name_slot == name )
                    flags.append( GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i ) )
            }
        }
        return flags
    }

    function SetWaveIconFlags( name, flags ) {

        local size_array = GetPropArraySize( resource, netprop_counts )
        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )

                if ( name_slot == name )
                    SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), flags, i )
            }
        }
    }

    // Increment wavebar spawn count of an icon with specified name and flags
    // Use it to decrement the spawn count when the enemy is killed. Should not be used for support type icons
    function DecrementWaveIconSpawnCount( name, flags, count = 1, change_max_enemy_count = false ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )

                if ( name_slot == name && ( flags == MVM_CLASS_FLAG_NONE || GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i ) == flags ) ) {

                    local pre_count = GetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), i )

                    SetPropIntArray( resource, format( "%s%s", netprop_counts, suffix ), pre_count - count > 0 ? pre_count - count : 0, i )

                    if ( change_max_enemy_count && ( flags & ( MVM_CLASS_FLAG_NORMAL | MVM_CLASS_FLAG_MINIBOSS ) ) ) {

                        SetPropInt( resource, "m_nMannVsMachineWaveEnemyCount", GetPropInt( resource, "m_nMannVsMachineWaveEnemyCount" ) - ( count > pre_count ? pre_count : count ) )
                    }

                    if ( pre_count - count <= 0 ) {

                        SetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), "", i )
                        SetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), 0, i )
                        SetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), false, i )
                    }
                    return
                }
            }
        }
        return 0
    }

    // Used for mission and support limited bots to display them on a wavebar during the wave, set by the game automatically when an enemy with this icon spawn
    function SetWaveIconActive( name, flags, active ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )

                if ( name_slot == name && ( flags == MVM_CLASS_FLAG_NONE || GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i ) == flags ) ) {

                    SetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), active, i )
                    return
                }
            }
        }
    }

    // Used for mission and support limited bots to display them on a wavebar during the wave, set by the game automatically when an enemy with this icon spawn
    function GetWaveIconActive( name, flags ) {

        local size_array = GetPropArraySize( resource, netprop_counts )

        for ( local a = 0; a < 2; a++ ) {

            local suffix = a == 0 ? "" : "2"

            for ( local i = 0; i < size_array; i++ ) {

                local name_slot = GetPropStringArray( resource, format( "%s%s", netprop_classnames, suffix ), i )

                if ( name_slot == name && ( flags == MVM_CLASS_FLAG_NONE || GetPropIntArray( resource, format( "%s%s", netprop_flags, suffix ), i ) == flags ) ) {

                    return GetPropBoolArray( resource, format( "%s%s", netprop_active, suffix ), i )
                }
            }
        }
        return false
    }
}
