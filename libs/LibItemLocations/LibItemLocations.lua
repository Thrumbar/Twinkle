local MAJOR, MINOR = 'LibItemLocations', 1
assert(LibStub, MAJOR..' requires LibStub')
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local bor, band, lshift = bit.bor, bit.band, bit.lshift
local EquipmentManager_UnpackLocation = EquipmentManager_UnpackLocation
local ITEM_INVENTORY_BAG_BIT_OFFSET = ITEM_INVENTORY_BAG_BIT_OFFSET
local ITEM_INVENTORY_LOCATION_BAGS = ITEM_INVENTORY_LOCATION_BAGS
local ITEM_INVENTORY_LOCATION_BANK = ITEM_INVENTORY_LOCATION_BANK
local ITEM_INVENTORY_LOCATION_PLAYER = ITEM_INVENTORY_LOCATION_PLAYER
local ITEM_INVENTORY_LOCATION_VOIDSTORAGE = ITEM_INVENTORY_LOCATION_VOIDSTORAGE
local REAGENTBANK_CONTAINER = REAGENTBANK_CONTAINER

-- custom masks that are missing in order to fully physical replicate item locations
if not _G.GUILDBANK_CONTAINER                 then _G.GUILDBANK_CONTAINER      = REAGENTBANK_CONTAINER - 1 end
if not _G.VOIDSTORAGE_CONTAINER               then _G.VOIDSTORAGE_CONTAINER    = GUILDBANK_CONTAINER - 1 end
if not _G.MAILATTACHMENT_CONTAINER            then _G.MAILATTACHMENT_CONTAINER = VOIDSTORAGE_CONTAINER - 1 end
if not _G.AUCTIONHOUSE_CONTAINER              then _G.AUCTIONHOUSE_CONTAINER   = MAILATTACHMENT_CONTAINER - 1 end
local GUILDBANK_CONTAINER, VOIDSTORAGE_CONTAINER, MAILATTACHMENT_CONTAINER, AUCTIONHOUSE_CONTAINER = GUILDBANK_CONTAINER, VOIDSTORAGE_CONTAINER, MAILATTACHMENT_CONTAINER, AUCTIONHOUSE_CONTAINER

if not _G.ITEM_INVENTORY_LOCATION_REAGENTBANK then _G.ITEM_INVENTORY_LOCATION_REAGENTBANK =  16777216 end
if not _G.ITEM_INVENTORY_LOCATION_GUILDBANK   then _G.ITEM_INVENTORY_LOCATION_GUILDBANK   =  33554432 end
if not _G.ITEM_INVENTORY_LOCATION_MAIL        then _G.ITEM_INVENTORY_LOCATION_MAIL        =  67108864 end
if not _G.ITEM_INVENTORY_LOCATION_AUCTION     then _G.ITEM_INVENTORY_LOCATION_AUCTION     = 134217728 end
local ITEM_INVENTORY_LOCATION_REAGENTBANK, ITEM_INVENTORY_LOCATION_GUILDBANK, ITEM_INVENTORY_LOCATION_MAIL, ITEM_INVENTORY_LOCATION_AUCTION = ITEM_INVENTORY_LOCATION_REAGENTBANK, ITEM_INVENTORY_LOCATION_GUILDBANK, ITEM_INVENTORY_LOCATION_MAIL, ITEM_INVENTORY_LOCATION_AUCTION

function lib:PackInventoryLocation(container, slot, equipment, bank, bags, voidStorage, reagentBank, mailAttachment, guildBank, auctionHouse)
	local location = 0
	-- basic flags
	location = bor(location, equipment and ITEM_INVENTORY_LOCATION_PLAYER or 0)
	location = bor(location, bags and ITEM_INVENTORY_LOCATION_BAGS or 0)
	location = bor(location, bank and ITEM_INVENTORY_LOCATION_BANK or 0)
	location = bor(location, voidStorage and ITEM_INVENTORY_LOCATION_VOIDSTORAGE or 0)
	location = bor(location, reagentBank and ITEM_INVENTORY_LOCATION_REAGENTBANK or 0)
	location = bor(location, guildBank and ITEM_INVENTORY_LOCATION_GUILDBANK or 0)
	location = bor(location, mailAttachment and ITEM_INVENTORY_LOCATION_MAIL or 0)
	location = bor(location, auctionHouse and ITEM_INVENTORY_LOCATION_AUCTION or 0)

	-- container (tab, bag, ...) and slot
	location = location + (slot or 1)
	if container and container > 0 then
		location = lshift(container, ITEM_INVENTORY_BAG_BIT_OFFSET)
	end

	return location
end

function lib:UnpackInventoryLocation(location)
	local reagentBank, mailAttachment, auctionHouse

	local reagentBank    = band(location, ITEM_INVENTORY_LOCATION_REAGENTBANK) ~= 0
	local guildBank      = band(location, ITEM_INVENTORY_LOCATION_GUILDBANK) ~= 0
	local mailAttachment = band(location, ITEM_INVENTORY_LOCATION_MAIL) ~= 0
	local auctionHouse   = band(location, ITEM_INVENTORY_LOCATION_AUCTION) ~= 0

	if reagentBank    then location = location - ITEM_INVENTORY_LOCATION_REAGENTBANK end
	if guildBank      then location = location - ITEM_INVENTORY_LOCATION_GUILDBANK end
	if mailAttachment then location = location - ITEM_INVENTORY_LOCATION_MAIL end
	if auctionHouse   then location = location - ITEM_INVENTORY_LOCATION_AUCTION end
	if reagentBank or guildBank or mailAttachment or auctionHouse then
		-- so container and slot gets parsed nicely
		location = bor(location, ITEM_INVENTORY_LOCATION_BAGS)
	end

	local player, bank, bags, voidStorage, slot, container, tab, voidSlot = EquipmentManager_UnpackLocation(location)
	if voidStorage then
		container = tab
		slot = voidSlot
	end

	return container, slot, player, bank, bags, voidStorage, reagentBank, mailAttachment, guildBank, auctionHouse
end
