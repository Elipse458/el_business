ESX = nil
local dataCache,namecache = {},{}

TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj

    ESX.RegisterServerCallback("el_business:getNewEmployeeList",function(source,cb,business)
        local players = {}
        for k,v in ipairs(ESX.GetPlayers()) do
            local xTarget = ESX.GetPlayerFromId(v)
            if v~=source and GetPlayerName(v)~=nil and not isBusinessEmployee(dataCache[business]["employees"],xTarget.identifier) then table.insert(players,{name=MySQL.Sync.fetchScalar("SELECT CONCAT(firstname,' ',lastname) FROM users WHERE identifier=@identifier",{["@identifier"]=xTarget.identifier}),sid=v}) end
        end
        if #players<1 then TriggerClientEvent('esx:showNotification', source, _L("no_people_on_server")); return end
        cb(players)
    end)
    
    ESX.RegisterServerCallback("el_business:getEmployeeList",function(source,cb,business)
        local idssql,idvals = {},{}
        for k,v in ipairs(dataCache[business]["employees"]) do
            table.insert(idssql,"@identifier"..k)
            idvals["@identifier"..k]=v
        end
        if #idssql<1 then TriggerClientEvent('esx:showNotification', source, _L("employee_list_empty")); return end
        MySQL.Async.fetchAll("SELECT CONCAT(firstname,' ',lastname) AS name,identifier FROM users WHERE identifier IN ("..table.concat(idssql,",")..")",idvals,function(data)
            local employees = {}
            for k,v in ipairs(data) do
                table.insert(employees,{name=v.name,identifier=v.identifier})
            end
            cb(employees)
        end)
    end)
    
    ESX.RegisterServerCallback("el_business:hireEmployee",function(source,cb,newempid,business)
        local xPlayer = ESX.GetPlayerFromId(source)
        local xTarget = ESX.GetPlayerFromId(newempid)
        local identifier = xPlayer.identifier
        if dataCache[business]["owner"]==identifier and xTarget then
            table.insert(dataCache[business]["employees"],xTarget.identifier)
            MySQL.Async.execute("UPDATE businesses SET employees=@employees WHERE id=@business",{["@employees"]=json.encode(dataCache[business]["employees"]),["@business"]=business},function(rc)
                cb(rc>0)
                Citizen.CreateThread(function() reloadServerData(); reloadPlayersData() end)
            end)
        else
            cb(false)
        end
    end)
    
    ESX.RegisterServerCallback("el_business:fireEmployee",function(source,cb,fireid,business)
        local xPlayer = ESX.GetPlayerFromId(source)
        local identifier = xPlayer.identifier
        if dataCache[business]["owner"]==identifier then
            for k,v in ipairs(dataCache[business]["employees"]) do
                if v==fireid then table.remove(dataCache[business]["employees"],k); break end
            end
            MySQL.Async.execute("UPDATE businesses SET employees=@employees WHERE id=@business",{["@employees"]=json.encode(dataCache[business]["employees"]),["@business"]=business},function(rc)
                cb(rc>0)
                Citizen.CreateThread(function() reloadServerData(); reloadPlayersData() end)
            end)
        else
            cb(false)
        end
    end)
    
    ESX.RegisterServerCallback("el_business:getStock", function(source,cb,business)
        local identifier = ESX.GetPlayerFromId(source).getIdentifier()
        if dataCache[business]["owner"]~=nil and dataCache[business]["owner"]==identifier or isBusinessEmployee(dataCache[business]["employees"],identifier) then cb(getStock(tonumber(business))) else cb(0) end
    end)
    
    ESX.RegisterServerCallback("el_business:buyStock", function(source,cb,business,amt)
        local xPlayer = ESX.GetPlayerFromId(source)
        local identifier = xPlayer.getIdentifier()
        if dataCache[business]["owner"]==identifier or isBusinessEmployee(dataCache[business]["employees"],identifier) then
            if xPlayer.getMoney()>=dataCache[business]["stock_price"]*amt then
                xPlayer.removeMoney(dataCache[business]["stock_price"]*amt)
                local time = math.random(300,900)
                Citizen.CreateThread(function()
                    print("[^1"..GetCurrentResourceName().."^7] Player "..identifier.." bought stock, delivering in: "..time.."s")
                    Citizen.Wait(time*1000)
                    MySQL.Async.execute('UPDATE businesses SET stock = stock + @amt WHERE id = @business', {["@amt"] = tonumber(amt), ["@business"] = tonumber(business)}, nil)
                    TriggerClientEvent('esx:showNotification', source, _L("stock_delivered"):format(dataCache[business]["name"]))
                end)
                cb(true,time)
            else
                cb(false,0)
            end
        else
            cb(false,0)
        end
    end)
    
    ESX.RegisterServerCallback("el_business:buyBusiness", function(source,cb,business)
        local xPlayer = ESX.GetPlayerFromId(source)
        local identifier = xPlayer.getIdentifier()
        local business_count = MySQL.Sync.fetchScalar("SELECT COUNT(id) FROM businesses WHERE owner=@owner",{["@owner"]=identifier})
        if business_count>=Config.max_business then
            cb(3)
        else
            if dataCache[business]["owner"]==nil then
                if xPlayer.getMoney()>=dataCache[business]["price"] then
                    dataCache[business]["owner"]=identifier -- counteract the loading time from db (player can accidentally buy twice)
                    xPlayer.removeMoney(dataCache[business]["price"])
                    MySQL.Sync.execute('UPDATE businesses SET owner = @identifier WHERE id = @business', {["@identifier"] = identifier, ["@business"] = tonumber(business)}, nil)
                    Citizen.CreateThread(function() reloadServerData();reloadPlayersData() end)
                    cb(0)
                else
                    cb(2)
                end
            else
                cb(1)
            end
        end
    end)
    
    ESX.RegisterServerCallback("el_business:sellBusiness", function(source,cb,business)
        local xPlayer = ESX.GetPlayerFromId(source)
        local identifier = xPlayer.getIdentifier()
        if dataCache[business]["owner"]==identifier then
            xPlayer.addMoney(math.floor(dataCache[business]["price"]*Config.sell_percentage))
            dataCache[business]["owner"]=nil -- counteract the loading time from db (dupe bug)
            MySQL.Sync.execute('UPDATE businesses SET owner = NULL, employees = "{}" WHERE id = @business', {["@business"] = tonumber(business)}, nil)
            Citizen.CreateThread(function() reloadServerData();reloadPlayersData() end)
            cb(true)
        else
            cb(false)
        end
    end)
    
    ESX.RegisterServerCallback("el_business:createBusiness", function(source,cb,business)
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer.getGroup()=="superadmin" then
            if not business then cb(false) end
            local bx,by,bz = table.unpack(business["buy_position"])
            local ax,ay,az = table.unpack(business["actions_position"])
            MySQL.Async.execute("INSERT INTO businesses(id,name,address,description,blipname,price,earnings,position,stock_price,taxrate,employees) VALUES (NULL,@name,@address,@description,@blipname,@price,@earnings,@position,@stock_price,@taxrate,'{}')", {
                ["@name"] = business["name"],
                ["@address"] = business["address"],
                ["@description"] = business["description"],
                ["@blipname"] = business["blipname"],
                ["@price"] = business["price"],
                ["@earnings"] = business["earnings"],
                ["@position"] = json.encode({buy = {x = bx, y = by, z = bz}, actions = {x = ax, y = ay, z = az}}),
                ["@stock_price"] = business["stock_price"],
                ["@taxrate"] = business["taxrate"]
            }, function(rowsChanged)
                if rowsChanged>0 then cb(true);reloadServerData();reloadPlayersData() else cb(false) end
            end)
        else
            cb(false)
        end
    end)
