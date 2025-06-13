ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterUsableItem('jumelles', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	TriggerClientEvent('duck:jumelles:active', source, 'normal')
end)

ESX.RegisterUsableItem('thermalvision', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	TriggerClientEvent('duck:jumelles:active', source, 'thermal') 
end)

ESX.RegisterUsableItem('nightvision', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	TriggerClientEvent('duck:jumelles:active', source, 'night')
end)
