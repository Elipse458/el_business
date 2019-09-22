ESX = nil
local PlayerData = nil
local businessData,blips = {},{}
local boss,buy,currentmenu = false,false,nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
    end
    if PlayerData==nil then PlayerData = ESX.GetPlayerData() end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

function disp_time(time)
    local minutes = math.floor((time%3600)/60)
    local seconds = math.floor((time%60))
    return string.format("~b~%02d~s~m ~b~%02d~s~s",minutes,seconds)
end

function DrawText3D(x,y,z, text, scl) 
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
    local scale = (1/dist)*scl
    local fov = (1/GetGameplayCamFov())*100
    local scale = scale*fov
    if onScreen then
        SetTextScale(0.0*scale, 1.1*scale)
        SetTextFont(0)
        SetTextProportional(1)
        -- SetTextScale(0.0, 0.55)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x,_y)
    end
end

function OpenBusinessMenu(business)
    if boss then ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_boss") end
    boss = true
    ESX.TriggerServerCallback("esx_business:getStock", function(stock)
        local elements = {}
        table.insert(elements,{label = "Stock: "..tostring(stock), value = ''})
        table.insert(elements,{label = 'Buy Stock - <span style="color:green;">$'..tostring(business["stock_price"])..'</span>', label_real = 'buystock', value = 1, type = 'slider', min = 1, max = 100})
        if business["owner"]==PlayerData.identifier then table.insert(elements,{label = 'Sell business - <span style="color:red;">$'..tostring(math.floor(business["price"]*Config.sell_percentage))..'</span>', value = 'sellbusiness'}) end
        if business["owner"]==PlayerData.identifier then table.insert(elements,{label = 'Employee list', value = 'employeelist'}) end
        table.insert(elements,{label = "Exit menu", value = 'exitmenu'})
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_boss',
        {
            title = business["name"],
            align = 'bottom-right',
            elements = elements
        }, function(data, menu)
            if data.current.label_real == 'buystock' then
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_confirm_stock', {
                    title    = ("Are you sure you want to buy %s stock for %s?"):format(data.current.value,business["stock_price"]*data.current.value),
                    align    = 'bottom-right',
                    elements = {
                        {label = 'No',  value = 'no'},
                        {label = 'Yes', value = 'yes'},
                    }
                }, function(data2, menu2)
                    if data2.current.value == 'yes' then
                        ESX.TriggerServerCallback("esx_business:buyStock", function(success,time)
                            if success then
                                ESX.ShowNotification("Successfuly bought stock! It will arrive in "..disp_time(time))
                            else ESX.ShowNotification("~r~You don't have enough money") end
                        end,business["id"],data.current.value)
                    end
                    menu2.close()
                end, function(data2, menu2) menu2.close() end)
            elseif data.current.value == 'sellbusiness' then
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_confirm_sellbusiness', {
                    title    = ("Are you sure you want to sell %s for %s?"):format(business["name"],math.floor(business["price"]*Config.sell_percentage)),
                    align    = 'bottom-right',
                    elements = {
                        {label = 'No',  value = 'no'},
                        {label = 'Yes', value = 'yes'},
                    }
                }, function(data2, menu2)
                    if data2.current.value == 'yes' then
                        ESX.TriggerServerCallback("esx_business:sellBusiness", function(success)
                            if success then
                                ESX.ShowNotification("You have sold your business for ~g~$"..math.floor(business["price"]*Config.sell_percentage))
                            else ESX.ShowNotification("~r~An error occured") end
                        end,business["id"])
                    end
                    menu2.close()
                end, function(data2, menu2) menu2.close() end)
                menu.close(); boss=false
            elseif data.current.value=="employeelist" then
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_employeemenu_choice', {
                    title    = business["name"]..' - Employees',
                    align    = 'bottom-right',
                    elements = {
                        {label = 'Hire employees',  value = 'hire'},
                        {label = 'Fire employees', value = 'fire'},
                    }
                }, function(data2, menu2)
                    if data2.current.value=="hire" then
                        ESX.TriggerServerCallback("esx_business:getNewEmployeeList",function(newemployees)
                            local newemployeeselements = {}
                            for k,v in ipairs(newemployees) do
                                table.insert(newemployeeselements,{label=v.name.." - "..v.sid,sid=v.sid})
                            end
                            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_employeemenu_hire', {
                                title    = business["name"]..' - Hire employees',
                                align    = 'bottom-right',
                                elements = newemployeeselements
                            }, function(data3, menu3)
                                ESX.TriggerServerCallback("esx_business:hireEmployee",function(isok)
                                    ESX.ShowNotification(isok and "~g~Successfully hired a new employee" or "~r~An error has occured")
                                end, data3.current.sid, business["id"])
                                menu3.close(); boss=false
                            end, function(data3, menu3) menu3.close(); boss=false end)
                        end, business["id"])
                    elseif data2.current.value=="fire" then
                        ESX.TriggerServerCallback("esx_business:getEmployeeList",function(employees)
                            local employeeselements = {}
                            for k,v in ipairs(employees) do
                                table.insert(employeeselements,{label=v.name,identifier=v.identifier})
                            end
                            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_employeemenu_fire', {
                                title    = business["name"]..' - Fire employees',
                                align    = 'bottom-right',
                                elements = employeeselements
                            }, function(data3, menu3)
                                ESX.TriggerServerCallback("esx_business:fireEmployee",function(isok)
                                    ESX.ShowNotification(isok and "~g~Successfully fired an employee" or "~r~An error has occured")
                                end, data3.current.identifier, business["id"])
                                menu3.close(); boss=false
                            end, function(data3, menu3) menu3.close(); boss=false end)
                        end, business["id"])
                    end
                    menu2.close(); boss=false
                end, function(data2, menu2) menu2.close(); boss = false end)
                menu.close()
            else
                menu.close(); boss=false
            end
        end, function(data, menu)
            menu.close(); boss=false
        end)
    end, business["id"])
