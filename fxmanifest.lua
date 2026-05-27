fx_version 'cerulean'
game 'gta5'

author 'AttackDefend'
description 'Attack & Defend - QBCore'
version '2.0.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
    'client/spectate.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

lua54 'yes'
