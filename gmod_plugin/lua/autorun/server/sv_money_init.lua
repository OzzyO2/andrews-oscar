local TABLE_NAME = "OscarMoney:PlayerData"
local TRANSFERS_TABLE_NAME = "OscarMoney:Transfers"
local TRANSFER_WITHDRAW = 0
local TRANSFER_DEPOSIT = 1
local NOTIFY_GENERIC = 0
local NOTIFY_ERROR = 1
local HISTORY_PAGE_SIZE = 4
local RATE_LIMIT = 3
local lastTransfer = {}

-- we need to initialise the sql table if it's not already in existence
if not sql.TableExists(TABLE_NAME) then
	sql.Begin()
		sql.Query("CREATE TABLE `" .. TABLE_NAME .. "`( id int, bank int )")
	sql.Commit()
end

if not sql.TableExists(TRANSFERS_TABLE_NAME) then
	sql.Begin()
		sql.Query("CREATE TABLE `" .. TRANSFERS_TABLE_NAME .. "`( toId int, fromId int, amount int, timestamp int )")
	sql.Commit()
end

function IdHasEntry(id)
	local sanitizedId = sql.SQLStr(id)
	local query = string.format("SELECT id FROM `" .. TABLE_NAME .. "` WHERE id=" .. id)
	local result = sql.Query(query)

	if not result then
		return false -- probably an error
	end
	return true
end

function LogTransfer(to, from, amount)
	local query = string.format("INSERT INTO `%s` ( toId, fromId, amount, timestamp ) VALUES ( %s, %s, %d, %d )", TRANSFERS_TABLE_NAME, to, from, amount, os.time() )
	sql.Begin()
		local s = sql.Query(query)
	sql.Commit()
end

function FetchTransfers(id, page)
	local query = string.format("SELECT * FROM `%s` WHERE (toId=%s OR fromId=%s) ORDER BY timestamp DESC", TRANSFERS_TABLE_NAME, id, id)
	local result = sql.Query(query)

	local data = {}
	if not result then return data end

	local skipped = 0

	for i, transfer in pairs(result) do
		if tostring(transfer.toId) == id then
			if skipped >= page * HISTORY_PAGE_SIZE then
				table.insert(data,{
					amount = transfer.amount,
					toFrom = transfer.fromId,
					timestamp = transfer.timestamp,
				})
			else
				skipped = skipped + 1
			end
		end

		if #data >= HISTORY_PAGE_SIZE then break end

		if tostring(transfer.fromId) == id then
			if skipped >= page * HISTORY_PAGE_SIZE then
				table.insert(data,{
					amount = -transfer.amount,
					toFrom = transfer.toId,
					timestamp = transfer.timestamp,
				})
			else
				skipped = skipped + 1
			end
		end

		if #data >= HISTORY_PAGE_SIZE then break end
	end

	return data
end

function SavePlayerData(client)
	local bank = client:GetNWInt("bankBalance")
	local query = string.format("UPDATE `%s` SET bank=%d WHERE id=%q", TABLE_NAME, bank, client:SteamID64())
	sql.Begin()
		sql.Query(query)
	sql.Commit()
end

function LoadPlayerData(client)
	local query = string.format("SELECT bank FROM `%s` WHERE id=%q", TABLE_NAME, client:SteamID64())
	local playerData = sql.QueryRow("SELECT bank FROM `" .. TABLE_NAME .. "` WHERE id=" .. client:SteamID64()) -- someone should try and break this at some point

	if not playerData then
		sql.Begin()
			local query = string.format("INSERT INTO `%s` ( id, bank ) VALUES ( %q, %d )", TABLE_NAME, client:SteamID64(), 0)
			sql.Query(query)
		sql.Commit()
		client:SetNWInt("bankBalance", 0)
	else
		client:SetNWInt("bankBalance", tonumber(playerData.bank))
	end
end

hook.Add("PlayerInitialSpawn", "Oscarmoney-on-join", function(client)
	LoadPlayerData(client)
end)

hook.Add("playerGetSalary", "Oscarmoney-on-salary", function(client, amount)
	local bankBalance = client:GetNWInt("bankBalance")
	client:SetNWInt("bankBalance",bankBalance + amount)
	SavePlayerData(client)

	return false, string.format("Payday! $%d has been transferred to your bank account!", amount), 0
end)

