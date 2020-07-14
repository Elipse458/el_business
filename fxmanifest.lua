fx_version 'adamant'

game 'gta5'

description 'ESX Businesses'

version '1.2.0'

client_scripts {
    "config.lua",
    "client.lua",
    "locale/en.lua"
}
server_scripts {
    "@mysql-async/lib/MySQL.lua",
	"config.lua",
    "server.lua",
    "locale/en.lua"
}

dependencies {
    "es_extended",
    "cron"
}