end

function OpenBuyBusinessMenu(business)
    if buy then ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_buy") end
    buy = true
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_buy',
    {
        title = "Buy "..business["name"].." for $"..business["price"].."?",
        align = 'bottom-right',
        elements = {
            {label = 'Yes', value = 'yes'},
            {label = 'No', value = 'no'}
        }
    }, function(data,menu)
        if data.current.value == 'yes' then
            ESX.TriggerServerCallback("esx_business:buyBusiness",function(status)
                if status==0 then
                    ESX.ShowNotification("You successfuly bought ~b~"..business["name"].."~s~!")
                elseif status==1 then
                    ESX.ShowNotification("~r~"..business["name"].."~s~ already has an owner!")
                else
                    ESX.ShowNotification("You don't have enough money to buy ~b~"..business["name"].."~s~!")
                end
            end,business["id"])
        end
        menu.close(); buy = false
    end, function(data,menu)
        menu.close(); buy = false
    end)
end

function OpenParameterDialog(length)
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP", "", "", "", "", "", length)
    while UpdateOnscreenKeyboard()==0 do
        DisableAllControlActions(0)
        Wait(0)
    end
    if GetOnscreenKeyboardResult() then return GetOnscreenKeyboardResult() end
end

function editElements(elements,label,value)
    for _,v in ipairs(elements) do
        if v.label==label then v.value=value; break end
    end
    return elements
end

RegisterCommand("testing", function(a,b,c)
    print(OpenParameterDialog(255))
end, false)

