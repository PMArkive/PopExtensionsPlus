import datetime
import os
import typing
# TODO: This PyPI module is not properly VDF-compliant, but will suffice until I
#        finish writing a better one.
import vdf

# == CONSTANTS ==
# TODO: These would do well as CLI args.
LOCALE: typing.Final[str] = 'english'
 # Max depth is relatively low as there shouldn't be too many references in prefabs
MAX_RECURSION_DEPTH: typing.Final[str] = 50
OUTPUT_TABLE_NAME: typing.Final[str] = 'PopExtItems'
OUTPUT_DIR: typing.Final[str] = f'{os.path.dirname(__file__)}/output'
OUTPUT_FILE_NAME: typing.Final[str] = 'item_map.nut'

# TODO: Path hardcoded currently for win32, but can be detected easily from libraryfolders.vdf.
tf_path = f'{os.environ['ProgramFiles(x86)']}/Steam/steamapps/common/Team Fortress 2/tf'

# == FUNCTIONS ==
def schema_block_from_prefabs(prefabs: dict, block: dict, _depth: int = 0) -> dict:
    """
    Recursively builds a full schema block from a partial block containing "prefab" keys.

    :param prefabs (dict): The dictionary containing the prefab data.
    :param block (dict): The name of the item to find the item class for.
    :param depth (int, optional): Internal use tracker of current recursion depth.
    :return (dict): Block containing all merged prefab information.
    """

    if _depth > MAX_RECURSION_DEPTH:
        raise RecursionError('Maximum recursion depth exceeded when searching for prefabs.')

    # Look for "prefab" in current block.
    try:
        prefab_refs = block['prefab'].split()
    # Could not find "prefab" key, merge is complete. Early return.
    except KeyError:
        return block

    # Merge prefab reference keys to block.
    for prefab in prefab_refs:
        prefab_block = schema_block_from_prefabs(prefabs, prefabs[prefab], _depth + 1)
        # Prioritise original block values.
        block = {**prefab_block, **block}

    block.pop('prefab', None)
    return block

def ItemMap_to_squirrel(tablename: str, inputdict: dict, indent: str = '    ', globalscope: bool = True) -> list:
    """
    Converts an ItemMap dict to the string representation of a Squirrel table.

    Note that this function is not suited for wider use outside of TFItemMap as it does not use recursion,
        given that it was designed to handle a dict case where it was unclear if a table slot should be a variable
        or a string.

    This function will Soon™ be deprecated in favour of declaring a derived class of str to identify
        when a variable should be printed.

    :param tablename (str): Name of the Squirrel table.
    :param inputdict (dict): Target dict to convert.
    :param indent (int, optional): Indentation level to use, default = 4 spaces.
    :param globalscope (bool, optional): Create table in the global scope, default = True.
    :return (str): String representation of the converted Squirrel table.
    """

    generation_time = datetime.datetime.now(datetime.timezone.utc)
    _outputlist = ['// TFItemMap generated on ' + generation_time.strftime('%H:%M %Y/%m/%d UTC')]

    if globalscope:
        _outputlist.append(f'::{tablename} <- {{')
    else:
        _outputlist.append(f'local {tablename} = {{')

    lastitem_i = list(inputdict)[-1]
    for key, value in inputdict.items():
        _outputlist.append(f'{indent}\"{key}\" : {{')
        lastitem_j = list(value)[-1]
        for k, v in value.items():
            try:
                val = int(v) if type(v) != dict else v
                str = f"{indent*2}{k} = {val}".replace("'", '"') if type(v) == dict else f"{indent*2}{k} = {val}"
                _outputlist.append(str)
            except ValueError:
                # Hack, some locstrings contain an actual newline which Squirrel really enjoys
                _outputlist.append(f"{indent*2}{k} = \"{v.replace('\n', '\\n')}\"")
            if k != lastitem_j:
                _outputlist[-1] += ','
        _outputlist.append(f'{indent}}}')
        if key != lastitem_i:
            _outputlist[-1] += ','
    _outputlist.append("}\n")

#	print(_outputlist)
    return '\n'.join(_outputlist)
	# return '\n'.join(_outputlist)
