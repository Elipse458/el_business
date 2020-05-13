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

## Translations
If you want to change your locale from `en` to some of the pre-made ones, here's how to do it
- Change locale in config.lua to the desired one
- Change line 6 and 12 in \_\_resource.lua your locale's filename (for example `locale/sk.lua`)
- Start it and it should work (if not, restart your server)  

Translators:  
@Elipse458 - SK (Slovak), CZ (Czech)  
@NiT34ByTe - IT (Italian), RO (Romanian)  
@NessFrg - BR (Brazilian)  
@iSiKoZ - FR (French)  
@CuPi - PL (Polish)  
@Marfru - ES (Spanish)  
If you want to submit your own translation, make a pull request or shoot me a DM on discord!

## Important notes
**DO NOT RESTART THIS** - it requires a full server restart!  
If you want to change the time when people receive money (default is every hour at :00) here's how you do it:  
- Open `server.lua` and go to [line 299](https://github.com/Elipse458/el_business/blob/master/server.lua#L299)
- Change the '0' in `TriggerEvent("cron:runAt",i, *0* ,runMoneyCoroutines)` to a number between 0-59, that will be the minute when it gets executed  
If you want to change the hours, i'll let you figure that out on your own as an exercise lol ([cron](https://github.com/ESX-Org/cron))
- If the script doesn't give money to the player, try changing [line 194](https://github.com/Elipse458/el_business/blob/master/server.lua#L194) in server.lua to `xPlayer.addMoney(math.floor(money))`  

If you have someone in the businesses set as an owner of a business and their identifier is no longer in the users database, you need to set the owner of that business back to NULL. Here's a sql query that can do all of that automagically (might take longer with big users table)
```sql
UPDATE businesses SET owner=NULL WHERE owner IS NOT NULL AND NOT EXISTS (SELECT 1 FROM users WHERE businesses.owner = users.identifier)
```  

If find any bugs, please join my [discord server](https://discord.gg/GbT49uH) and report it in the #bug-reports channel  
If you like my work, please check out [my page](https://elipse458.me), i'll probably release a few more things if i have the time and feel like it