function OpenCreateBusinessMenu()
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_create',
    {
        title = "Create business",
        align = 'bottom-right',
        elements = {
            {label = '<span style="color:red;">Your current position will be used</span>', action = ''},
            {label = 'Name: ', action = 'name', value = '', key = 2},
            {label = 'Description: ', action = 'desc', value = '', key = 3},
            {label = 'Address: ', action = 'address', value = '', key = 4},
            {label = 'Blip name: ', action = 'blipname', value = '', key = 5},
            {label = 'Price: ', action = 'price', value = '', key = 6},
            {label = 'Earnings: ', action = 'earnings', value = '', key = 7},
            {label = 'Stock price: ', action = 'stock_price', value = '', key = 8},
            {label = 'Tax rate: ', action = 'taxrate', value = '', key = 9},
            {label = '<span style="color:red;">Tax rate is in % 0.1=10% - 1.0=100%</span>', action = ''},
            {label = 'Create business', action = 'create'},
            {label = 'Discard business', action = 'discard'}
        }
    }, function(data,menu)
        if data.current.action == 'name' then
            data.current.value = OpenParameterDialog(255)
            data.current.label = 'Name: '..data.current.value
        elseif data.current.action == 'desc' then
            data.current.value = OpenParameterDialog(75)
            data.current.label = 'Description: '..data.current.value
        elseif data.current.action == 'address' then
            data.current.value = OpenParameterDialog(255)
            data.current.label = 'Address: '..data.current.value
        elseif data.current.action == 'price' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Price: '..tostring(data.current.value)
        elseif data.current.action == 'earnings' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Earnings: '..tostring(data.current.value)
        elseif data.current.action == 'blipname' then
            data.current.value = OpenParameterDialog(75)
            data.current.label = 'Blip name: '..tostring(data.current.value)
        elseif data.current.action == 'stock_price' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Stock price: '..tostring(data.current.value)
        elseif data.current.action == 'taxrate' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Tax rate: '..tostring(data.current.value)
        elseif data.current.action == 'create' then
            local error = false
            for _,v in ipairs(menu.data.elements) do if v.key~=nil and v.key~=5 and (v.value==nil or v.value=='') then error = true end end
            if not error then
                local buypos = GetEntityCoords(GetPlayerPed(-1))
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_create_actionpos', {title="Please select the boss action location",align="bottom-right",elements={{label='<span style="color:red;">Your current position will be used</span>',action=''},{label="Set position",action="setpos"},{label="Cancel",action="cancel"}}},function(data1,menu1) if data1.current.action=="setpos" then 
                    local business = {
                        name = menu.data.elements[2].value,
                        address = menu.data.elements[4].value,
                        description = menu.data.elements[3].value,
                        price = menu.data.elements[6].value,
                        earnings = menu.data.elements[7].value,
                        blipname = menu.data.elements[5].value=="" and nil or menu.data.elements[5].value,
                        buy_position = buypos,
                        actions_position = GetEntityCoords(GetPlayerPed(-1)),
                        stock_price = menu.data.elements[8].value,
                        taxrate = menu.data.elements[9].value=="" and nil or menu.data.elements[9].value
                    }
                    ESX.ShowNotification("~b~Creating business...")
                    menu1.close()
                    ESX.TriggerServerCallback("esx_business:createBusiness", function(diditwork)
                        if diditwork then ESX.ShowNotification("~g~Business created!") else ESX.ShowNotification("~r~There was an error creating the business") end
                    end,business)
                elseif data1.current.action=="cancel" then menu1.close() end end,function(data1,menu1) menu1.close() end)
                menu.close()
            else
                ESX.ShowNotification("~r~Data error, check your values.")
            end
        elseif data.current.action == 'discard' then
            menu.close()
        end
        if data.current.key~=nil then menu.setElement(data.current.key, "label", data.current.label); menu.setElement(data.current.key, "value", data.current.value); menu.refresh() end
    end, function(data,menu)
        menu.close()
    end)
end

function replaceVariablesInString(str,business)
    for k,v in pairs(business) do
        str = str:gsub("{"..k.."}",(k=="price" or k=="stock_price" or k=="earnings") and ESX.Math.GroupDigits(v) or (k=="taxrate" and tostring(math.floor(v*100)) or tostring(v)))
    end
    return str
end

RegisterNetEvent("esx_business:syncServer")
AddEventHandler("esx_business:syncServer",function(data)
    print(ESX.DumpTable(data))
    if Config.blip.enabled then
        for k,v in ipairs(blips) do
            RemoveBlip(v)
        end
        blips={}
    end
    for k,v in pairs(data) do
        if Config.blip.enabled then
            local bl = AddBlipForCoord(v.position.buy.x,v.position.buy.y,v.position.buy.z)
            SetBlipDisplay(bl, 6)
            SetBlipColour(bl, Config.blip.color)
            SetBlipSprite(bl, Config.blip.sprite)
            table.insert(blips,bl)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(v.blipname~=nil and v.blipname or Config.blip.name)
            EndTextCommandSetBlipName(bl)
        end
        data[k]["isemployee"] = false
        for kk,vv in ipairs(v.employees) do
            if vv==PlayerData.identifier then data[k]["isemployee"]=true end
        end
        data[k]["display"] = {}
        for kk,vv in ipairs(Config.display) do
            table.insert(data[k].display,replaceVariablesInString(vv.text,v))
        end
    end
    businessData = data
    -- Citizen.Trace("Received business data from server")
end)