util.AddNetworkString("OscarMoney:TransferMoney")
util.AddNetworkString("OscarMoney:PlayerTransferMoney")
util.AddNetworkString("OscarMoney:RequestTransfers")

net.Receive("OscarMoney:TransferMoney",function(length,client)
	local transferType = net.ReadUInt(1)
	local transferAmount = net.ReadUInt(32)

	local bankBalance = client:GetNWInt("bankBalance")

	if transferType == TRANSFER_DEPOSIT then
		if not client:canAfford(transferAmount) then
			DarkRP.notify(client, NOTIFY_ERROR, 5, string.format("Insufficient funds to deposit $%d!", transferAmount))
			return
		end

		client:addMoney(-transferAmount)
		client:SetNWInt("bankBalance",bankBalance + transferAmount)
		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully deposited $%d!", transferAmount))
	elseif transferType == TRANSFER_WITHDRAW then
		local sufficientBankBalance = bankBalance >= transferAmount
		if not sufficientBankBalance then
			DarkRP.notify(client, NOTIFY_ERROR, 5, string.format("Insufficient funds to withdraw $%d!", transferAmount))
			return -- stop because they have insufficient funds
		end

		client:addMoney(transferAmount)
		client:SetNWInt("bankBalance",bankBalance - transferAmount)
		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully withdrew $%d!", transferAmount))
	else
		print(string.format("Warning: Invalid transferType %d, expected %d or %d", transferType, TRANSFER_DEPOSIT, TRANSFER_WITHDRAW))
		DarkRP.notify(client, NOTIFY_ERROR, 5, "An error occured while handling your transfer.")
		return
	end

	SavePlayerData(client)
end)

net.Receive("OscarMoney:PlayerTransferMoney", function(length, client)
	local transferTarget = net.ReadUInt64()
	local transferAmount = net.ReadUInt(32)

	local targetSanitized = sql.SQLStr(transferTarget)

	local bankBalance = client:GetNWInt("bankBalance")

	if bankBalance < transferAmount then
		DarkRP.notify(client, NOTIFY_ERROR, 5, string.format("Insufficient funds to transfer $%d!", transferAmount))
		return
	end

	if CurTime() - (lastTransfer[client:SteamID64()] or 0) < RATE_LIMIT then -- don't want people spamming now do we
		DarkRP.notify(client, NOTIFY_ERROR, 5, "Slow down! You're doing that too fast.")
		return
	end
	lastTransfer[client:SteamID64()] = CurTime()

	local targetClient = player.GetBySteamID64(transferTarget) -- need to check if the player is online or not
	if targetClient then -- they exist on the server so online
		targetClient:SetNWInt("bankBalance", targetClient:GetNWInt("bankBalance") + transferAmount)
		client:SetNWInt("bankBalance", client:GetNWInt("bankBalance") - transferAmount)

		SavePlayerData(client)
		SavePlayerData(targetClient)

		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully transfered $%d!", transferAmount))
		DarkRP.notify(targetClient, NOTIFY_GENERIC, 5, string.format("You received $%d from %s!", transferAmount, client:Name()))
	else -- they're not online
		local playerExists = IdHasEntry(transferTarget)
		if not playerExists then -- shouldn't transfer to non-existent steamid's
			DarkRP.notify(client, NOTIFY_ERROR, 5, "No such account Id.")
			return
		end

		client:SetNWInt("bankBalance", client:GetNWInt("bankBalance") - transferAmount)
		SavePlayerData(client)

		local targetBalance = sql.Query(string.format("SELECT bank FROM `%s` WHERE id=%q", TABLE_NAME, targetSanitized))

		local query = string.format("UPDATE `%s` SET bank=%d WHERE id=%q", TABLE_NAME, targetBalance + transferAmount, targetSanitized)

		sql.Begin()
			sql.Query(query)
		sql.Commit()
		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully transfered $%d!", transferAmount))
	end

	LogTransfer( targetSanitized, client:SteamID64(), transferAmount)
end)

net.Receive("OscarMoney:RequestTransfers", function( length, client )
	local entity = net.ReadEntity()
	local pageNumber = net.ReadUInt(32)
	local clientTime = net.ReadInt(32)

	local data = FetchTransfers( client:SteamID64(), pageNumber )

	net.Start("OscarMoney:RequestTransfers")
		net.WriteEntity(entity)
		net.WriteTable(data, true)
		net.WriteInt(os.difftime(os.time(), clientTime), 32)
	net.Send(client)
end)
