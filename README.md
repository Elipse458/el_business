# el_business
Business system for FiveM (ESX)  
Buy a business, order stock and get money every irl hour!
You can have employees, which get a cut from the income based on a formula that can be edited in the config. They can also buy stock for you (with their own money).  

## Installation
1. Download the [resource](https://github.com/Elipse458/el_business/archive/master.zip)
2. Put it into your resources folder
3. Import sql.sql into your database
4. Edit the config to your liking
5. Add `start el_business` to your server.cfg ***Make sure to add this after mysql-async and es_extended***
6. Start it and you're good to go

## Documentation
Commands:
- /business <- root admin command, shows possible sub-commands - **make sure you have superadmin**
- /business create <- admin command, allows you to create a business in your current location
- /business list <- admin command, dumps list of current businesses into your console
- /business reload <- admin command, reloads business data from database

## Important notes
**DO NOT RESTART THIS** - it requires a full server restart!  
If you want to change the time when people receive money (default is every hour at :00) here's how you do it:  
- Open `server.lua` and go to line 201
- Change the '0' in `TriggerEvent("cron:runAt",i, *0* ,runMoneyCoroutines)` to a number between 0-59, that will be the minute when it gets executed  
If you want to change the hours, i'll let you figure that out on your own as an exercise lol ([cron](https://github.com/ESX-Org/cron))
- If the script doesn't give money to the player, try changing [line 40](https://github.com/Elipse458/el_business/blob/master/server.lua#L40) in server.lua to `xPlayer.addMoney(math.floor(money))`

If find any bugs, please join my [discord server](https://discord.gg/GbT49uH) and report it in the #bug-reports channel  
If you like my work, please check out [my page](https://elipse458.me), i'll probably release a few more things if i have the time and feel like it