RegisterNetEvent("esx_business:businessCreate")
AddEventHandler("esx_business:businessCreate",function()
    OpenCreateBusinessMenu()
end)

function counttbl(tbl) local cnt = 0; for _,_ in pairs(tbl) do cnt=cnt+1 end; return cnt end

RegisterNetEvent("esx_business:businessList")
AddEventHandler("esx_business:businessList",function()
    if counttbl(businessData)<1 then print("No business info on client, if there is some on server, you should try running the `/business reload` command to sync server info") else
        print("esx_business: Started business dump")
        for k,v in pairs(businessData) do
            print("-"..tostring(v["id"]))
            print("|-> Name: "..v["name"])
            print("|-> Address: "..v["address"])
            print("|-> Description: "..v["description"])
            print("|-> Blip name: "..(v["blipname"]~=nil and v["blipname"] or Config.blip.name))
            print("|-> Owner: "..(v["owner_name"]~=nil and v["owner_name"] or "N/A").." ("..(v["owner"]~=nil and v["owner"] or "N/A")..")")
            print("|-> Price: "..v["price"].."$")
            print("|-> Stock price: "..v["stock_price"].."$")
            print("L-> Earnings: "..v["earnings"].."$/h")
        end
        print("esx_business: Finished business dump")
        print("esx_business: Dumped "..tostring(counttbl(businessData)).." business(es) to console")
    end
end)

Citizen.CreateThread(function()
    while true do
        local ped = GetPlayerPed(-1)
        local ppos = GetEntityCoords(ped)
        Citizen.Wait(10) -- change this to 0 if you're experiencing flickering
        for id,business in pairs(businessData) do
            local x,y,z = business.position.buy.x,business.position.buy.y,business.position.buy.z
            if GetDistanceBetweenCoords(ppos,x,y,z,false)<Config.draw_distance then
                if business.owner==nil then
                    if GetDistanceBetweenCoords(ppos,x,y,z,false)<2.0 and not buy then
                        ESX.ShowHelpNotification('Hit ~INPUT_CONTEXT~ to buy business')
                        if IsControlJustPressed(0, 51) then OpenBuyBusinessMenu(business); currentmenu=id end
                    elseif GetDistanceBetweenCoords(ppos,x,y,z,false)>2.0 and buy and currentmenu==id then
                        ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_buy")
                        buy = false; currentmenu = nil
                    end
                elseif business.owner==PlayerData.identifier or business.isemployee then
                    local xx,yy,zz = business.position.actions.x,business.position.actions.y,business.position.actions.z
                    if GetDistanceBetweenCoords(vector3(xx,yy,zz),GetEntityCoords(ped),false)<1.0 and not boss then
                        ESX.ShowHelpNotification('Hit ~INPUT_CONTEXT~ to open business menu')
                        if IsControlJustPressed(0, 51) then OpenBusinessMenu(business); currentmenu=id end
                    elseif GetDistanceBetweenCoords(vector3(xx,yy,zz),GetEntityCoords(ped),false)>1.0 and boss and currentmenu==id then
                        ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_boss")
                        boss = false; currentmenu = nil
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function() -- draw thread
    while true do
        Citizen.Wait(5)
        local ppos = GetEntityCoords(GetPlayerPed(-1))
        for _,business in pairs(businessData) do
            local x,y,z = business.position.buy.x,business.position.buy.y,business.position.buy.z
            if GetDistanceBetweenCoords(ppos,x,y,z,false)<Config.draw_distance then
                for k,v in ipairs(Config.display) do
                    DrawText3D(x,y,z+0.5+v.offset,business.display[k],v.scale)
                end
                if business.owner==nil then
                    DrawMarker(29, x, y, z-0.7, 0, 0, 0, 0, 0, 0, 1.0001, 1.0001, 1.2001, 0, 255, 0, 200, 0, 0, 0, true)
                elseif business.owner==PlayerData.identifier or business.isemployee then
                    local xx,yy,zz = business.position.actions.x,business.position.actions.y,business.position.actions.z
                    DrawMarker(1, xx, yy, zz-1.0, 0, 0, 0, 0, 0, 0, 1.0001, 1.0001, 0.25, 0, 0, 255, 100, 0, 0, 0, false)
                end
            end
        end
    end
end)