end)

function _L(str)
    if not Locale then return "Locale error" end
    if not Locale[Config.locale] then return "Invalid locale" end
    if not Locale[Config.locale][str] then return "Invalid string" end
    return Locale[Config.locale][str]
end

function reloadServerData()
    print("[^1"..GetCurrentResourceName().."^7] Syncing businesses from database")
    dataCahe = {}
    local res = MySQL.Sync.fetchAll('SELECT * FROM businesses')
    for key,val in ipairs(res) do
        hasowner = val.owner~=nil and val.owner~=""
        if hasowner and not namecache[val.owner] then namecache[val.owner]=MySQL.Sync.fetchAll("SELECT firstname,lastname FROM users WHERE identifier = @identifier",{["@identifier"]=val.owner})[1] end
        if val.owner~=nil then namecache[val.owner] = namecache[val.owner]~=nil and namecache[val.owner] or {firstname="N/A",lastname="N/A"} end
        dataCache[val.id] = {
            id = val.id,
            name = val.name,
            address = val.address,
            description = val.description,
            blipname = (val.blipname~=nil and val.blipname~="") and val.blipname or Config.blip.name,
            owner = val.owner,
            owner_rp_name = hasowner and namecache[val.owner].firstname.." "..namecache[val.owner].lastname or "None",
            price = val.price,
            earnings = val.earnings,
            position = json.decode(val.position),
            stock_price = val.stock_price,
            employees = (val.employees~=nil and val.employees~="") and json.decode(val.employees) or {},
            taxrate = (val.taxrate~=nil and val.taxrate~="") and val.taxrate or Config.default_tax_rate
        }
    end
    print("[^1"..GetCurrentResourceName().."^7] Synced "..tostring(#res).." business(es) from database")
end

function addMoney(identifier,money,business)
    if not identifier then return end
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    local money = math.floor(tonumber(money))
    if xPlayer then
        print("[^1"..GetCurrentResourceName().."^7] Adding money to "..GetPlayerName(xPlayer.source).." - "..identifier.." ("..tostring(money).."$)")
        TriggerClientEvent('esx:showNotification', xPlayer.source, _L("received_money"):format(tostring(money),business))
        xPlayer.addAccountMoney("bank", math.floor(money))
    else
        print("[^1"..GetCurrentResourceName().."^7] An error occured while adding money to "..identifier.." ("..tostring(money).."$). The player is offline. Forcing adding money")
        MySQL.Sync.execute('UPDATE `users` SET `bank` = `bank` + @bank WHERE `identifier` = @identifier',{['@bank'] = money, ['@identifier'] = identifier})
    end
end

function noStock(identifier,business)
    if not identifier or identifier==nil then return end
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    print("[^1"..GetCurrentResourceName().."^7] Player "..identifier.." has no stock at "..business)
    if xPlayer then
        TriggerClientEvent('esx:showNotification', xPlayer.source, _L("out_of_stock"):format(business))
    end
end

function getStock(business)
    return MySQL.Sync.fetchAll('SELECT stock FROM businesses WHERE id='..tonumber(business))[1].stock
end

function runMoneyCoroutines(d,h,m)
    Citizen.CreateThread(function()
        print("[^1"..GetCurrentResourceName().."^7] Running money coroutines "..h..":"..m)
        local businesses = MySQL.Async.fetchAll('SELECT * FROM businesses',{},function(data)
            for _,business in ipairs(data) do
                if business["owner"]~=nil then
                    if business["stock"]>0 then
                        MySQL.Async.execute('UPDATE businesses SET stock = stock - 1 WHERE id = @business', {["@business"] = tonumber(business["id"])}, nil)
                        local taxed_earnings = business["earnings"]*(1.0-(business["taxrate"]~=nil and business["taxrate"] or Config.default_tax_rate))
                        if business["employees"]~=nil and business["employees"]~="" and business["employees"]~="{}" and business["employees"]~="[]" then
                            local employees = json.decode(business["employees"])
                            local per_employee_earning = Config.employee_payout_formula(taxed_earnings,#employees)
                            for k,v in ipairs(employees) do
                                addMoney(v,per_employee_earning,business["name"])
                            end
                            addMoney(business["owner"],taxed_earnings-(per_employee_earning*#employees),business["name"])
                        else
                            addMoney(business["owner"],taxed_earnings,business["name"])
                        end
                    else
                        noStock(business["owner"],business["name"])
                    end
                end
            end
        end)
    end)
end

MySQL.ready(function()
    reloadServerData()
    Citizen.CreateThread(function()
        Citizen.Wait(2000) -- just wait for clients to load their shit
        reloadPlayersData()
    end)
end)

function reloadPlayersData()
    local xPlayers = ESX.GetPlayers()
    if #xPlayers<1 then return end
    TriggerClientEvent("el_business:syncServer",-1,dataCache)
end

AddEventHandler('esx:playerLoaded', function(source, user)
    local _source = source
    TriggerClientEvent("el_business:syncServer",_source,dataCache)
end)

RegisterCommand("business", function(source,args,rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup()~="superadmin" then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions' } })
    else
        if args[1]=="business" then table.remove(args,1) end
        if #args>0 then
            if args[1]=="reload" then
                reloadServerData()
                reloadPlayersData()
                TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Data loaded from database and synced' } })
            elseif args[1]=="list" then
                TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Business list will appear in F8 console' } })
                TriggerClientEvent("el_business:businessList", source)
            elseif args[1]=="create" then
                TriggerClientEvent("el_business:businessCreate", source)
            -- elseif args[1]=="runcoros" then -- debug
            --     runMoneyCoroutines(0,0,0)
            end
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Wrong parameters, possible parameters are: ^2reload^7, ^2list^7, ^2create^7' } })
        end
    end
end, false)

function isBusinessEmployee(employeelist,identifier)
    for k,v in ipairs(employeelist) do
        if v==identifier then return true end
    end
    return false
end

Citizen.CreateThread(function()
    print("[^1"..GetCurrentResourceName().."^7] Started!")
    -- print("********************")
    print("[^1"..GetCurrentResourceName().."^7] !!^3WARNING^7!! PLEASE DON\'T RESTART THIS SCRIPT, USE THE BUILTIN COMMAND /business reload TO RELOAD DATA FROM DATABASE")
    -- print("********************")
    for i=0,23 do
        TriggerEvent("cron:runAt",i,0,runMoneyCoroutines)
    end
    print("[^1"..GetCurrentResourceName().."^7] Performing version check...")
    PerformHttpRequest("https://api.elipse458.me/resources/checkupdates.php", function(a,b,c)
        if a~=200 then
            print("[^1"..GetCurrentResourceName().."^7] Version check failed!")
        else
            local data = json.decode(b)
            if data and data.updateNeeded then
                print("[^1"..GetCurrentResourceName().."^7] Outdated!")
                print("[^1"..GetCurrentResourceName().."^7] Current version: 1.57 | New version: "..data.newVersion.." | Versions behind: "..data.versionsBehind)
                print("[^1"..GetCurrentResourceName().."^7] Changelog:")
                for k,v in ipairs(data.update.changelog) do
                    print("- "..v)
                end
                print("[^1"..GetCurrentResourceName().."^7] Database update needed: "..(data.update.dbUpdateNeeded and "^4Yes^7" or "^1No^7"))
                print("[^1"..GetCurrentResourceName().."^7] Config update needed: "..(data.update.configUpdateNeeded and "^4Yes^7" or "^1No^7"))
                print("[^1"..GetCurrentResourceName().."^7] Update url: ^4"..data.update.releaseUrl.."^7")
                if (type(data.versionsBehind)=="string" or data.versionsBehind>1) and data.update.dbUpdateNeeded then
                    print("[^1"..GetCurrentResourceName().."^7] ^1!!^7 You are multiple versions behind, make sure you run update sql files (if any) from all new versions in order of release ^1!!^7")
                end
            else
                print("[^1"..GetCurrentResourceName().."^7] No updates found!")
            end
        end
    end, "POST", "resname=el_business&ver=1.57")
end)