# == SCRIPT ==
if __name__ == "__main__":
    # GPL says you're supposed to do this or something
    print("""
        TFItemMap Generator by fellen.  
            https://github.com/mtxfellen/
        Modified by Braindawg.
            https://github.com/Brain-dawg/
        Used for PopExtensionsPlus.
            https://github.com/potato-tf/PopExtensionsPlus
    """)

    print('Reading items_game.txt...')
    path_to_schema = os.path.abspath(f'{tf_path}/scripts/items/items_game.txt')
    with open(path_to_schema, 'r') as fp:
        items_game = vdf.parse(fp)
    print(f'Reading tf_{LOCALE}.txt...')
    path_to_loc_file = os.path.abspath(f'{tf_path}/resource/tf_{LOCALE}.txt')
    with open(path_to_loc_file, 'r', encoding='utf-16-le') as fp:
        locfile = vdf.parse(fp)

    # TODO: Should .lower() items_game keys, though doesn't matter for now since it's likely
    #        a generated file.
    items = items_game['items_game']['items']
    prefabs = items_game['items_game']['prefabs']
    attributes = items_game['items_game']['attributes']
    del items_game  # Free some memory, item schema is fat.
    # Sort "items" entries by index numerically ascending
    items = {'default': items.pop('default'), **dict(sorted(items.items(), key=lambda item: int(item[0])))}

    # Temporary: Locfile is .lower()ed as VDF is not case-sensitive.
    #            .casefold() would be the correct way of handling this, but VDF does not use
    #              an equivalent method (probably).
    locfile = locfile['lang']['Tokens']
    locfile = {k.lower(): v for k, v in locfile.items()}

    items_dict = {}

    print('Parsing data from items_game.txt...')
    itemmap_filter = {
        'name':                     'LOCALIZED',
        'item_description':         'LOCALIZED',
        'item_class':               'item_class',
        'item_slot':                'item_slot',
        'prefab' :                  'prefab',
        'baseitem':                 'baseitem',
        'item_iconname':            'item_iconname',
        'base_item_name':           'base_item_name',
        'anim_slot':                'anim_slot',

        'model_player':            'model_player',
        'model_player_per_class':  'model_player_per_class',
        'model_world':             'model_world',
        'equip_region':            'equip_region',
        'extra_wearable':          'extra_wearable',
        'extra_wearable_vm':       'extra_wearable_vm',
        'min_ilevel':              'min_ilevel',
        'max_ilevel':              'max_ilevel',
        'item_quality':            'item_quality',
        'flip_viewmodel':          'flip_viewmodel',
        'attach_to_hands':         'attach_to_hands',
        'attach_to_hands_vm_only': 'attach_to_hands_vm_only',
        'act_as_wearable':         'act_as_wearable',

        'first_sale_date':         'first_sale_date',
        'holiday_restriction':     'holiday_restriction',
        'vision_filter_flags':     'vision_filter_flags',
        'item_type_name':          'LOCALIZED',
        'xifier_class_remap':      'xifier_class_remap',
        'propername':              'propername',
        'item_rarity':             'item_rarity',
        'propername':              'propername',
        'visuals':                 'visuals',
        'used_by_classes':         'used_by_classes',

    }
    for key, value in items.items():
        value = schema_block_from_prefabs(prefabs, value)

        # Set key name to "name".
        items_dict[value['name']] = {}
        # Set 'id' to item index.
        items_dict[value['name']]['id'] = key
        # Set 'item_class' to "item_class".

        for k, v in value.items():
            if (k in itemmap_filter):
                try:
                    items_dict[value['name']][k] = v if itemmap_filter[k] != 'LOCALIZED' else locfile[v[1:].lower()]

                    if (r'"' in items_dict[value['name']][k]):
                        items_dict[value['name']][k] = items_dict[value['name']][k].replace(r'"', r"'")
                except KeyError:
                    items_dict[value['name']][k] = ''

    full_output_path = os.path.abspath(f'{OUTPUT_DIR}/{OUTPUT_FILE_NAME}')
    print(f'Writing to \'{full_output_path}\'... ', end='', flush=True)

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
    with open(full_output_path, mode='wt', encoding='utf-8', newline='\n') as fp:
        fp.write(ItemMap_to_squirrel(OUTPUT_TABLE_NAME, items_dict))
    print('Done.')

    raise SystemExit
