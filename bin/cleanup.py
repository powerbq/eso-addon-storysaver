#!/usr/bin/python3

import os
import sys
import time

import lupa


def export(lua_table, level=0):
    result = '' if level > 0 else 'StorySaverSavedVariables =\n'

    prefix = ''
    for _ in range(level):
        prefix += '\t'

    result += prefix + '{\n'

    for key in lua_table:
        value = lua_table[key]
        if type(key) is str:
            key = '"' + key + '"'
        elif type(key) is int:
            pass
        else:
            raise Exception('Unexpected key type: %s' % type(key))

        header = prefix + '\t' '[' + str(key) + '] = '
        if type(value) is str:
            result += header + '"' + value.replace('\r', '\\r').replace('\n', '\\n') + '",\n'
        elif type(value) is int:
            result += header + str(value) + ',\n'
        elif type(value) is float:
            result += header + str('%.10f' % value) + ',\n'
        elif type(value) is bool:
            result += header + ('true' if value else 'false') + ',\n'
        else:
            result += header + '\n'
            result += export(value, level + 1)

    result += prefix + '}' + (',' if level > 0 else '') + '\n'

    return result


if __name__ == '__main__':
    start_time = time.time()
    file_path = os.path.abspath(sys.executable if getattr(sys, 'frozen', False) else __file__)
    file_directory = os.path.dirname(file_path)
    new_directory = file_directory + '/../../../SavedVariables'

    try:
        if not os.path.exists(new_directory):
            raise Exception('SavedVariables folder not found')

        os.chdir(new_directory)

        if not os.path.exists('StorySaver.lua'):
            raise Exception('StorySaver.lua file not found')

        with open('StorySaver.lua', 'rb') as f:
            content = f.read()

        text = content.decode('utf-8').replace('\r', '').strip()
        text += '\nreturn StorySaverSavedVariables\n'

        lua = lupa.LuaRuntime()

        data = lua.execute(text)

        realm_1 = 'Default'
        character_1 = '$AccountWide'

        if realm_1 not in data:
            raise Exception('No cache found')

        for account_1 in data[realm_1]:
            for category_1 in data[realm_1][account_1][character_1]:
                if category_1 == 'version':
                    continue

                for name_1 in data[realm_1][account_1][character_1][category_1]:
                    for hash_1 in data[realm_1][account_1][character_1][category_1][name_1]:
                        body = data[realm_1][account_1][character_1][category_1][name_1][hash_1]
                        found = False
                        for realm_2 in data:
                            if realm_2 == realm_1:
                                continue

                            for account_2 in data[realm_2]:
                                if account_2 != account_1:
                                    continue

                                for character_2 in data[realm_2][account_2]:
                                    if character_2 == character_1:
                                        continue

                                    for category_2 in data[realm_2][account_2][character_2]:
                                        if category_2 != category_1:
                                            continue

                                        for name_2 in data[realm_2][account_2][character_2][category_2]:
                                            if name_2 != name_1:
                                                continue

                                            for event_2 in data[realm_2][account_2][character_2][category_2][name_2]:
                                                hash_2 = data[realm_2][account_2][character_2][category_2][name_2][event_2]['hash']
                                                if hash_2 == hash_1:
                                                    found = True

                                                if 'selectedOptionHash' in data[realm_2][account_2][character_2][category_2][name_2][event_2]:
                                                    selected_option_hash = data[realm_2][account_2][character_2][category_2][name_2][event_2]['selectedOptionHash']
                                                    if selected_option_hash == hash_1:
                                                        found = True

                                                if 'optionHashes' in data[realm_2][account_2][character_2][category_2][name_2][event_2]:
                                                    for i, option_hash in data[realm_2][account_2][character_2][category_2][name_2][event_2]['optionHashes'].items():
                                                        if option_hash == hash_1:
                                                            found = True

                        if not found:
                            print('Removing', account_1, category_1, name_1, hash_1, 'from cache')
                            del data[realm_1][account_1][character_1][category_1][name_1][hash_1]

                            i = 0
                            for _ in data[realm_1][account_1][character_1][category_1][name_1]:
                                i += 1
                            if i == 0:
                                print('Removing', account_1, category_1, name_1, 'from cache')
                                del data[realm_1][account_1][character_1][category_1][name_1]

        with open('StorySaver.lua', 'wb') as f:
            f.write(export(data).replace('\n', '\r\n').replace('\t', '    ').encode('utf-8'))

        print(' * Done - %.2fs' % (time.time() - start_time))

    except Exception as e:
        print(' * Error: %s - %.2fs' % (e, time.time() - start_time))

    time.sleep(5)
